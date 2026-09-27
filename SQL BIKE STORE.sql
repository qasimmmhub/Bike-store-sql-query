-- =============================================================================
-- Task 1 — Build the Sales Detail Dataset (6 marks)
-- =============================================================================
/*
  Description: Returns detailed order item records for completed orders (order_status = 4).
  Includes customer name, store, staff, product details, quantities, and net line revenue.
*/

SELECT 
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    st.store_name,
    CONCAT(sf.first_name, ' ', sf.last_name) AS staff_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    (oi.quantity * oi.list_price * (1 - oi.discount)) AS net_line_revenue
FROM sales.orders o
INNER JOIN sales.customers c 
    ON o.customer_id = c.customer_id
INNER JOIN sales.stores st 
    ON o.store_id = st.store_id
INNER JOIN sales.staffs sf 
    ON o.staff_id = sf.staff_id
INNER JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
INNER JOIN production.products p 
    ON oi.product_id = p.product_id
INNER JOIN production.categories cat 
    ON p.category_id = cat.category_id
INNER JOIN production.brands b 
    ON p.brand_id = b.brand_id
WHERE o.order_status = 4
ORDER BY o.order_date DESC, o.order_id DESC;
GO

/*******************************************************************************
  MORPHERALABS — Scenario-Based SQL Assignment (BikeStores)
  Tasks 2 through 10
  Syntax: Microsoft SQL Server (T-SQL)
*******************************************************************************/

USE BikeStores;
GO

-- =============================================================================
-- Task 2 — Store Performance Summary (5 marks)
-- =============================================================================
/*
  Description: Store-level report showing total completed orders, units sold,
  total net revenue, and average order value ordered by net revenue descending.
*/

SELECT 
    st.store_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM sales.stores st
INNER JOIN sales.orders o 
    ON st.store_id = o.store_id
INNER JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY st.store_id, st.store_name
ORDER BY total_net_revenue DESC;
GO


-- =============================================================================
-- Task 3 — High-Value Customers (5 marks)
-- =============================================================================
/*
  Description: Identifies customers whose total completed order spending exceeds
  the average spending of all customers with completed orders.
*/

WITH CustomerSpending AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
    FROM sales.customers c
    INNER JOIN sales.orders o 
        ON c.customer_id = o.customer_id
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
    customer_id,
    customer_name,
    completed_order_count,
    total_spending
FROM CustomerSpending
WHERE total_spending > (SELECT AVG(total_spending) FROM CustomerSpending)
ORDER BY total_spending DESC;
GO


-- =============================================================================
-- Task 4 — Inventory Risk Report (5 marks)
-- =============================================================================
/*
  Description: Identifies inventory risk where product stock is below 5 units in a store.
  Sorted with zero stock items first, then lowest remaining quantities.
*/

SELECT 
    p.product_name,
    st.store_name,
    s.quantity AS current_quantity,
    cat.category_name,
    b.brand_name
FROM production.stocks s
INNER JOIN production.products p 
    ON s.product_id = p.product_id
INNER JOIN sales.stores st 
    ON s.store_id = st.store_id
INNER JOIN production.categories cat 
    ON p.category_id = cat.category_id
INNER JOIN production.brands b 
    ON p.brand_id = b.brand_id
WHERE s.quantity < 5
ORDER BY s.quantity ASC, p.product_name ASC;
GO


-- =============================================================================
-- Task 5 — Top Products Within Each Category (6 marks)
-- =============================================================================
/*
  Description: Ranks top 3 products per category based on completed order net revenue.
  Uses DENSE_RANK() so tied products receive the same rank without gaps.
*/

