-- PROJECT: Pizza Sales Data Analysis using SQL
-- OBJECTIVE: To derive business insights such as sales trends, top-performing pizzas, and revenue growth.
-- TOOLS: PostgreSQL
-- TABLES: pizza_types, pizzas, orders, order_details
-- AUTHOR: Diya (Data Analyst Aspirant)
-- -----------------------------------------------------------

--CREATE TABLE FOR PIZZA_TYPE
CREATE TABLE pizza_types (
    pizza_type_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    ingredients TEXT
);

--CREATE TABLE FOR PIZZAS
CREATE TABLE pizzas(
	pizza_id VARCHAR(100),
	pizza_type_id VARCHAR(100),
	size VARCHAR(10),
	price NUMERIC(5,2)
);

--CREATE TABLE FOR ORDERS
CREATE TABLE orders(
	order_id INT ,
	"Date" DATE,
	"Time" TIME
);

--CREATE TABLE FOR ORDER_DETAILS 
CREATE TABLE Order_details(
	order_details_id INT,
	order_id INT,
	pizza_id VARCHAR,
	quantity INT	
);

-- DATA HAS BEEN INSERTED DIRECTLY CHECK IT OUT 
SELECT * FROM pizza_types;
SELECT * FROM pizzas;
SELECT * FROM orders;
SELECT * FROM order_details;

--Retrieve the total number of orders placed 
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM order_details;

--Calculate the total revenue generated from pizza sales.
SELECT SUM(od.quantity * p.price)
AS total_revenue
FROM order_details od
JOIN pizzas p
ON od.pizza_id = p.pizza_id;

--Identify the highest-priced pizza.
SELECT * FROM pizzas ORDER BY price DESC 
LIMIT 1;

--Identify the most common pizza size ordered.
SELECT size, count(size) AS common_pizza_size_ordered
FROM pizzas GROUP BY size 
ORDER BY common_pizza_size_ordered  DESC
LIMIT 1;

--List the top 5 most ordered pizza types along with their quantities.
SELECT 
    pt.name AS pizza_type,
    SUM(od.quantity) AS total_quantity
FROM order_details AS od
JOIN pizzas AS p
    ON od.pizza_id = p.pizza_id
JOIN pizza_types AS pt
    ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_quantity DESC
LIMIT 5;

--Join the necessary tables to find the total quantity of each pizza category ordered
SELECT 
    pt.category,
    SUM(od.quantity) AS total_quantity
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
JOIN pizza_types pt 
    ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.category
ORDER BY total_quantity DESC;

--Determine the distribution of orders by hours of the day 
SELECT 
    EXTRACT(HOUR FROM "Time") AS hour_of_day,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY hour_of_day
ORDER BY hour_of_day DESC;

--Join relevant tables to find the category wise distribution of pizzas 
SELECT 
    pt.category,
    COUNT(p.pizza_id) AS total_pizzas
FROM pizza_types pt
JOIN pizzas p
    ON pt.pizza_type_id = p.pizza_type_id
GROUP BY pt.category
ORDER BY total_pizzas DESC;

--Group the orders by date and calculate the average number of pizzas order per day 
SELECT 
    ROUND(AVG(daily_total), 2) AS avg_pizzas_per_day
FROM (
    SELECT 
        o."Date",
        SUM(od.quantity) AS daily_total
    FROM orders o
    JOIN order_details od
        ON o.order_id = od.order_id
    GROUP BY o."Date"
) AS daily_summary;

--Determine the top 3 most ordered pizza types based on revenue 
SELECT 
    pt.name AS pizza_name,
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
JOIN pizza_types pt 
    ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_revenue DESC
LIMIT 3;

--Calculate the percentage contribution of each pizza type to total revenue . 
SELECT 
    pt.name AS pizza_name,
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue,
    ROUND(
        (SUM(od.quantity * p.price) / 
         (SELECT SUM(od2.quantity * p2.price)
          FROM order_details od2
          JOIN pizzas p2 ON od2.pizza_id = p2.pizza_id)
        ) * 100, 2
    ) AS percentage_contribution
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
JOIN pizza_types pt 
    ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_revenue DESC;

--Analyze the cumulative revenue generated over time 
SELECT 
    o."Date",
    ROUND(SUM(od.quantity * p.price), 2) AS daily_revenue,
    ROUND(SUM(SUM(od.quantity * p.price)) OVER (ORDER BY o."Date"), 2) AS cumulative_revenue
FROM orders o
JOIN order_details od 
    ON o.order_id = od.order_id
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
GROUP BY o."Date"
ORDER BY o."Date";

--Determine the top 3 most ordered pizza types based on revenue for each pizza category 
SELECT 
    category,
    name AS pizza_name,
    ROUND(total_revenue, 2) AS total_revenue
FROM (
    SELECT 
        pt.category,
        pt.name,
        SUM(od.quantity * p.price) AS total_revenue,
        RANK() OVER (
            PARTITION BY pt.category
            ORDER BY SUM(od.quantity * p.price) DESC
        ) AS revenue_rank
    FROM order_details od
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt 
        ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY pt.category, pt.name
) AS ranked_pizzas
WHERE revenue_rank <= 3
ORDER BY category, total_revenue DESC;

