# E-commerce Sales Analysis (SQL)

I built this project to practice answering real business questions with SQL — not just writing queries for the sake of it, but figuring out what a store owner would actually want to know from their sales data.

**Data:** synthetic e-commerce dataset — 200 customers, 15 products, 356 orders, 947 order line items (2024–2025)
**Tools:** SQL (PostgreSQL / SQLite), Python for generating the data

## The setup

I created a dataset that mimics a small online store selling clothing, electronics, beauty products, and home goods. It follows a standard relational structure: `customers` → `orders` → `order_items` ← `products` — customers place orders, orders contain line items, line items point to products. That structure is what lets me use JOINs, aggregation, subqueries, and date-based logic throughout.

---

## 1. Which products actually make money?

```sql
SELECT p.product_name, p.category, SUM(oi.quantity) AS total_qty,
       ROUND(SUM(oi.quantity * p.price)::numeric, 2) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.product_id
ORDER BY revenue DESC
LIMIT 5;
```

**Result:** Jacket ($7,142.65), Smart Watch ($6,643.20), Sneakers ($6,611.57), Perfume ($5,306.91), Speaker ($5,203.44).

Jacket, Smart Watch, and Sneakers came out on top. Interesting part: these aren't necessarily the best-selling items by volume, they're just priced high enough that fewer sales still add up to more revenue. Worth knowing if you're deciding what to feature in ads versus what just moves a lot of units.

---

## 2. Is revenue growing or flat?

```sql
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
```

**Result:** Growing steadily — from about $412 in January 2024 to over $6,000 by May 2025. There's also a clear spike in November (makes sense, Black Friday season) followed by a dip in December.

If I were running this store, I'd probably shift some of the December marketing budget earlier, or run a specific December push instead of relying on November momentum to carry through.

---

## 3. Which category actually pulls its weight?

```sql
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
```

**Result:** Clothing — 33.2%, Electronics — 32.1%, Beauty — 22.4%, Home — 12.3%.

Clothing and Electronics each bring in about a third of total revenue. Home goods only make up 12%, despite having a similar number of products listed. Something's off there — either the products aren't appealing, or they're just not being marketed properly.

---

## 4. Who's about to churn?

```sql
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
```

**Result:** 10 customers haven't ordered in 416–473 days, including some who used to be pretty active.

The one that stood out: a customer with 8 past orders who's gone silent for 425 days. That's exactly the kind of person worth sending a "we miss you" email with a discount, rather than treating every quiet customer the same way.

---

## 5. How loyal is the customer base, really?

```sql
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
```

**Result:** 53 one-time buyers, 61 repeat customers (2-3 orders), 30 loyal customers (4+ orders, averaging 5.4).

Only about a fifth of the customer base is "loyal" — which tracks with the usual pattern where a small chunk of customers ends up driving most of the repeat revenue. Next logical step would be to check how much of total revenue that 21% actually accounts for.

---

## 6. Where are the returns coming from?

```sql
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
```

**Result:** Home — 25.6% problem rate (highest), Beauty — 18.1% (lowest).

Combined with question 3, Home goods looks like the category that needs the most attention — low revenue AND high returns at the same time. Worth checking product descriptions or quality specifically there.

---

## 7. Does location affect spending?

```sql
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
```

**Result:** Kyiv leads with $221.03 average order value, Lviv is lowest at $167.29.

That's a 32% gap between cities — big enough to be worth testing something regional, like a delivery promo or a targeted offer aimed at increasing average order value in the lower-performing cities.


