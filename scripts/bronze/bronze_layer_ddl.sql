/*
=============================================================
LOAD BRONZE LAYER DATA
=============================================================

Purpose:
    Create Bronze Layer tables and load raw CRM and ERP data
    from source CSV files into the Data Warehouse.

Source Files:
    - cust_info.csv
    - prd_info.csv
    - sales_details.csv
    - CUST_AZ12.csv
    - LOC_A101.csv
    - PX_CAT_G1V2.csv

Author:
    Samuel Boye Abroquah

=============================================================
*/

USE DataWarehouse;

-- =========================================================
-- CRM CUSTOMER INFORMATION
-- =========================================================

DROP TABLE IF EXISTS bronze_crm_cus_info;

CREATE TABLE bronze_crm_cus_info (
    cst_id VARCHAR(50),
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date VARCHAR(50)
);

TRUNCATE TABLE bronze_crm_cus_info;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/cust_info.csv'
INTO TABLE bronze_crm_cus_info
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;


-- =========================================================
-- CRM PRODUCT INFORMATION
-- =========================================================

DROP TABLE IF EXISTS bronze_crm_prd_info;

CREATE TABLE bronze_crm_prd_info (
    prd_id VARCHAR(50),
    prd_key VARCHAR(50),
    prd_nm VARCHAR(100),
    prd_cost VARCHAR(50),
    prd_line VARCHAR(50),
    prd_start_dt VARCHAR(50),
    prd_end_dt VARCHAR(50)
);

TRUNCATE TABLE bronze_crm_prd_info;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/prd_info.csv'
INTO TABLE bronze_crm_prd_info
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;


-- =========================================================
-- CRM SALES DETAILS
-- =========================================================

DROP TABLE IF EXISTS bronze_crm_sales_details;

CREATE TABLE bronze_crm_sales_details (
    sls_ord_num VARCHAR(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id VARCHAR(50),
    sls_order_dt VARCHAR(50),
    sls_ship_dt VARCHAR(50),
    sls_due_dt VARCHAR(50),
    sls_sales VARCHAR(50),
    sls_quantity VARCHAR(50),
    sls_price VARCHAR(50)
);

TRUNCATE TABLE bronze_crm_sales_details;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_details.csv'
INTO TABLE bronze_crm_sales_details
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;


-- =========================================================
-- ERP CUSTOMER DETAILS
-- =========================================================

DROP TABLE IF EXISTS bronze_erp_cust_az12;

CREATE TABLE bronze_erp_cust_az12 (
    cid VARCHAR(50),
    bdate VARCHAR(50),
    gender VARCHAR(50)
);

TRUNCATE TABLE bronze_erp_cust_az12;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/CUST_AZ12.csv'
INTO TABLE bronze_erp_cust_az12
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;


-- =========================================================
-- ERP CUSTOMER LOCATION
-- =========================================================

DROP TABLE IF EXISTS bronze_erp_loc_a101;

CREATE TABLE bronze_erp_loc_a101 (
    cid VARCHAR(50),
    cntry VARCHAR(50)
);

TRUNCATE TABLE bronze_erp_loc_a101;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/LOC_A101.csv'
INTO TABLE bronze_erp_loc_a101
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;


-- =========================================================
-- ERP PRODUCT CATEGORY
-- =========================================================

DROP TABLE IF EXISTS bronze_erp_px_cat_g1v2;

CREATE TABLE bronze_erp_px_cat_g1v2 (
    id VARCHAR(50),
    cat VARCHAR(50),
    subcat VARCHAR(50),
    maintenance VARCHAR(50)
);

TRUNCATE TABLE bronze_erp_px_cat_g1v2;

SET SESSION sql_mode = '';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PX_CAT_G1V2.csv'
INTO TABLE bronze_erp_px_cat_g1v2
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW WARNINGS;

/*
=============================================================
END OF BRONZE LAYER LOAD
=============================================================
*/

-- =============================================================================
-- Silver Layer: DDL + Transformation & Load
-- Data Warehouse Project (Bronze -> Silver -> Gold, Medallion Architecture)
--
-- Purpose:
--   Rebuilds the silver layer from scratch. Silver takes the raw, untouched
--   bronze tables and applies cleaning, standardization, and light business
--   logic (deduplication, code-to-label mapping, derived columns) so that
--   downstream gold-layer views can consume trustworthy, consistent data.
--
-- Source tables : bronze_crm_*, bronze_erp_*  (raw, as loaded from CSV)
-- Output tables : silver_crm_*, silver_erp_*  (cleaned, standardized)
-- =============================================================================