-- Identify the least ordered pizza and analyze possible reason
WITH pizza_sales AS (
    SELECT 
        pt.name AS pizza_name,
        pt.category,
        p.price,
        SUM(od.quantity) AS total_quantity
    FROM order_details od
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt 
        ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY pt.name, pt.category, p.price
),
least_ordered AS (
    SELECT 
        pizza_name,
        category,
        price,
        total_quantity
    FROM pizza_sales
    ORDER BY total_quantity ASC
    LIMIT 1
),
avg_price AS (
    SELECT 
        AVG(price) AS avg_pizza_price
    FROM pizzas
)
SELECT 
    l.pizza_name,
    l.category,
    l.price,
    l.total_quantity,
    a.avg_pizza_price,
    CASE 
        WHEN l.price > a.avg_pizza_price THEN 'Less ordered due to higher price'
        WHEN l.category IN ('Supreme', 'Gourmet') THEN 'Premium category — niche demand'
        ELSE 'Low popularity or unfamiliar ingredients'
    END AS probable_reason
FROM least_ordered l
CROSS JOIN avg_price a;

--Find the day of the week with the highest sales 
SELECT 
    TO_CHAR(o."Date", 'Day') AS day_of_week,
    ROUND(SUM(od.quantity * p.price), 2) AS total_sales
FROM orders o
JOIN order_details od 
    ON o.order_id = od.order_id
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
GROUP BY TO_CHAR(o."Date", 'Day')
ORDER BY total_sales DESC
LIMIT 1;
 
-- Calculate the Average Ordered Value (AOV)
WITH order_totals AS (
    SELECT 
        o.order_id,
        SUM(od.quantity * p.price) AS order_total
    FROM orders o
    JOIN order_details od 
        ON o.order_id = od.order_id
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
)
SELECT 
    ROUND(AVG(order_total), 2) AS average_order_value
FROM order_totals;

-- Determine revenue contribution by pizza size
WITH size_revenue AS (
    SELECT 
        p.size,
        ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
    FROM order_details od
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    GROUP BY p.size
),
total AS (
    SELECT SUM(total_revenue) AS overall_revenue FROM size_revenue
)
SELECT 
    s.size,
    s.total_revenue,
    ROUND((s.total_revenue / t.overall_revenue) * 100, 2) AS revenue_percentage
FROM size_revenue s
CROSS JOIN total t
ORDER BY revenue_percentage DESC;

-- Detect Month-over-Month Sales Growth
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', o."Date") AS month,
        ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
    FROM orders o
    JOIN order_details od 
        ON o.order_id = od.order_id
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    GROUP BY DATE_TRUNC('month', o."Date")
),
growth_calc AS (
    SELECT 
        month,
        total_revenue,
        LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
        ROUND(
            ((total_revenue - LAG(total_revenue) OVER (ORDER BY month)) 
            / LAG(total_revenue) OVER (ORDER BY month)) * 100, 2
        ) AS month_over_month_growth
    FROM monthly_sales
)
SELECT 
    TO_CHAR(month, 'Mon YYYY') AS month_name,
    total_revenue,
    prev_month_revenue,
    month_over_month_growth
FROM growth_calc
ORDER BY month;

-- Find the order IDs with the highest basket value
WITH order_totals AS (
    SELECT 
        o.order_id,
        ROUND(SUM(od.quantity * p.price), 2) AS basket_value
    FROM orders o
    JOIN order_details od 
        ON o.order_id = od.order_id
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
)
SELECT 
    order_id,
    basket_value
FROM order_totals
ORDER BY basket_value DESC
LIMIT 5;   -- shows top 5 highest-value orders

-- Find the busiest order day of the week and total orders
SELECT 
    TO_CHAR("Date", 'Day') AS day_of_week,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY day_of_week
ORDER BY total_orders DESC;

-- Find total pizzas sold per month (volume trend)
SELECT 
    DATE_TRUNC('month', o."Date") AS month,
    SUM(od.quantity) AS total_pizzas_sold
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
GROUP BY DATE_TRUNC('month', o."Date")
ORDER BY month;


-- QUICK SUMMARY REPORT
SELECT 
    COUNT(DISTINCT od.order_id) AS total_orders,
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue,
    ROUND(AVG(order_value), 2) AS average_order_value
FROM order_details od
JOIN pizzas p 
    ON od.pizza_id = p.pizza_id
JOIN (
    SELECT 
        o.order_id,
        SUM(od.quantity * p.price) AS order_value
    FROM orders o
    JOIN order_details od 
        ON o.order_id = od.order_id
    JOIN pizzas p 
        ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
) AS order_summary 
    ON od.order_id = order_summary.order_id;


-- -----------------------------------------------------------
-- INSIGHTS SUMMARY
-- 1. Total Revenue: Use query output to note overall sales performance.
-- 2. Top Pizza: Identify most popular pizza type by quantity and revenue.
-- 3. Peak Hour: Determine busiest hour from hourly order distribution.
-- 4. Month with Highest Sales: Check month-over-month growth table.
-- 5. Business Suggestion: Focus marketing around peak sales times & top categories.

-- END OF PROJECT

