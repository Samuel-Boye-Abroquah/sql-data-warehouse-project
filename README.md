# SQL Data Warehouse Project

An end-to-end data warehouse built from raw CRM and ERP source files through a full **Bronze → Silver → Gold (Medallion Architecture)** pipeline in MySQL, feeding a Power BI reporting layer via ODBC.

This project is a hands-on build covering the full lifecycle of a data warehouse: raw ingestion, data cleaning and standardization, dimensional modeling, data quality validation, and documentation — not just a single script, but a repeatable, documented pipeline.

---

## Architecture

![Data Flow: Source to Gold Layer](docs/data_flow_bronze_silver_gold.png)

- **Bronze** — raw data loaded exactly as extracted from source (CRM and ERP), untouched.
- **Silver** — cleaned, standardized, and deduplicated: consistent codes (gender, marital status, country, product line), validated dates, corrected price/quantity/sales inconsistencies.
- **Gold** — business-ready star schema: `dim_customers`, `dim_products`, and `fact_sales`, built as views on top of Silver with surrogate keys, ready for reporting.

---

## Data Sources

| System | Tables |
|---|---|
| **CRM** | `crm_sales_details`, `crm_cust_info`, `crm_prd_info` |
| **ERP** | `erp_cust_az12` (customer demographics), `erp_loc_a101` (location), `erp_px_cat_g1v2` (product category) |

---

## Project Structure

```
sql-data-warehouse-project/
├── scripts/
│   ├── bronze/          # Raw table DDL and load scripts
│   ├── silver/          # Cleaning, standardization, and transformation logic
│   └── gold/            # Business-ready views: dim_customers, dim_products, fact_sales
├── tests/
│   └── quality_checks/  # Data quality validation queries, organized by source table
└── docs/
    ├── data_flow_bronze_silver_gold.png
    ├── Naming_Conventions.docx
    └── Gold_Layer_Data_Catalog.docx
```

---

## Data Model

The Gold layer is a standard star schema:

- **`fact_sales`** — one row per order line, referencing both dimensions via surrogate keys (`customer_key`, `product_key`)
- **`dim_customers`** — CRM customer records enriched with ERP demographic and location data
- **`dim_products`** — CRM product records enriched with ERP category data, filtered to current product versions

Full column-level definitions are documented in [`docs/Gold_Layer_Data_Catalog.docx`](docs/Gold_Layer_Data_Catalog.docx).

---

## Data Quality

Every Silver table is validated before being trusted downstream. Checks include:

- Primary key null/duplicate checks on every source table
- Whitespace and formatting consistency
- Code standardization (gender, marital status, country, product line) verified against raw distinct values
- Date validity (format, logical order, out-of-range values)
- Price/quantity/sales consistency (`sales = quantity × price`, no null/negative values)
- Referential integrity between `fact_sales` and both dimension tables
- Cross-source key alignment between CRM and ERP customer records
- Duplicate checks on keys that are only created by a cleaning transformation itself (e.g. the ERP `NAS`-prefix strip)

Full validation queries: [`tests/quality_checks/`](tests/quality_checks).

---

## Tools & Technologies

| Layer | Tools |
|---|---|
| Database | MySQL 8 |
| Transformation | SQL (CTEs, window functions, recursive CTEs) |
| Documentation | Markdown, Word (naming conventions, data catalog) |
| Visualization | Power BI (connected via ODBC) |

---

## How to Run

1. Run the bronze layer scripts to create and load raw tables from source CSVs.
2. Run `scripts/silver/` to build the cleaned Silver layer.
3. Run `scripts/gold/` to create the Gold layer views.
4. Run the scripts in `tests/quality_checks/` to validate each layer before trusting it.
5. Connect Power BI Desktop to the database via ODBC and build the reporting layer on top of the Gold views.

---

## Known Limitations & Next Steps

Documented transparently rather than hidden — every real project has trade-offs, and these are the ones I'm aware of in this build:

- **`sls_price` / `sls_sales` correction logic** in the Silver layer computes both values independently from the same raw source row rather than referencing each other's cleaned result — a narrow edge case (raw price null, raw sales otherwise valid) can pass without correction. Noted in the script; a staged subquery would close this fully.
- **`prd_end_dt` versioning** is derived by partitioning on product *name* rather than a stable product key — correct for this dataset, but would need revisiting if product names are ever reused or inconsistently formatted.
- **Naming convention documentation** currently has a couple of inconsistencies against the actual implementation (flagged directly in `docs/Naming_Conventions.docx`) — pending reconciliation between the documented standard and the tables as built.
- **Stored procedures** are not yet implemented — Bronze and Silver layers currently run as plain SQL scripts rather than encapsulated, parameterized procedures. Documented as the intended next step.

---

## About

Built by **Samuel Boye Abroquah** — Quality Assurance & Data Analytics professional, applying 12+ years of process-validation discipline to data engineering.

[LinkedIn](https://linkedin.com/in/Samuel-Boye-Abroquah)
