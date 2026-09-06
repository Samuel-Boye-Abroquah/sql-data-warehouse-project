-- =============================================================================
-- Silver Layer: Data Quality Validation Checks
-- Data Warehouse Project (Bronze -> Silver -> Gold, Medallion Architecture)
--
-- Purpose:
--   Exploratory checks run against BRONZE tables to identify the specific
--   data quality issues that the silver_layer_ddl_and_transform.sql script
--   is designed to fix (duplicates, stray whitespace, inconsistent codes,
--   invalid dates, price/quantity/sales mismatches).
--
--   These are diagnostic SELECTs, not automated tests — each check documents
--   what "clean" looks like ("Expectation: no results") so it's obvious at a
--   glance whether a check passed.
-- =============================================================================

-- =============================================================================
-- bronze_crm_cus_info
-- =============================================================================

-- Check for NULL or duplicate primary key
-- Expectation: no results
SELECT cst_id, COUNT(*)
FROM bronze_crm_cus_info
GROUP BY cst_id
HAVING COUNT(*) > 1 AND cst_id IS NOT NULL;

-- Preview: which record per customer will survive deduplication
-- (most recent by cst_create_date, dupe_flag = 1 is the one silver keeps)
SELECT cst_id
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS dupe_flag
    FROM bronze_crm_cus_info
    WHERE TRIM(cst_id) != '' AND cst_id IS NOT NULL
) t1
WHERE dupe_flag = 1;

-- Check for unwanted leading/trailing spaces in names
-- Expectation: no results
SELECT cst_firstname
FROM bronze_crm_cus_info
WHERE TRIM(cst_firstname) != cst_firstname;

SELECT cst_lastname
FROM bronze_crm_cus_info
WHERE TRIM(cst_lastname) != cst_lastname;

-- Preview trimmed values
SELECT TRIM(cst_firstname) AS cst_firstname FROM bronze_crm_cus_info;
SELECT TRIM(cst_lastname) AS cst_lastname FROM bronze_crm_cus_info;

-- Data standardization and consistency: raw distinct values before mapping
SELECT DISTINCT NULLIF(TRIM(cst_gndr), '') FROM bronze_crm_cus_info;
SELECT DISTINCT NULLIF(TRIM(cst_marital_status), '') FROM bronze_crm_cus_info;

-- Preview the standardized mapping applied in silver
SELECT
    CASE
        WHEN NULLIF(TRIM(UPPER(cst_gndr)), '') = 'F' THEN 'Female'
        WHEN NULLIF(TRIM(UPPER(cst_gndr)), '') = 'M' THEN 'Male'
        ELSE 'Unknown'
    END AS cst_gndr
FROM bronze_crm_cus_info;

SELECT
    CASE
        WHEN NULLIF(TRIM(UPPER(cst_marital_status)), '') = 'S' THEN 'Single'
        WHEN NULLIF(TRIM(UPPER(cst_marital_status)), '') = 'M' THEN 'Married'
        ELSE 'Unknown'
    END AS cst_marital_status
FROM bronze_crm_cus_info;

-- Preview date cast
SELECT CAST(cst_create_date AS DATE) AS cst_create_date FROM bronze_crm_cus_info;


-- =============================================================================
-- bronze_crm_prd_info
-- =============================================================================

-- Check for NULL or duplicate primary key
-- Expectation: no results
SELECT prd_id, COUNT(*)
FROM bronze_crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted spaces in product name
-- Expectation: no results
SELECT prd_nm
FROM bronze_crm_prd_info
WHERE TRIM(prd_nm) != prd_nm;

-- Check for null or negative cost
-- Expectation: no results
SELECT NULLIF(prd_cost, '')
FROM bronze_crm_prd_info
WHERE prd_cost = '' OR prd_cost IS NULL OR prd_cost < 0;

-- Preview the cleaned cost (missing/blank -> 0)
SELECT COALESCE(NULLIF(prd_cost, ''), 0) AS prd_cost FROM bronze_crm_prd_info;

