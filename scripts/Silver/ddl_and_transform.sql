USE DataWarehouse;

-- =============================================================================
-- STEP 1: DROP EXISTING SILVER TABLES
-- Ensures this script is fully re-runnable from a clean state.
-- =============================================================================
DROP TABLE IF EXISTS silver_crm_sales_details;
DROP TABLE IF EXISTS silver_crm_prd_info;
DROP TABLE IF EXISTS silver_crm_cus_info;
DROP TABLE IF EXISTS silver_erp_cust_az12;
DROP TABLE IF EXISTS silver_erp_loc_a101;
DROP TABLE IF EXISTS silver_erp_px_cat_g1v2;

-- =============================================================================
-- STEP 2: CREATE SILVER TABLES
-- =============================================================================

CREATE TABLE silver_crm_cus_info (
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date     DATETIME
);

CREATE TABLE silver_crm_prd_info (
    prd_id           INT,
    cat_id           VARCHAR(50),
    product_key      VARCHAR(50),
    prd_nm           VARCHAR(50),
    prd_cost         DECIMAL(10,2),
    prd_line         VARCHAR(50),
    prd_start_dt     DATE,
    prd_end_dt       DATE,
    dwh_create_date  DATETIME
);

CREATE TABLE silver_crm_sales_details (
    sls_ord_num      VARCHAR(20),
    sls_prd_key      VARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE,
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_quantity     INT,
    sls_price        INT,
    sls_sales        INT,
    dwh_create_date  DATETIME
);

CREATE TABLE silver_erp_cust_az12 (
    cid              VARCHAR(50),
    bdate            DATE,
    gender           VARCHAR(20),
    dwh_create_date  DATETIME
);

CREATE TABLE silver_erp_loc_a101 (
    cid              VARCHAR(50),
    cntry            VARCHAR(50),
    dwh_create_date  DATETIME
);

CREATE TABLE silver_erp_px_cat_g1v2 (
    id               VARCHAR(50),
    cat              VARCHAR(50),
    subcat           VARCHAR(50),
    maintenance      VARCHAR(50),
    dwh_create_date  DATETIME
);

-- =============================================================================
-- STEP 3: TRANSFORM & LOAD
-- =============================================================================

-- -----------------------------------------------------------------------------
-- silver_crm_cus_info
-- Cleaning rules applied:
--   - Trim first/last name of stray whitespace
--   - Standardize marital status and gender codes ('S'/'M', 'F'/'M') into
--     full readable labels; anything else (blank, null, unrecognized) -> 'Unknown'
--   - Deduplicate on cst_id, keeping only the most recent record per customer
--     (ROW_NUMBER over cst_create_date DESC, keep dupe_flag = 1)
--   - Drop rows with a null/blank cst_id (no usable customer key)
-- -----------------------------------------------------------------------------
INSERT INTO silver_crm_cus_info
SELECT
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date,
    dwh_create_date
FROM (
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN NULLIF(TRIM(UPPER(cst_marital_status)), '') = 'S' THEN 'Single'
            WHEN NULLIF(TRIM(UPPER(cst_marital_status)), '') = 'M' THEN 'Married'
            ELSE 'Unknown'
        END AS cst_marital_status,
        CASE
            WHEN NULLIF(TRIM(UPPER(cst_gndr)), '') = 'F' THEN 'Female'
            WHEN NULLIF(TRIM(UPPER(cst_gndr)), '') = 'M' THEN 'Male'
            ELSE 'Unknown'
        END AS cst_gndr,
        CAST(cst_create_date AS DATE) AS cst_create_date,
        CURRENT_TIMESTAMP() AS dwh_create_date,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS dupe_flag
    FROM bronze_crm_cus_info
) t1
WHERE TRIM(cst_id) != ''
  AND cst_id IS NOT NULL
  AND dupe_flag = 1;

