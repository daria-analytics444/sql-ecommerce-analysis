-- ============================================
-- E-commerce Sales Analysis (PostgreSQL)
-- ============================================

-- Question 1: Top-5 products by revenue
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity) AS total_qty,
    ROUND(SUM(oi.quantity * p.price)::numeric, 2) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.product_id
ORDER BY revenue DESC
LIMIT 5;

-- Question 2: Monthly revenue trend
SELECT
    TO_CHAR(o.order_date, 'YYYY-MM') AS month,
    ROUND(SUM(oi.quantity * p.price)::numeric, 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders_count
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'completed'
GROUP BY month
ORDER BY month;

-- Question 3: Revenue share by category
SELECT
    p.category,
    ROUND(SUM(oi.quantity * p.price)::numeric, 2) AS revenue,
    ROUND(100.0 * SUM(oi.quantity * p.price) / (
        SELECT SUM(oi2.quantity * p2.price)
        FROM order_items oi2
        JOIN products p2 ON p2.product_id = oi2.product_id
        JOIN orders o2 ON o2.order_id = oi2.order_id
        WHERE o2.status = 'completed'
    ), 1) AS pct_of_total
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.category
ORDER BY revenue DESC;

-- Question 4: Customers at churn risk
-- (last order was more than 120 days ago)
SELECT
    c.customer_id,
    c.name,
    c.city,
    MAX(o.order_date) AS last_order_date,
    COUNT(o.order_id) AS total_orders,
    (DATE '2025-06-30' - MAX(o.order_date)) AS days_since_last_order
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name, c.city
HAVING (DATE '2025-06-30' - MAX(o.order_date)) > 120
ORDER BY days_since_last_order DESC
LIMIT 10;

-- Question 5: Customer segmentation by order frequency
SELECT
    CASE
        WHEN order_count = 1 THEN '1. One-time buyer'
        WHEN order_count BETWEEN 2 AND 3 THEN '2. Repeat (2-3 orders)'
        WHEN order_count >= 4 THEN '3. Loyal (4+ orders)'
    END AS segment,
    COUNT(*) AS customers_count,
    ROUND(AVG(order_count), 1) AS avg_orders
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    GROUP BY customer_id
) t
GROUP BY segment
ORDER BY segment;

-- Question 6: Cancellation/return rate by category
SELECT
    p.category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(CASE WHEN o.status IN ('cancelled', 'returned') THEN 1 ELSE 0 END) AS problem_orders,
    ROUND(100.0 * SUM(CASE WHEN o.status IN ('cancelled', 'returned') THEN 1 ELSE 0 END) / COUNT(DISTINCT o.order_id), 1) AS problem_rate_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY problem_rate_pct DESC;

-- Question 7: Average order value by city
SELECT
    c.city,
    COUNT(DISTINCT o.order_id) AS orders_count,
    ROUND((SUM(oi.quantity * p.price) / COUNT(DISTINCT o.order_id))::numeric, 2) AS avg_order_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'completed'
GROUP BY c.city
ORDER BY avg_order_value DESC;
