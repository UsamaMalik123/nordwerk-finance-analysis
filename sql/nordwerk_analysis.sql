-- =====================================================================
-- NordWerk Maschinenbau GmbH – Finance Analysis (MySQL 8)
-- Author: Muhammad Usama Bin Babar
-- Tables: gl, budget, coa, cost_centers, invoices, customers
-- Note: tables were loaded from the cleaned CSVs in /data/clean
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Setup
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS nordwerk;
USE nordwerk;

-- Imported tables were renamed to short names:
-- RENAME TABLE coa_clean TO coa, budget_clean TO budget, customers_clean TO customers,
--              cost_centers_clean TO cost_centers, gl_clean TO gl, invoices_clean TO invoices;

-- Reconcile row counts with Python after import
SELECT 'gl' AS table_name, COUNT(*) AS row_count FROM gl          -- expected 2183
UNION ALL SELECT 'budget', COUNT(*) FROM budget                   -- expected 936
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices               -- expected 900
UNION ALL SELECT 'customers', COUNT(*) FROM customers             -- expected 25
UNION ALL SELECT 'cost_centers', COUNT(*) FROM cost_centers       -- expected 8
UNION ALL SELECT 'coa', COUNT(*) FROM coa;                        -- expected 18

-- Finding during reconciliation: the Workbench import wizard silently dropped the
-- 47 unpaid invoices (empty payment_date). Table was reloaded from Python (pandas.to_sql).
SELECT status, COUNT(*) FROM invoices GROUP BY status;            -- Paid 853, Open 28, Disputed 19

-- Helper column: posting year
ALTER TABLE gl ADD COLUMN year INT;
SET SQL_SAFE_UPDATES = 0;
UPDATE gl SET year = YEAR(posting_date);

-- =====================================================================
-- CFO TASK 1: P&L 2024 vs 2025
-- =====================================================================

-- P&L by account group and year (LEFT JOIN keeps the 8 unmapped postings -> NULL)
SELECT coa.account_group, gl.year, ROUND(SUM(gl.amount), 2) AS total
FROM gl
LEFT JOIN coa ON gl.account_no = coa.account_no
GROUP BY coa.account_group, gl.year
ORDER BY coa.account_group, gl.year;

-- Gross Profit = Revenue + COGS (costs are stored as negative values)
SELECT gl.year, ROUND(SUM(gl.amount), 2) AS gross_profit
FROM gl
LEFT JOIN coa ON gl.account_no = coa.account_no
WHERE coa.account_group IN ('Revenue', 'COGS')
GROUP BY gl.year
ORDER BY gl.year;
-- 2024: 6,275,864 | 2025: 6,126,386

-- EBIT = Revenue + COGS + Personnel + OPEX
SELECT gl.year, ROUND(SUM(gl.amount), 2) AS ebit
FROM gl
LEFT JOIN coa ON gl.account_no = coa.account_no
WHERE coa.account_group IN ('Revenue', 'COGS', 'Personnel', 'OPEX')
GROUP BY gl.year
ORDER BY gl.year;
-- 2024: 1,296,848 | 2025: 620,934  -> EBIT -52%

-- =====================================================================
-- CFO TASK 2: Budget vs Actual 2025 by account
-- =====================================================================
WITH actual AS (
    SELECT account_no, SUM(amount) AS actual
    FROM gl
    WHERE year = 2025
    GROUP BY account_no
),
plan AS (
    SELECT account_no, SUM(budget_eur) AS budget
    FROM budget
    WHERE fiscal_year = 2025
    GROUP BY account_no
)
SELECT plan.account_no,
       coa.account_name,
       plan.budget,
       ROUND(actual.actual, 2)                                          AS actual,
       ROUND(actual.actual - plan.budget, 2)                            AS variance,
       ROUND((actual.actual - plan.budget) / ABS(plan.budget) * 100, 1) AS variance_pct
FROM plan
LEFT JOIN actual ON plan.account_no = actual.account_no
JOIN coa         ON plan.account_no = coa.account_no
ORDER BY variance;
-- Negative variance = worse than plan.
-- Top: Machine Sales -451,894 (-5.0%), Raw Materials -216,455 (-7.3%),
--      Marketing -80,122 (-17.2%), Consulting & Legal -25,397 (-17.9%)

-- Drill-down: Marketing per month (overspend Sep-Nov 2025)
SELECT MONTH(gl.posting_date) AS month, ROUND(SUM(gl.amount), 2) AS actual
FROM gl
JOIN coa ON gl.account_no = coa.account_no
WHERE gl.year = 2025 AND coa.account_name = 'Marketing & Advertising'
GROUP BY MONTH(gl.posting_date)
ORDER BY month;