-- -----------------------------------------------------------------------------
-- silver_crm_prd_info
-- Cleaning rules applied:
--   - Split prd_key into cat_id (first 5 chars, '-' -> '_') and product_key
--     (remainder), matching the category id format used in erp_px_cat_g1v2
--   - Replace missing/blank prd_cost with 0
--   - Map prd_line codes (M/R/S/T) to readable product line names
--   - Derive prd_end_dt as one day before the next version's prd_start_dt
--     for the same product name (SCD-style versioning) — most recent
--     version per product correctly ends up with a NULL end date
--   NOTE: prd_end_dt is derived via LEAD() partitioned on prd_nm (product
--   name). If a product name is ever reused or inconsistently cased across
--   distinct products, this derivation would need a stable key instead —
--   flagged as a known assumption, not yet changed.
-- -----------------------------------------------------------------------------
INSERT INTO silver_crm_prd_info
SELECT
    prd_id,
    REPLACE(LEFT(TRIM(prd_key), 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS product_key,
    prd_nm,
    COALESCE(NULLIF(prd_cost, ''), 0) AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'Unknown'
    END AS prd_line,
    CAST(prd_start_dt AS DATE) AS prd_start_dt,
    DATE_SUB(
        LEAD(prd_start_dt) OVER (PARTITION BY prd_nm ORDER BY prd_start_dt),
        INTERVAL 1 DAY
    ) AS prd_end_dt,
    CURRENT_TIMESTAMP() AS dwh_create_date
FROM bronze_crm_prd_info;

-- -----------------------------------------------------------------------------
-- silver_crm_sales_details
-- Cleaning rules applied:
--   - Convert order/ship/due dates from YYYYMMDD integers to real DATE values;
--     anything not exactly 8 digits (or <= 0) becomes NULL instead of erroring
--   - Rebuild sls_price from sales/quantity when the source price is missing
--     or negative
--   - Rebuild sls_sales as quantity * ABS(price) when the source sales value
--     is missing, non-positive, or inconsistent with quantity * price
--   NOTE: the sls_price and sls_sales fixes both reference the *original*
--   bronze values, not each other's cleaned result, within the same SELECT.
--   In the edge case where source price is NULL and source sales otherwise
--   looks valid, the sales-consistency check can silently pass without
--   correction (NULL comparisons are neither true nor false in SQL). Not
--   yet restructured into a staged subquery — flagged for a future pass.
-- -----------------------------------------------------------------------------
INSERT INTO silver_crm_sales_details
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE
        WHEN sls_order_dt <= 0 OR LENGTH(sls_order_dt) != 8 THEN NULL
        ELSE STR_TO_DATE(sls_order_dt, '%Y%m%d')
    END AS sls_order_dt,
    CASE
        WHEN sls_ship_dt <= 0 OR LENGTH(sls_ship_dt) != 8 THEN NULL
        ELSE STR_TO_DATE(sls_ship_dt, '%Y%m%d')
    END AS sls_ship_dt,
    CASE
        WHEN sls_due_dt <= 0 OR LENGTH(sls_due_dt) != 8 THEN NULL
        ELSE STR_TO_DATE(sls_due_dt, '%Y%m%d')
    END AS sls_due_dt,
    sls_quantity,
    CASE
        WHEN NULLIF(TRIM(sls_price), '') IS NULL OR NULLIF(TRIM(sls_price), '') < 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS sls_price,
    CASE
        WHEN NULLIF(TRIM(sls_sales), '') IS NULL
            OR NULLIF(TRIM(sls_sales), '') <= 0
            OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,
    CURRENT_TIMESTAMP() AS dwh_create_date
FROM bronze_crm_sales_details;

-- -----------------------------------------------------------------------------
-- silver_erp_cust_az12
-- Cleaning rules applied:
--   - Strip a leading 'NAS' prefix from cid where present, to align with the
--     customer id format used elsewhere
--   - Null out any birthdate in the future (clearly invalid source data)
--   - Standardize gender values (M.../F... prefixes, blank, null) into
--     'Male' / 'Female' / 'Unknown'
-- -----------------------------------------------------------------------------
INSERT INTO silver_erp_cust_az12
SELECT
    CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4)
        ELSE cid
    END AS cid,
    CASE
        WHEN bdate > CURDATE() THEN NULL
        ELSE bdate
    END AS bdate,
    CASE
        WHEN gender IS NULL THEN 'Unknown'
        WHEN LENGTH(TRIM(gender)) = 0 THEN 'Unknown'
        WHEN UPPER(TRIM(gender)) LIKE 'M%' THEN 'Male'
        WHEN UPPER(TRIM(gender)) LIKE 'F%' THEN 'Female'
        ELSE 'Unknown'
    END AS gender,
    CURRENT_TIMESTAMP() AS dwh_create_date
FROM bronze_erp_cust_az12;

-- -----------------------------------------------------------------------------
-- silver_erp_loc_a101
-- Cleaning rules applied:
--   - Strip hyphens from cid to align with the customer id format used elsewhere
--   - Strip stray carriage-return/line-feed characters from country values
--     (a common artifact of Windows-exported CSVs)
--   - Standardize country values (US/USA/United States -> USA, DE -> Germany,
--     United Kingdom -> UK); blank/null -> 'Unknown'
-- -----------------------------------------------------------------------------
INSERT INTO silver_erp_loc_a101
SELECT
    REPLACE(cid, '-', '') AS cid,
    CASE
        WHEN cntry IS NULL
             OR LENGTH(TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))) = 0
            THEN 'Unknown'
        WHEN UPPER(TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))) IN ('US', 'USA', 'UNITED STATES')
            THEN 'USA'
        WHEN UPPER(TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))) = 'DE'
            THEN 'Germany'
        WHEN UPPER(TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))) = 'UNITED KINGDOM'
            THEN 'UK'
        ELSE TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''))
    END AS cntry,
    CURRENT_TIMESTAMP() AS dwh_create_date
FROM bronze_erp_loc_a101;

-- -----------------------------------------------------------------------------
-- silver_erp_px_cat_g1v2
-- Straight pass-through — source data already clean; dwh_create_date added
-- for consistency with every other silver table.
-- -----------------------------------------------------------------------------
INSERT INTO silver_erp_px_cat_g1v2
SELECT
    id,
    cat,
    subcat,
    maintenance,
    CURRENT_TIMESTAMP() AS dwh_create_date
FROM bronze_erp_px_cat_g1v2;
