-- Query 1: Calculate recognized revenue, completed-order count, and average order value by product category, net of discounts.
WITH category_order_revenue AS (
    SELECT
        p.category,
        o.order_id,
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))) AS order_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    JOIN products AS p ON p.product_id = oi.product_id
    WHERE o.status = 'completed'
    GROUP BY p.category, o.order_id
)
SELECT
    category,
    ROUND(SUM(order_revenue), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(AVG(order_revenue), 2) AS average_order_value
FROM category_order_revenue
GROUP BY category
ORDER BY total_revenue DESC;

-- Query 2: Identify the top 20 customers by lifetime spend, including city and signup date.
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.email,
    c.city,
    c.signup_date,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))), 2) AS lifetime_spend
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY c.customer_id, c.name, c.email, c.city, c.signup_date
ORDER BY lifetime_spend DESC
LIMIT 20;

-- Query 3: Show the month-over-month revenue trend for the latest 24 months using LAG.
WITH monthly_revenue AS (
    SELECT
        DATE(o.order_date, 'start of month') AS revenue_month,
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE(o.order_date, 'start of month')
),
latest_month AS (
    SELECT MAX(revenue_month) AS maximum_month FROM monthly_revenue
),
last_24_months AS (
    SELECT mr.*
    FROM monthly_revenue AS mr
    CROSS JOIN latest_month AS lm
    WHERE mr.revenue_month >= DATE(lm.maximum_month, '-23 months')
)
SELECT
    revenue_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY revenue_month), 2) AS previous_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY revenue_month), 0) * 100,
        2
    ) AS month_over_month_change_percent
FROM last_24_months
ORDER BY revenue_month;

-- Query 4: Calculate each category's return rate as the share of line items with negative quantity.
WITH category_returns AS (
    SELECT
        p.category,
        COUNT(*) AS total_order_items,
        SUM(CASE WHEN oi.quantity < 0 THEN 1 ELSE 0 END) AS returned_order_items
    FROM order_items AS oi
    JOIN products AS p ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT
    category,
    total_order_items,
    returned_order_items,
    ROUND(returned_order_items * 100.0 / NULLIF(total_order_items, 0), 2) AS return_rate_percent
FROM category_returns
ORDER BY return_rate_percent DESC;

-- Query 5: Find customers who placed completed orders in every one of the latest three calendar quarters.
WITH latest_quarter AS (
    SELECT
        CAST(STRFTIME('%Y', MAX(order_date)) AS INTEGER) AS latest_year,
        CAST((CAST(STRFTIME('%m', MAX(order_date)) AS INTEGER) - 1) / 3 + 1 AS INTEGER) AS latest_q
    FROM orders
),
quarter_orders AS (
    SELECT
        o.customer_id,
        CAST(STRFTIME('%Y', o.order_date) AS INTEGER) * 4
            + CAST((CAST(STRFTIME('%m', o.order_date) AS INTEGER) - 1) / 3 AS INTEGER) AS quarter_index
    FROM orders AS o
    WHERE o.status = 'completed'
),
quarter_bounds AS (
    SELECT latest_year * 4 + (latest_q - 1) AS latest_index FROM latest_quarter
)
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.email,
    COUNT(DISTINCT qo.quarter_index) AS quarters_with_orders
FROM quarter_orders AS qo
JOIN quarter_bounds AS qb
JOIN customers AS c ON c.customer_id = qo.customer_id
WHERE qo.quarter_index BETWEEN qb.latest_index - 2 AND qb.latest_index
GROUP BY c.customer_id, c.name, c.email
HAVING COUNT(DISTINCT qo.quarter_index) = 3
ORDER BY c.customer_id;

-- Query 6: Return the 10 highest-rated products that have at least 15 valid reviews.
SELECT
    p.product_id,
    p.name AS product_name,
    p.category,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.rating), 3) AS average_rating
FROM products AS p
JOIN reviews AS r ON r.product_id = p.product_id
WHERE r.rating BETWEEN 1 AND 5
GROUP BY p.product_id, p.name, p.category
HAVING COUNT(r.review_id) >= 15
ORDER BY average_rating DESC, review_count DESC
LIMIT 10;

-- Query 7: Compare engagement by device among customers who made at least one completed purchase.
SELECT
    ws.device,
    COUNT(*) AS session_count,
    ROUND(AVG(ws.duration_minutes), 2) AS average_session_minutes,
    ROUND(AVG(ws.pages_viewed), 2) AS average_pages_viewed
FROM web_sessions AS ws
WHERE EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = ws.customer_id
      AND o.status = 'completed'
)
GROUP BY ws.device
ORDER BY average_session_minutes DESC;

-- Query 8: Rank products by recognized revenue within each category.
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_id,
        p.name AS product_name,
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))) AS revenue
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.product_id
    JOIN orders AS o ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category, p.product_id, p.name
)
SELECT
    category,
    product_id,
    product_name,
    ROUND(revenue, 2) AS revenue,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS revenue_rank
FROM product_revenue
ORDER BY category, revenue_rank, product_id;

-- Query 9: Calculate payment-method share of completed orders within each customer country.
WITH payment_counts AS (
    SELECT
        c.country,
        o.payment_method,
        COUNT(*) AS order_count
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.country, o.payment_method
)
SELECT
    country,
    payment_method,
    order_count,
    ROUND(order_count * 100.0 / SUM(order_count) OVER (PARTITION BY country), 2) AS country_order_share_percent
FROM payment_counts
ORDER BY country, country_order_share_percent DESC;

-- Query 10: Measure category profit and effective margin after discounts, product cost, and negative-quantity returns.
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))), 2) AS net_revenue,
    ROUND(SUM(oi.quantity * p.cost), 2) AS net_cost,
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - COALESCE(oi.discount, 0)) - p.cost)), 2) AS net_profit,
    ROUND(
        SUM(oi.quantity * (oi.unit_price * (1 - COALESCE(oi.discount, 0)) - p.cost))
        / NULLIF(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0))), 0) * 100,
        2
    ) AS effective_margin_percent
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN products AS p ON p.product_id = oi.product_id
WHERE o.status = 'completed'
GROUP BY p.category
ORDER BY net_profit DESC;
