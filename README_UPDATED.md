# AdventureWorks Analytics Pipeline

Portfolio project built on **AdventureWorks2022** to demonstrate an end-to-end analytics workflow based on SQL Server, Python and Power BI.

The project extends the public AdventureWorks database with a dedicated `project` schema, a simulated daily sales feed, SQL transformation logic, a reporting-oriented star schema and analytical views used as the semantic source for Power BI dashboards.

## Architecture

```text
AdventureWorks2022
      │
      ├── Historical AdventureWorks tables
      │
      ├── project schema
      │      ├── historical project tables
      │      ├── staging tables
      │      └── Power BI dimensions
      │
Python sales simulator
      │
      ▼
Daily staging tables
      │
SQL Server ETL / stored procedures
      │
      ▼
Historical project tables
      │
      ├── Star-schema dimensions
      │
      └── Analytical SQL views
      │
      ▼
Power BI dashboards
```

## What the project demonstrates

- SQL Server data modelling on top of AdventureWorks2022
- Creation of a separate analytical `project` schema
- Python-based generation of simulated daily sales data
- Daily staging, validation and loading workflow
- Historical product-cost handling and margin calculations
- Reporting-oriented star schema for Power BI
- Customer and product segmentation
- Cohort / retention and purchase-sequence analysis
- Power BI-ready fact and analytical views

## Database setup

The clean repository version separates database creation into sequential scripts:

```text
01_create_project_schema.sql
        ↓
02_load_initial_data.sql
        ↓
03_post_load_transformations.sql
        ↓
04_create_powerbi_dimensions.sql
```

The separation reflects the logical data-engineering flow:

1. **Schema creation** — creates the final project tables and constraints.
2. **Initial load** — copies the required AdventureWorks data into the `project` schema.
3. **Post-load transformations** — aligns historical dates, manages historical costs and recalculates commercial values.
4. **Power BI dimensions** — creates reporting-ready dimensions for the semantic model.

## Power BI star schema

The reporting layer uses a simplified star-schema approach. Normalized SQL tables are retained for data processing, while denormalized dimensions make filtering and drill-down operations easier in Power BI.

The main dimensions are:

| Dimension | Purpose | Main key |
|---|---|---|
| `project.Territory_prj` | Geography / sales territory | `TerritoryID` |
| `project.dimensioni_type_customer_prj` | Customer name and customer type | `customerId` |
| `project.dimensioni_prod_cat_prj` | Product → Subcategory → Category hierarchy | `productid` |
| `project.calendario_prj` | Date, year, month and quarter hierarchy | `data` |

Typical relationships with the sales fact layer are:

```text
                        calendario_prj
                             │
                          OrderDate
                             │
                             ▼
dimensioni_prod_cat_prj → SALES FACT ← Territory_prj
        ProductID                           TerritoryID
                             ▲
                             │
                         CustomerID
                             │
               dimensioni_type_customer_prj
```

The product and customer dimensions are deliberately denormalized for reporting, while the underlying normalized project tables remain available for ETL and SQL processing.

## Daily simulation

`python/genera_vendite.py` connects to SQL Server, analyses historical order distributions and creates a new simulated sales day.

The script generates:

- new `SalesOrderID` and `SalesOrderDetailID` values;
- order quantities and product mixes derived from historical distributions;
- customer, salesperson and territory assignments;
- order, due and shipping dates;
- records for the project staging tables.

It also performs validation checks before loading the staging layer.

## Power BI layer

The SQL reporting layer supports analyses such as:

- revenue and margin performance;
- current performance versus historical growth and goals;
- Country × Subcategory commercial prioritisation;
- customer segmentation;
- cohort and retention analysis;
- repurchase timing;
- purchase sequence / next-purchase behaviour.

## Technical Challenges & Design Decisions

### Making a static sample database behave like a live system
AdventureWorks is a historical sample database. The project shifts the historical timeline and combines it with a Python daily-sales simulator so that the reporting layer can evolve over time instead of remaining a static demonstration dataset.

### Preserving historical product costs
Profitability cannot be calculated correctly using only the current product cost. The project keeps a separate product cost history and aligns its validity periods with the shifted order timeline.

### Separating staging from analytical tables
Simulated orders are not inserted directly into the reporting tables. They first pass through staging tables and SQL validation / loading logic before reaching the historical project layer.

### Separating transactional modelling from reporting modelling
The SQL processing layer retains normalized entities, while Power BI consumes simplified dimensions such as product hierarchy, customer type, territory and calendar. This keeps ETL logic and reporting requirements separate.

### Keeping SQL and DAX responsibilities distinct
Transformations that define reusable datasets are handled upstream in SQL, while Power BI / DAX is mainly used for filter-context-dependent KPI, goals, performance clusters and interactive analysis.

## Repository structure

```text
python/
  genera_vendite.py

sql/
  setup/
    01_create_project_schema.sql
    02_load_initial_data.sql
    03_post_load_transformations.sql
    04_create_powerbi_dimensions.sql

  etl/
    insert_orders_temp.sql
    insert_daily_orderdetails_temp.sql
    test_caricamento_giornaliero.sql

  maintenance/
    reset_product_cost_history.sql

  views/
    fact_table_segmentazioni.sql
    customer_analytics.sql

powerbi/
  Reserved for report screenshots or the PBIX file, when publishable.
```

## Requirements

- SQL Server with the AdventureWorks2022 sample database
- Python 3.x
- Microsoft ODBC Driver for SQL Server
- Python packages listed in `requirements.txt`
- Power BI Desktop for the reporting layer

Install Python dependencies with:

```bash
pip install -r requirements.txt
```

## Notes

AdventureWorks is a Microsoft sample database. This repository contains the additional SQL/Python logic developed for the portfolio project, not the AdventureWorks database itself.

The generated staging SQL files are snapshots of simulated runs. The Python script is responsible for generating new daily staging records.

## Repository

https://github.com/albi8585/adventureworks-sales-analytics

## Local configuration

The Python sales generator reads the SQL Server instance and database from environment variables. No credentials are stored in the repository. See `.env.example` for the expected configuration.
