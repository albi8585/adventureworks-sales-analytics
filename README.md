# AdventureWorks Analytics Pipeline

Portfolio project built on **AdventureWorks2022** to demonstrate an end-to-end analytics workflow based on SQL Server, Python and Power BI.

The project extends the public AdventureWorks database with a dedicated `project` schema, a simulated daily sales feed, SQL transformation logic and analytical views used as the semantic source for Power BI dashboards.

## Architecture

```text
AdventureWorks2022
      │
      ├── Historical AdventureWorks tables
      │
      ├── project schema
      │      ├── analytical copies / dimensions
      │      ├── orders_temp
      │      └── daily_orderdetails_temp
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
SQL analytical views
      │
      ▼
Power BI dashboards
```

## What the project demonstrates

- SQL Server data modelling on top of AdventureWorks2022
- Creation of a separate analytical `project` schema
- Python-based generation of realistic daily sales data
- Daily staging and loading workflow
- Historical product-cost handling and margin calculations
- Customer and product segmentation
- Cohort / retention and purchase-sequence analysis
- Power BI-ready fact and analytical views

## Repository structure

```text
python/
  genera_vendite.py                  Daily sales simulation and staging load

sql/
  setup/
    01_creazione_schema_project.sql  Project tables / schema objects
    02_popolamento_schema_project.sql Initial population from AdventureWorks

  etl/
    insert_orders_temp.sql
    insert_daily_orderdetails_temp.sql
    test_caricamento_giornaliero.sql

  maintenance/
    aggiornamenti_date_prezzi.sql
    reset_product_cost_history.sql

  views/
    01_fact_table_segmentazioni.sql  Fact table and segmentation views
    02_customer_analytics.sql        Cohort / customer analytics views

powerbi/
  Reserved for report screenshots or the PBIX file, when publishable.
```

## Daily simulation

`python/genera_vendite.py` connects to SQL Server using Windows authentication, analyses historical order distributions and creates a new simulated sales day.

The script generates:

- new `SalesOrderID` and `SalesOrderDetailID` values;
- order quantities and product mixes derived from historical distributions;
- customer, salesperson and territory assignments;
- order, due and shipping dates;
- records for `project.orders_temp` and `project.daily_orderdetails_temp`.

It also performs validation checks before loading the staging tables.

## Power BI layer

The SQL views under `sql/views` create reporting-ready datasets used for analyses such as:

- revenue and margin performance;
- customer segmentation;
- product/customer activity over recent periods;
- cohort and retention analysis;
- purchase sequence / next-purchase behaviour.

## Requirements

- SQL Server with the AdventureWorks2022 sample database
- Python 3.x
- Microsoft ODBC Driver 17 for SQL Server
- Python packages listed in `requirements.txt`
- Power BI Desktop for the reporting layer

Install Python dependencies with:

```bash
pip install -r requirements.txt
```

## Notes

AdventureWorks is a Microsoft sample database. This repository contains the additional SQL/Python logic developed for the portfolio project, not the AdventureWorks database itself.

The generated `insert_*_temp.sql` files are snapshots of one simulated run. The Python script is the component responsible for regenerating those staging records.


## Repository
https://github.com/albi8585/adventureworks-sales-analytics

## Local configuration
The Python sales generator reads the SQL Server instance and database from the `SQL_SERVER` and `SQL_DATABASE` environment variables. No credentials are stored in the repository. See `.env.example` for the expected configuration.
