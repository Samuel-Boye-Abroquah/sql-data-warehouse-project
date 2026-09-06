/*
=============================================================
LOAD BRONZE LAYER DATA
=============================================================

Purpose:
    Load raw data from CRM and ERP source files into
    the Bronze layer tables of the Data Warehouse.

Source Files:
    - cust_info.csv
    - prd_info.csv
    - sales_details.csv
    - CUST_AZ12.csv
    - LOC_A101.csv
    - PX_CAT_G1V2.csv

Process:
    1. Truncate existing data from Bronze tables.
    2. Load fresh data from CSV files.
    3. Capture any data quality warnings.
    4. Preserve source data in its raw form.

Target Layer:
    Bronze

Database:
    DataWarehouse

Author:
    Samuel Boye Abroquah

Last Updated:
    2026-09-06

=============================================================
*/

-- =========================================================
-- CRM CUSTOMER INFORMATION
-- =========================================================

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
