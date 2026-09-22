# AdventureWorks Sales Analytics Pipeline

Portfolio project built on **AdventureWorks2022** to demonstrate an end-to-end analytics workflow based on **SQL Server, Python and Power BI**.

The project transforms the static AdventureWorks sample database into a simplified **continuously evolving business scenario**. Historical sales are used as the baseline, Python generates new daily transactions, SQL Server manages the ETL and analytical layers, and Power BI turns the resulting data into a decision-oriented reporting workflow.

A key extension of the project is the **commercial action monitoring process**: underperforming Country × Subcategory combinations can be identified, their starting position can be frozen in a SQL snapshot, and subsequent sales performance can be compared with that baseline to measure the evolution of the commercial action over time.

---

## Architecture

```text
AdventureWorks2022
        │
        ├── Historical AdventureWorks tables
        │
        ▼
project schema
        │
        ├── Historical project tables
        ├── Staging tables
        ├── Product cost history
        └── Power BI dimensions
        │
        ▲
        │
Python daily sales simulator
        │
        ▼
Daily staging tables
        │
        ▼
SQL Server ETL / stored procedures
        │
        ▼
Historical project tables
        │
        ├── Star-schema dimensions
        ├── Analytical SQL views
        └── Commercial monitoring snapshots
        │
        ▼
Power BI
        │
        ├── Business performance analysis
        ├── Commercial action prioritisation
        ├── Action monitoring
        └── Day-by-day monitoring
```

---

## What the project demonstrates

- SQL Server data modelling on top of AdventureWorks2022
- Creation of a separate analytical `project` schema
- Python-based generation of simulated daily sales
- Daily staging, validation and loading workflow
- Historical product-cost handling and margin calculations
- Reporting-oriented star schema for Power BI
- Customer and product segmentation
- Cohort, retention and purchase-sequence analysis
- Power BI-ready fact and analytical SQL views
- Country × Subcategory commercial prioritisation
- Snapshot-based monitoring of commercial actions
- Comparison between a frozen baseline and continuously evolving sales
- Separation between reusable SQL business logic and interactive DAX measures

---

## Business analytics workflow

The Power BI report is designed as a **decision journey**, rather than as a collection of independent dashboards.

```text
Business Performance
        │
        ▼
Identify performance gaps
        │
        ▼
Commercial Actions
        │
        ▼
Select Country × Subcategory priorities
        │
        ▼
Create Monitoring Snapshot
        │
        ▼
Freeze the starting business position
        │
        ▼
Action Monitoring
        │
        ▼
Compare current performance with the snapshot
        │
        ▼
Day-by-Day Monitoring
        │
        ▼
Observe recovery and ongoing sales evolution
```

This creates two complementary monitoring levels:

- **Periodic Business Review** — evaluates overall performance and identifies Country × Subcategory combinations requiring attention.
- **Continuous Monitoring** — follows selected commercial actions after their baseline has been frozen and measures how performance evolves as new simulated sales are generated.

---

## Commercial Action Monitoring

The monitoring layer extends the reporting workflow from **identifying a problem** to **following what happens after an action is initiated**.

### 1. Commercial prioritisation

Power BI evaluates sales performance by **Country × Subcategory** and highlights combinations where current revenue is below the expected goal.

The analysis provides the basis for selecting potential commercial actions.

### 2. Snapshot creation

When a combination is selected for monitoring, a SQL Server stored procedure creates a snapshot of its starting position.

The snapshot stores the relevant business state at the beginning of the monitoring period, including information such as:

- Country
- Subcategory
- Snapshot date
- Revenue at snapshot
- Goal at snapshot
- Initial revenue gap
- Priority information

The snapshot therefore acts as a **fixed baseline**. It is not recalculated when new sales arrive.

### 3. Monitoring view

`project.VW_ActionMonitoring` combines the frozen snapshot with the continuously updated sales fact layer.

Conceptually:

