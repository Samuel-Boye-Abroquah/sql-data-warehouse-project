/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

CREATE OR REPLACE VIEW dim_products AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY prd_start_dt, sc.product_key
    ) AS product_key,

    sc.prd_id AS product_id,
    sc.product_key AS product_number,
    sc.prd_nm AS product_name,
    sc.cat_id AS category_id,
    se.cat AS category,
    se.subcat AS subcategory,
    sc.prd_cost AS cost_price,
    sc.prd_line AS product_line,
    se.maintenance,
    sc.prd_start_dt AS start_date

FROM silver_crm_prd_info sc

LEFT JOIN silver_erp_px_cat_g1v2 se
    ON sc.cat_id = se.id

WHERE sc.prd_end_dt IS NULL;



-- ============================================================
-- DIM_CUSTOMERS
-- Customer Dimension
-- Combines CRM customer data with ERP demographic and
-- location information.
-- ============================================================

CREATE OR REPLACE VIEW dim_customers AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY cst_id
    ) AS customer_key,

    cst_id AS customer_id,
    cst_key AS customer_number,
    cst_firstname AS first_name,
    cst_lastname AS last_name,
    cst_marital_status AS marital_status,

    sl.cntry AS country,

    CASE
        WHEN cst_gndr <> 'Unknown'
            THEN cst_gndr
        ELSE COALESCE(se.gender, 'Unknown')
    END AS gender,

    bdate AS birth_date,
    cst_create_date AS date_created

FROM silver_crm_cus_info sc

LEFT JOIN silver_erp_cust_az12 se
    ON sc.cst_key = se.cid

LEFT JOIN silver_erp_loc_a101 sl
    ON sc.cst_key = sl.cid;



-- ============================================================
-- FACT_SALES
-- Sales Fact Table
-- Central fact table linking customer and product dimensions.
-- ============================================================

CREATE OR REPLACE VIEW fact_sales AS
SELECT
    sls_ord_num AS order_number,

    dp.product_key,
    dc.customer_key,

    sls_order_dt AS order_date,
    sls_ship_dt AS ship_date,
    sls_due_dt AS due_date,

    sls_quantity AS quantity,
    sls_price AS price,
    sls_sales AS sales

FROM silver_crm_sales_details sc

LEFT JOIN dim_products dp
    ON sc.sls_prd_key = dp.product_number

LEFT JOIN dim_customers dc
    ON sc.sls_cust_id = dc.customer_id;