-- Drill-down: Consulting & Legal per month (one-off cost in June 2025)
SELECT MONTH(gl.posting_date) AS month, ROUND(SUM(gl.amount), 2) AS actual
FROM gl
JOIN coa ON gl.account_no = coa.account_no
WHERE gl.year = 2025 AND coa.account_name = 'Consulting & Legal'
GROUP BY MONTH(gl.posting_date)
ORDER BY month;

-- Drill-down: Raw materials, budget vs actual per month (over plan from April 2025)
WITH actual AS (
    SELECT MONTH(posting_date) AS month, SUM(amount) AS actual
    FROM gl
    WHERE year = 2025 AND account_no = 5000
    GROUP BY MONTH(posting_date)
),
plan AS (
    SELECT month, SUM(budget_eur) AS budget
    FROM budget
    WHERE fiscal_year = 2025 AND account_no = 5000
    GROUP BY month
)
SELECT plan.month, plan.budget,
       ROUND(actual.actual, 2) AS actual,
       ROUND((actual.actual - plan.budget) / ABS(plan.budget) * 100, 1) AS variance_pct
FROM plan
LEFT JOIN actual ON plan.month = actual.month
ORDER BY plan.month;

-- =====================================================================
-- CFO TASK 3: Budget vs Actual 2025 by cost center
-- =====================================================================
WITH actual AS (
    SELECT cost_center, SUM(amount) AS actual
    FROM gl
    WHERE year = 2025
    GROUP BY cost_center
),
plan AS (
    SELECT cost_center, SUM(budget_eur) AS budget
    FROM budget
    WHERE fiscal_year = 2025
    GROUP BY cost_center
)
SELECT plan.cost_center,
       cost_centers.cost_center_name,
       plan.budget,
       ROUND(actual.actual, 2)                                          AS actual,
       ROUND(actual.actual - plan.budget, 2)                            AS variance,
       ROUND((actual.actual - plan.budget) / ABS(plan.budget) * 100, 1) AS variance_pct
FROM plan
LEFT JOIN actual  ON plan.cost_center = actual.cost_center
JOIN cost_centers ON plan.cost_center = cost_centers.cost_center
ORDER BY variance;
-- Sales International (CC110): -415,800 (-10.4%)

-- Drill-down: Sales International per month (about -20% vs plan from July 2025)
WITH actual AS (
    SELECT MONTH(posting_date) AS month, SUM(amount) AS actual
    FROM gl
    WHERE year = 2025 AND cost_center = 'CC110'
    GROUP BY MONTH(posting_date)
),
plan AS (
    SELECT month, SUM(budget_eur) AS budget
    FROM budget
    WHERE fiscal_year = 2025 AND cost_center = 'CC110'
    GROUP BY month
)
SELECT plan.month, plan.budget,
       ROUND(actual.actual, 2) AS actual,
       ROUND((actual.actual - plan.budget) / ABS(plan.budget) * 100, 1) AS variance_pct
FROM plan
LEFT JOIN actual ON plan.month = actual.month
ORDER BY plan.month;

-- =====================================================================
-- CFO TASK 4: Accounts receivable
-- =====================================================================

-- Late payers: average days late per customer (paid invoices only)
SELECT invoices.customer_id,
       customers.customer_name,
       customers.payment_terms_days,
       COUNT(*)                            AS invoices,
       ROUND(AVG(invoices.days_late), 1)   AS avg_days_late
FROM invoices
JOIN customers ON invoices.customer_id = customers.customer_id
WHERE invoices.status = 'Paid'
GROUP BY invoices.customer_id, customers.customer_name, customers.payment_terms_days
ORDER BY avg_days_late DESC;
-- Miele & Cie 36.1 | Caterpillar France 35.6 | Sandvik Sweden 31.9 | all others < 8

-- Aging report: open invoices as of 31.12.2025
SELECT
    CASE
        WHEN DATEDIFF('2025-12-31', due_date) <= 0  THEN '1. Not yet due'
        WHEN DATEDIFF('2025-12-31', due_date) <= 30 THEN '2. 1-30 days'
        WHEN DATEDIFF('2025-12-31', due_date) <= 60 THEN '3. 31-60 days'
        WHEN DATEDIFF('2025-12-31', due_date) <= 90 THEN '4. 61-90 days'
        ELSE '5. Over 90 days'
    END AS overdue_group,
    COUNT(*)                   AS invoices,
    ROUND(SUM(amount_eur), 2)  AS open_amount
FROM invoices
WHERE status <> 'Paid'
GROUP BY overdue_group
ORDER BY overdue_group;
-- Total open 835,002 | over 90 days: 15 invoices, 209,841