```text
                 FROZEN BASELINE
                       │
                       │
Monitoring Snapshot ───┤
                       │
                       ▼
                VW_ActionMonitoring
                       ▲
                       │
                       │
Current Sales Data ────┤
                       │
                 EVOLVING DATA
```

This makes it possible to preserve the business situation that triggered the action while current revenue continues to evolve through the daily simulation pipeline.

### 4. Measuring the action over time

Power BI can then compare the initial gap with the current situation using monitoring KPIs such as:

- **Initial Gap** — revenue gap when monitoring started
- **Expected Recovery** — recovery target defined for the action
- **Actual Recovery** — reduction of the initial gap observed after the snapshot
- **Target Achievement** — actual recovery relative to expected recovery

The objective is not to claim causal attribution between an action and sales growth, but to provide a structured way to **track whether the selected commercial gap is recovering after the action starts**.

---

## Database setup

Database creation is separated into sequential scripts:

```text
01_create_project_schema.sql
        ↓
02_load_initial_data.sql
        ↓
03_post_load_transformations.sql
        ↓
04_create_powerbi_dimensions.sql
```

The sequence reflects the logical data-engineering flow:

1. **Schema creation** — creates project tables, constraints and monitoring support tables.
2. **Initial load** — copies the required AdventureWorks data into the `project` schema.
3. **Post-load transformations** — aligns historical dates, manages historical costs and recalculates commercial values.
4. **Power BI dimensions** — creates reporting-ready dimensions for the semantic model.

---

## Power BI star schema

The reporting layer uses a simplified star-schema approach. Normalized SQL tables are retained for data processing, while denormalized dimensions make filtering and drill-down operations easier in Power BI.

| Dimension | Purpose | Main key |
|---|---|---|
| `project.Territory` | Geography / sales territory | `TerritoryID` |
| `project.dimension_type_customer` | Customer name and customer type | `customerId` |
| `project.dimensioni_prod_cat` | Product → Subcategory → Category hierarchy | `productid` |
| `project.calendar` | Date, year, month and quarter hierarchy | `data` |

Typical relationships with the sales fact layer are:

```text
                        calendar
                           │
                       OrderDate
                           │
                           ▼
dimensioni_prod_cat → SALES FACT ← Territory
      ProductID                         TerritoryID
                           ▲
                           │
                       CustomerID
                           │
               dimension_type_customer
```

The product and customer dimensions are deliberately denormalized for reporting, while the underlying normalized project tables remain available for ETL and SQL processing.

---

## Daily sales simulation

`python/sales_simulation.py` connects to SQL Server, analyses historical order distributions and creates a new simulated sales day.

The script generates:

- new `SalesOrderID` and `SalesOrderDetailID` values;
- order quantities and product mixes derived from historical distributions;
- customer, salesperson and territory assignments;
- order, due and shipping dates;
- records for the project staging tables.

Validation checks are performed before the simulated batch enters the historical project layer.

The purpose of the simulator is to make a static sample database behave more like an **ongoing business environment**, allowing dashboards and monitoring KPIs to change over time.

---

## Daily ETL Pipeline and Testing

The project includes an automated daily ETL pipeline designed to simulate a continuously updated sales database.

```text
Python Sales Simulation
        │
        ▼
Daily Staging Tables
        │
        ▼
Daily Load Stored Procedure
        │
        ▼
Historical Project Tables
        │
        ▼
Analytical SQL Views
        │
        ▼
Power BI
```

The automated procedure checks whether new unprocessed data is available and executes the historical load only when required.

A dedicated **test/reset workflow** allows the loading process to be validated repeatedly without permanently modifying the baseline dataset.

```text
Test Daily Load
      │
      ▼
Historical Tables
      │
      ▼
Validation
      │
      ▼
Reset Procedure
      │
      ▼
Pre-test State
```

This is a controlled test/reset workflow rather than a full database backup or transactional rollback: only data affected by the simulated test load is restored.

---