WITH RankedProducts AS (
    SELECT 
        cat.category_name,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
        DENSE_RANK() OVER (
            PARTITION BY cat.category_id 
            ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC
        ) AS category_position
    FROM production.categories cat
    INNER JOIN production.products p 
        ON cat.category_id = p.category_id
    INNER JOIN sales.order_items oi 
        ON p.product_id = oi.product_id
    INNER JOIN sales.orders o 
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT 
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    category_position
FROM RankedProducts
WHERE category_position <= 3
ORDER BY category_name ASC, category_position ASC, total_net_revenue DESC;
GO


-- =============================================================================
-- Task 6 — Monthly Sales Trend (6 marks)
-- =============================================================================
/*
  Description: Calculates monthly net revenue and month-over-month revenue changes
  using LAG() analytic function. Sorted chronologically.
*/

WITH MonthlySales AS (
    SELECT 
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT 
    sales_year AS [year],
    sales_month AS [month],
    total_net_revenue,
    LAG(total_net_revenue, 1) OVER (
        ORDER BY sales_year, sales_month
    ) AS previous_month_revenue,
    total_net_revenue - LAG(total_net_revenue, 1) OVER (
        ORDER BY sales_year, sales_month
    ) AS revenue_change
FROM MonthlySales
ORDER BY [year] ASC, [month] ASC;
GO


-- =============================================================================
-- Task 7 — Reusable Reporting View (4 marks)
-- =============================================================================
/*
  Description: Creates a reusable view aggregating customer sales metrics.
  Uses LEFT JOINs and ISNULL to include customers without orders cleanly.
*/

CREATE OR ALTER VIEW sales.vw_customer_sales_summary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_completed_orders,
    ISNULL(SUM(oi.quantity), 0) AS total_units_purchased,
    ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS total_net_revenue,
    MAX(o.order_date) AS most_recent_completed_order_date
FROM sales.customers c
LEFT JOIN sales.orders o 
    ON c.customer_id = o.customer_id AND o.order_status = 4
LEFT JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;
GO


-- =============================================================================
-- Task 8 — Safe Data Modification (4 marks)
-- =============================================================================
/*
  Description: Explicit transaction safely updating customer phone number,
  followed by a validation query and a ROLLBACK to preserve assessment state.
*/

BEGIN TRANSACTION;

-- 1. Perform Update
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

-- 2. Validation Query
SELECT 
    customer_id, 
    first_name, 
    last_name, 
    phone 
FROM sales.customers 
WHERE customer_id = 1;

-- 3. Rollback during testing to preserve raw dataset
ROLLBACK TRANSACTION;
GO


-- =============================================================================
-- Task 9 — Store Sales Procedure (6 marks)
-- =============================================================================
/*
  Description: Stored procedure returning completed sales per product for a store
  within a given date range. Features validation against invalid date ranges.
*/

CREATE OR ALTER PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Error handling for invalid date range
    IF @start_date > @end_date
    BEGIN
        RAISERROR('Invalid Date Range: @start_date cannot be later than @end_date.', 16, 1);
        RETURN;
    END

    -- Main Report Query
    SELECT 
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN production.products p 
        ON oi.product_id = p.product_id
    WHERE o.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date BETWEEN @start_date AND @end_date
    GROUP BY p.product_id, p.product_name
    ORDER BY total_net_revenue DESC;
END;
GO


-- =============================================================================
-- Task 10 — Management Insight Query (3 marks)
-- =============================================================================

SELECT 
    s.store_name,
    CONCAT(st.first_name, ' ', st.last_name) AS staff_name,
    COUNT(DISTINCT o.order_id) AS total_orders_handled,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue_generated
FROM sales.staffs st
INNER JOIN sales.stores s 
    ON st.store_id = s.store_id
INNER JOIN sales.orders o 
    ON st.staff_id = o.staff_id
INNER JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY s.store_name, st.staff_id, st.first_name, st.last_name
ORDER BY total_revenue_generated DESC;

/*
  1. Business Question: Who are the top-performing sales staff members across all store locations based on revenue generation?
  2. What it Measures: The total number of completed orders handled and total net revenue generated per sales staff employee.
  3. Why Management Cares: Identifies high-performing staff for commission/bonuses and highlights personnel needing sales training or support.
*/