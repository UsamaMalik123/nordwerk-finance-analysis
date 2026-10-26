# NordWerk Maschinenbau GmbH: Finance Data Handover

**From:** Dr. Petra Koch, CFO
**To:** Data Analyst (new hire)
**Subject:** Your first project: FY2025 Budget vs. Actual and Cash review

Hi,

welcome to the team! As discussed, here are the raw exports from our ERP system for FY2024 and FY2025. Be warned: the exports are not clean. Our systems were never fully integrated, so please check everything before you trust a number.

The board meeting is coming up. I need the following:

## What I need from you

1. **P&L overview (2024 vs. 2025):** Revenue, COGS, Gross Margin %, OPEX, EBIT per month and per year.
2. **Budget vs. Actual (FY2025):** Variance in EUR and % by account group and by cost center. Which 3 variances are the biggest, and what is behind them?
3. **Cost center report:** Which departments overspent their budget?
4. **Accounts Receivable:**
   - DSO (Days Sales Outstanding) per month
   - Aging report of open invoices (0–30, 31–60, 61–90, 90+ days overdue) as of 31.12.2025
   - Which customers pay late most often? Should we reconsider their payment terms?
5. **Dashboard** for the management team (Power BI or Tableau) with filters by year, month and cost center.
6. **Short summary** (max. 1 page): 3–5 key findings and recommendations.

## Files

| File | Source system | Description |
|---|---|---|
| `general_ledger_2024_2025.csv` | ERP (semicolon-separated!) | All posted journal entries. Revenue is positive, costs are negative. |
| `budget_2024_2025.xlsx` | Controlling (Excel) | Monthly budget per cost center and account |
| `chart_of_accounts.csv` | ERP | Account numbers, names, groups |
| `cost_centers.csv` | HR / Controlling | Cost centers, departments, managers |
| `customers.csv` | CRM | Customer master data incl. payment terms |
| `accounts_receivable_invoices.xlsx` | ERP AR module | Customer invoices and payment dates |

## Known data issues (that we know of...)

- The GL export has **mixed date formats** (ISO, German `dd.mm.yyyy`, and `dd/mm/yyyy`).
- Some amounts were exported with a **German decimal comma** and are stored as text.
- The international sales team sometimes books in **USD**. Use a fixed rate of **1 EUR = 1.09 USD**.
- I suspect some entries were **posted twice**.
- IT ran **test postings** in March 2025. These must be excluded.
- Some entries have **no cost center** or inconsistent spelling. Some vendor names have extra spaces.
- One account number in the GL **does not exist** in the chart of accounts. Please find it and flag it.

Please document every cleaning step, as our auditors will ask.

Thanks!
Petra

---

## Suggested tool workflow (for your portfolio)

| Step | Tool | Task |
|---|---|---|
| 1. Explore and clean | **Python (pandas)** | Parse dates, fix decimals, convert USD, remove duplicates and test postings, standardise cost centers, flag unknown account |
| 2. Store and query | **SQL (MySQL Workbench)** | Load the cleaned tables, write queries for P&L, variance, DSO and aging (JOINs, CTEs, CASE, window functions) |
| 3. Quick checks | **Excel** | Pivot tables for P&L by month; reconcile totals against your SQL results |
| 4. Dashboard | **Power BI** (and/or **Tableau**) | P&L page, Budget vs. Actual page, AR & Cash page |
| 5. Present | **GitHub + 1-page summary** | README, screenshots, key findings |

**Tip:** Real findings are hidden in this data. A good analyst will find at least 4 clear stories in FY2025.