-- Data standardization and consistency: raw product line codes before mapping
SELECT DISTINCT prd_line FROM bronze_crm_prd_info;

-- Check for invalid date ranges (start date after end date)
-- Expectation: no results
SELECT *
FROM bronze_crm_prd_info
WHERE prd_start_dt > prd_end_dt;


-- =============================================================================
-- bronze_crm_sales_details
-- =============================================================================

-- Check for duplicates on the natural key (order number + product key)
-- Expectation: no results
SELECT sls_ord_num, sls_prd_key, COUNT(*)
FROM bronze_crm_sales_details
GROUP BY sls_ord_num, sls_prd_key
HAVING COUNT(*) > 1;

-- Check for invalid order/ship/due dates (not a real 8-digit YYYYMMDD value)
SELECT sls_order_dt, NULLIF(sls_order_dt, 0)
FROM bronze_crm_sales_details
WHERE sls_order_dt <= 0 OR LENGTH(sls_order_dt) != 8;

SELECT sls_ship_dt, NULLIF(sls_ship_dt, 0)
FROM bronze_crm_sales_details
WHERE sls_ship_dt <= 0 OR LENGTH(sls_ship_dt) != 8;

SELECT sls_due_dt, NULLIF(sls_due_dt, 0)
FROM bronze_crm_sales_details
WHERE sls_due_dt <= 0 OR LENGTH(sls_due_dt) != 8;

-- Spot-check sales values on rows with an invalid due date
SELECT sls_sales
FROM bronze_crm_sales_details
WHERE sls_due_dt IS NULL OR sls_due_dt <= 0;

-- Check for illogical date order (order date after ship/due date)
SELECT *
FROM bronze_crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Check consistency between sales, quantity, and price
-- Rule: sales = quantity * price; none of the three may be null, zero, or negative
SELECT DISTINCT sls_quantity, sls_price, sls_sales AS old_sls
FROM bronze_crm_sales_details
WHERE sls_quantity * sls_price != sls_sales
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price < 0;


-- =============================================================================
-- bronze_erp_cust_az12
-- =============================================================================

-- Data standardization and consistency: raw distinct gender values before mapping
SELECT DISTINCT gender FROM bronze_erp_cust_az12;

-- Identify out-of-range birthdates (in the future)
SELECT bdate
FROM bronze_erp_cust_az12
WHERE bdate > CURDATE();

-- Preview the standardized gender mapping applied in silver
SELECT DISTINCT
    CASE
        WHEN gender IS NULL THEN 'Unknown'
        WHEN LENGTH(TRIM(gender)) = 0 THEN 'Unknown'
        WHEN UPPER(TRIM(gender)) LIKE 'M%' THEN 'Male'
        WHEN UPPER(TRIM(gender)) LIKE 'F%' THEN 'Female'
        ELSE 'Unknown'
    END AS gender
FROM bronze_erp_cust_az12;


-- =============================================================================
-- bronze_erp_loc_a101
-- =============================================================================

-- Data standardization and consistency: raw distinct country values before mapping
SELECT DISTINCT cntry FROM bronze_erp_loc_a101;


-- =============================================================================
-- bronze_erp_px_cat_g1v2
-- =============================================================================

-- Check for duplicate primary key
-- Expectation: no results
SELECT id, COUNT(*)
FROM bronze_erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;

-- Data standardization and consistency: raw distinct values (category/subcategory/maintenance)
SELECT DISTINCT cat FROM bronze_erp_px_cat_g1v2;
SELECT DISTINCT subcat FROM bronze_erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM bronze_erp_px_cat_g1v2;

-- Check for unwanted leading/trailing spaces
-- Expectation: no results
SELECT DISTINCT cat FROM bronze_erp_px_cat_g1v2 WHERE cat != TRIM(cat);
SELECT DISTINCT subcat FROM bronze_erp_px_cat_g1v2 WHERE subcat != TRIM(subcat);
SELECT DISTINCT maintenance FROM bronze_erp_px_cat_g1v2 WHERE maintenance != TRIM(maintenance);
