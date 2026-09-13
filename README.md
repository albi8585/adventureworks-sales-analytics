[README_AdventureWorks.md](https://github.com/user-attachments/files/32163613/README_AdventureWorks.md)
# AdventureWorks Sales Analytics

## End-to-End Sales Analytics Workflow with Python, SQL Server and Power BI

This project reproduces a **simplified end-to-end analytics workflow
built around a realistic business scenario**, starting from the public
AdventureWorks database.

The objective is not only to analyze historical sales, but to build a
workflow that can continue beyond the original dataset through
**simulated daily transactions, automated SQL processing and Power BI
analysis designed to support commercial decision-making**.

The project follows this flow:

**Historical Data → Data Exploration → SQL Data Mart → Data Preparation
→ Process Automation → Python Sales Simulation → Power BI Analysis &
Decisions**

------------------------------------------------------------------------

## Project Objectives

The project was designed to reproduce the main stages of a business
analytics pipeline:

-   explore historical sales patterns and identify data-quality issues;
-   create a dedicated analytical layer separated from the original
    AdventureWorks tables;
-   prepare and align historical data for the project timeline;
-   preserve historical product prices and costs for time-consistent
    analysis;
-   simulate new daily sales transactions using Python;
-   validate and load new data through an automated SQL Server pipeline;
-   expose analytical views and KPIs to Power BI;
-   organize BI analysis as a decision journey from overall performance
    to commercial priorities.

------------------------------------------------------------------------

## Architecture

### 1. Data Exploration

Historical AdventureWorks sales were analyzed before building the
simulation and analytical pipeline.

The exploration highlighted an important issue in the historical daily
sales distribution: **abnormal end-of-month quantity spikes** made
direct random sampling from historical daily totals unsuitable for
generating realistic daily transactions.

This finding influenced the simulation approach later implemented in
Python.

Data inconsistencies relevant to the analytical model were also
identified and addressed before generating new sales.

------------------------------------------------------------------------

### 2. SQL Server --- Project Data Mart

A dedicated `project` schema separates the analytical project from the
original AdventureWorks source tables.

Only the entities required by the project are selected and loaded into a
dedicated model containing sales facts, dimensions and supporting
historical tables.

The analytical layer includes information related to:

-   sales orders and order details;
-   customers;
-   products and product categories;
-   sales territories;
-   special offers and discounts;
-   product price history;
-   product cost history;
-   calendar and BI dimensions.

The original AdventureWorks tables remain reference sources, while
project-specific transformations are performed inside the dedicated
schema.

------------------------------------------------------------------------

### 3. SQL Server --- Data Preparation and Historical Consistency

Historical data is transformed into a simulation-ready analytical layer.

The original AdventureWorks timeline is shifted to the project timeline
while preserving the chronological relationships between orders, prices
and costs.

Two historical tables play an important role:

#### `project.ProductListPriceHistory`

Stores the historical selling-price intervals for each product.

Its validity periods are aligned with the shifted order timeline so that
the selling price valid on a specific `OrderDate` can be determined
consistently.

#### `project.ProductCostHistory`

Stores the historical `StandardCost` intervals for each product.

The same temporal alignment is applied so that each sale can be
associated with the cost valid at that point in time, providing a
consistent basis for **profit and margin analysis**.

The latest price and cost intervals are kept open-ended so they can also
support current and subsequently generated transactions.

This approach avoids relying only on the current `ListPrice` and
`StandardCost` stored in the product table.

------------------------------------------------------------------------

### 4. SQL Server --- Automation and BI Views

The daily data pipeline is automated through SQL Server stored
procedures and SQL Server Agent.

The workflow manages:

**Staging → Validation → Transformation → Final Load → BI-ready data**

The SQL layer also exposes dedicated analytical views and KPIs to Power
BI, reducing transformation logic inside the reporting layer and keeping
business calculations closer to the analytical database.

------------------------------------------------------------------------

## Python Sales Simulation

Python extends the dataset beyond the original AdventureWorks historical
period by generating new daily sales transactions.

### Simulation Logic

Historical daily quantities could not be sampled directly because of the
abnormal end-of-month spikes identified during Data Exploration.

The simulation therefore uses the **historical average daily sold
quantity as its reference point** and introduces controlled variability
through a Weibull distribution.

Conceptually:

``` text
daily target = historical daily quantity mean × random factor
```

The random factor is drawn from a Weibull distribution and normalized so
that simulated daily targets remain centered around historical average
demand while still showing realistic day-to-day variability.

The current implementation uses a Weibull shape parameter:

``` text
β = 1.5
```

Once the daily target is defined, Python generates the simulated sales
records and writes them to the SQL staging layer, where they are
validated and loaded by the automated SQL process.

------------------------------------------------------------------------

## Power BI --- From Performance to Commercial Priorities

Power BI is structured as a **decision journey rather than a collection
of independent dashboards**.

The analysis progressively narrows from overall business performance to
specific commercial priorities.

### 1 --- Understand

**How is the business performing overall?**

Main indicators include:

-   Revenue
-   Profit / Margin
-   Year-over-Year performance
-   Goal achievement

### 2 --- Diagnose

**Where is performance changing?**

The analysis supports drill-down across two main dimensions:

``` text
Region → Country
Category → Subcategory
```

This makes it possible to identify where performance changes originate.

### 3 --- Prioritize

**Which combinations deserve action first?**

Country × Subcategory combinations are evaluated using performance
versus goal and potential commercial impact.

The final objective is to answer a practical business question:

> **Where should I act first --- and why?**

Commercial priorities are classified into action groups such as
**High**, **Medium**, **Monitor**, **New Opportunity** and **No
Action**, helping translate analytical results into an actionable view.

------------------------------------------------------------------------

## Technology Stack

  -----------------------------------------------------------------------
  Technology                          Role
  ----------------------------------- -----------------------------------
  **SQL Server**                      Data mart, transformations,
                                      historical alignment, staging,
                                      validation and automated loading

  **SQL Server Agent**                Scheduling and execution of the
                                      daily SQL pipeline

  **Python**                          Historical-pattern analysis and
                                      daily sales simulation

  **pandas / NumPy**                  Data processing and simulation
                                      logic

  **Power BI**                        Data modeling, KPI analysis,
                                      drill-down and commercial
                                      prioritization

  **DAX**                             Business measures, comparisons,
                                      goals, clustering and analytical
                                      logic

  **AdventureWorks**                  Public source dataset
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## Repository Structure

``` text
adventureworks-sales-analytics/
│
├── SQL/
│   ├── schema creation
│   ├── initial data load
│   ├── post-load transformations
│   ├── daily load procedures
│   ├── automation procedures
│   ├── Power BI dimensions
│   └── analytical / KPI views
│
├── Python/
│   └── daily sales simulation
│
└── README.md
```

The SQL scripts are organized to separate **initial project setup**,
**historical preparation**, **daily processing** and **BI-serving
logic**.

------------------------------------------------------------------------

## End-to-End Workflow

``` text
AdventureWorks
      │
      ▼
Historical Sales Analysis
      │
      ▼
SQL Server Project Data Mart
      │
      ▼
Historical Data Preparation
Price / Cost Temporal Alignment
      │
      ▼
Python Simulation Logic
      │
      ▼
Simulated Daily Sales
      │
      ▼
SQL Staging & Validation
      │
      ▼
Automated Final Load
      │
      ▼
BI Views & KPIs
      │
      ▼
Power BI
Understand → Diagnose → Prioritize
```

------------------------------------------------------------------------

## Key Project Takeaways

The project focuses on the integration of **data exploration, data
engineering, simulation and business analytics** rather than on a single
dashboard or isolated analysis.

The main design choices were:

-   separating the project analytical layer from the source database;
-   validating historical patterns before defining the simulation;
-   preserving temporal consistency between orders, selling prices and
    product costs;
-   generating new daily transactions instead of keeping the dataset
    static;
-   automating the recurring SQL load process;
-   preparing BI-oriented views and KPIs in SQL Server;
-   structuring Power BI around a progressive business decision process.

The result is a small but complete analytics workflow that moves from
**raw historical data to continuously generated transactions and
decision-oriented BI analysis**.

------------------------------------------------------------------------

## Dataset

This project uses the public **Microsoft AdventureWorks** sample
database as its starting point.

The project does not represent a real company or live commercial
environment. It uses public sample data and simulated transactions to
reproduce a simplified but realistic analytics workflow for portfolio
and learning purposes.

------------------------------------------------------------------------

## Author

**Alberto Gubernati**

Data Analytics portfolio project focused on SQL Server, Python, Power BI
and end-to-end analytical workflows.