## Power BI analytical layer

The reporting layer supports analyses including:

- revenue and margin performance;
- current performance versus historical benchmarks and goals;
- Country × Subcategory prioritisation;
- customer segmentation;
- cohort and retention analysis;
- repurchase timing;
- purchase sequence / next-purchase behaviour;
- commercial action monitoring;
- recovery versus the frozen snapshot baseline;
- day-by-day sales evolution.

The report separates **diagnosis**, **action selection** and **monitoring**, so that the analytical workflow continues after an underperforming area has been identified.

---

## Technical Challenges & Design Decisions

### Making a static sample database behave like a live system

AdventureWorks is a historical sample database. The project shifts the historical timeline and combines it with a Python daily-sales simulator so that the reporting layer evolves over time instead of remaining a static demonstration dataset.

### Preserving historical product costs

Profitability cannot be calculated correctly using only the current product cost. The project keeps a separate product cost history and aligns its validity periods with the shifted order timeline.

### Separating staging from analytical tables

Simulated orders are not inserted directly into the reporting tables. They first pass through staging tables and SQL validation/loading logic before reaching the historical project layer.

### Separating transactional modelling from reporting modelling

The SQL processing layer retains normalized entities, while Power BI consumes simplified dimensions such as product hierarchy, customer type, territory and calendar.

### Freezing the starting point of a commercial action

A monitoring dashboard cannot reliably evaluate progress if its starting baseline changes every time the underlying data is refreshed.

For this reason, the project uses a dedicated **snapshot table and stored procedure** to preserve the selected Country × Subcategory position at the beginning of the action. The monitoring view then combines that fixed baseline with current sales data.

This allows the report to answer two different questions:

```text
What was the situation when the action started?
                    vs.
What is the situation now?
```

### Keeping SQL and DAX responsibilities distinct

Reusable dataset logic and monitoring baselines are handled upstream in SQL Server.

Power BI / DAX is mainly responsible for filter-context-dependent KPIs, goals, clusters, recovery calculations and interactive analysis.

---

## Repository structure

```text
README.md

python/
  sales_simulation.py

sql/
  database_build/
    01_create_project_schema.sql
    02_load_initial_data.sql
    03_post_load_transformations.sql
    04_create_powerbi_dimensions.sql

  daily_pipeline/
    01_daily_table_load_procedure.sql
    02_daily_automation_procedure.sql

  testing/
    01_daily_load_test.sql
    02_reset_historical_tables_for_test_procedure.sql

  analytics/
    01_powerbi_fact_view.sql
    02_customer_analytics_views.sql
    03_create_action_monitoring_snapshot_procedure.sql
    04_action_monitoring_view.sql

powerbi/
  Reserved for report screenshots or the PBIX file, when publishable.
```

The analytics layer therefore progresses from general reporting datasets to the commercial monitoring workflow:

```text
Power BI Fact View
        ↓
Customer Analytics
        ↓
Monitoring Snapshot Procedure
        ↓
Action Monitoring View
```

---

## Requirements

- SQL Server with the AdventureWorks2022 sample database
- Python 3.x
- Microsoft ODBC Driver for SQL Server
- Python packages listed in `requirements.txt`
- Power BI Desktop

Install Python dependencies with:

```bash
pip install -r requirements.txt
```

---

## Notes

AdventureWorks is a Microsoft sample database. This repository contains the additional SQL, Python and BI logic developed for the portfolio project, not the AdventureWorks database itself.

The sales generated after the historical baseline are **simulated transactions** and are intended to reproduce the behaviour of an evolving analytical environment.

The monitoring workflow tracks changes after a commercial action baseline is created; it should not be interpreted as proof that the action itself caused the observed sales change.

---

## Repository

https://github.com/albi8585/adventureworks-sales-analytics

## Local configuration

The Python sales generator reads the SQL Server instance and database from environment variables. No credentials are stored in the repository. See `.env.example` for the expected configuration.
