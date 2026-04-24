use ecommerce_db

select* from dbo.olist_customers_dataset
select*from dbo.olist_geolocation_dataset
select*from [dbo].[olist_order_payments_dataset]
select*from [dbo].[olist_order_reviews_dataset] ---translation needed

select*from[dbo].[olist_orders_dataset]

--Aggregate payments per order:
CREATE VIEW payments_clean AS
SELECT 
    order_id,
    SUM(payment_value) AS total_payment
FROM dbo.olist_order_payments_dataset
GROUP BY order_id;

--Aggregate item price per order:

CREATE VIEW items_clean AS
SELECT 
    order_id,
    SUM(price) AS total_price,
    SUM(freight_value) AS total_freight
FROM dbo.olist_order_items_dataset
GROUP BY order_id;


--CREATE MASTER TABLE
SELECT 
    o.order_id,
    c.customer_unique_id,
    CAST(o.order_purchase_timestamp AS DATE) AS order_date,
    i.total_price,
    i.total_freight,
    p.total_payment,
    o.order_status
INTO ecommerce_master
FROM dbo.olist_orders_dataset o
JOIN dbo.olist_customers_dataset c 
    ON o.customer_id = c.customer_id
JOIN items_clean i 
    ON o.order_id = i.order_id
JOIN payments_clean p 
    ON o.order_id = p.order_id;

    select*from ecommerce_master;


    SELECT COUNT(*) FROM ecommerce_master;
    SELECT COUNT(DISTINCT order_id) FROM ecommerce_master;

---BUSINESS QUESTIONS:

---1. Monthly revenue trend

    SELECT 
    DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month,
    SUM(total_payment) AS revenue
FROM ecommerce_master
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY month;

---2. orders trend
SELECT 
    DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month,
    COUNT(order_id) AS total_orders
FROM ecommerce_master
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY month;

--Average Order Value

SELECT 
    DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month,
    SUM(total_payment) * 1.0 / COUNT(order_id) AS avg_order_value
FROM ecommerce_master
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY month;

--Customer Retention analysis
--1. first purchase per customer

WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
)
SELECT * FROM first_purchase;


--2. classify orders new vs repeat
WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
)

SELECT 
    e.order_date,
    
    COUNT(DISTINCT CASE 
        WHEN e.order_date = f.first_order_date 
        THEN e.customer_unique_id END) AS new_customers,
        
    COUNT(DISTINCT CASE 
        WHEN e.order_date > f.first_order_date 
        THEN e.customer_unique_id END) AS repeat_customers
        
FROM ecommerce_master e

JOIN first_purchase f 
    ON e.customer_unique_id = f.customer_unique_id

GROUP BY e.order_date
ORDER BY e.order_date;


---3. Monthly retention view
WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
)

SELECT 
    DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1) AS month,
    
    COUNT(DISTINCT CASE 
        WHEN e.order_date = f.first_order_date 
        THEN e.customer_unique_id END) AS new_customers,
        
    COUNT(DISTINCT CASE 
        WHEN e.order_date > f.first_order_date 
        THEN e.customer_unique_id END) AS repeat_customers
        
FROM ecommerce_master e

JOIN first_purchase f 
    ON e.customer_unique_id = f.customer_unique_id

GROUP BY DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1)
ORDER BY month;

---retention rate:
WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
),

monthly_data AS (
    SELECT 
        DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1) AS month,
        
        COUNT(DISTINCT CASE 
            WHEN e.order_date = f.first_order_date 
            THEN e.customer_unique_id END) AS new_customers,
            
        COUNT(DISTINCT CASE 
            WHEN e.order_date > f.first_order_date 
            THEN e.customer_unique_id END) AS repeat_customers
            
    FROM ecommerce_master e
    JOIN first_purchase f 
        ON e.customer_unique_id = f.customer_unique_id
    GROUP BY DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1)
)

SELECT 
    month,
    new_customers,
    repeat_customers,
    (repeat_customers * 1.0) / 
    (new_customers + repeat_customers) AS retention_rate
FROM monthly_data
ORDER BY month;



---COHORT ANALYSIS(cohort means group of customers who made their first purchase in the same month)


--1.assign cohort month
WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
)

SELECT 
    customer_unique_id,
    DATEFROMPARTS(YEAR(first_order_date), MONTH(first_order_date), 1) AS cohort_month
FROM first_purchase;



---2.Attach Cohort to Every Order

WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT 
        e.customer_unique_id,
        DATEFROMPARTS(YEAR(f.first_order_date), MONTH(f.first_order_date), 1) AS cohort_month,
        DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1) AS order_month
    FROM ecommerce_master e
    JOIN first_purchase f 
        ON e.customer_unique_id = f.customer_unique_id
)

SELECT * FROM cohort_data;

---3.calculate month difference

WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT 
        e.customer_unique_id,
        DATEFROMPARTS(YEAR(f.first_order_date), MONTH(f.first_order_date), 1) AS cohort_month,
        DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1) AS order_month
    FROM ecommerce_master e
    JOIN first_purchase f 
        ON e.customer_unique_id = f.customer_unique_id
),

cohort_index AS (
    SELECT 
        customer_unique_id,
        cohort_month,
        order_month,
        DATEDIFF(MONTH, cohort_month, order_month) AS month_number
    FROM cohort_data
)

SELECT * FROM cohort_index;

---4.build cohort Table

WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_date) AS first_order_date
    FROM ecommerce_master
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT 
        e.customer_unique_id,
        DATEFROMPARTS(YEAR(f.first_order_date), MONTH(f.first_order_date), 1) AS cohort_month,
        DATEFROMPARTS(YEAR(e.order_date), MONTH(e.order_date), 1) AS order_month
    FROM ecommerce_master e
    JOIN first_purchase f 
        ON e.customer_unique_id = f.customer_unique_id
),

cohort_index AS (
    SELECT 
        customer_unique_id,
        cohort_month,
        DATEDIFF(MONTH, cohort_month, order_month) AS month_number
    FROM cohort_data
)

SELECT 
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM cohort_index
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

--cohort analysis
SELECT TOP 10 order_date FROM ecommerce_master;

ALTER TABLE ecommerce_master
ADD order_month DATE;

UPDATE ecommerce_master
SET order_month = DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1);

--rebuilt cohort version

;WITH numbers AS (
    SELECT 0 AS month_number
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 11
    UNION ALL SELECT 12
)
SELECT * 
FROM numbers;

WITH numbers AS (
    SELECT 0 AS month_number UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
    SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
    SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL
    SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
),

first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM ecommerce_master
    GROUP BY customer_unique_id
),

customer_monthly AS (
    SELECT DISTINCT
        customer_unique_id,
        order_month
    FROM ecommerce_master
),

cohort_data AS (
    SELECT 
        c.customer_unique_id,
        f.cohort_month,
        DATEDIFF(MONTH, f.cohort_month, c.order_month) AS month_number
    FROM customer_monthly c
    JOIN first_purchase f
        ON c.customer_unique_id = f.customer_unique_id
),

cohort_counts AS (
    SELECT 
        cohort_month,
        month_number,
        COUNT(customer_unique_id) AS customers
    FROM cohort_data
    GROUP BY cohort_month, month_number
),

cohort_size AS (
    SELECT 
        cohort_month,
        customers AS cohort_size
    FROM cohort_counts
    WHERE month_number = 0
),

all_combinations AS (
    SELECT 
        cs.cohort_month,
        n.month_number
    FROM cohort_size cs
    CROSS JOIN numbers n
)

SELECT 
    a.cohort_month,
    a.month_number,
    ISNULL(c.customers, 0) AS customers,
    CAST(ISNULL(c.customers, 0) AS FLOAT) / cs.cohort_size AS retention_rate
FROM all_combinations a
LEFT JOIN cohort_counts c
    ON a.cohort_month = c.cohort_month
    AND a.month_number = c.month_number
JOIN cohort_size cs
    ON a.cohort_month = cs.cohort_month
ORDER BY a.cohort_month, a.month_number;


---FUNNEL ANALYSIS

SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM dbo.olist_orders_dataset
GROUP BY order_status
ORDER BY total_orders DESC;

---Funnel Count
SELECT 
    COUNT(*) AS total_orders,

    COUNT(CASE 
        WHEN order_status != 'canceled' 
        THEN 1 END) AS approved_orders,

    COUNT(CASE 
        WHEN order_status = 'delivered' 
        THEN 1 END) AS delivered_orders

FROM dbo.olist_orders_dataset;

---Conversion rates

SELECT 
    COUNT(*) * 1.0 AS total_orders,

    COUNT(CASE 
        WHEN order_status != 'canceled' 
        THEN 1 END) * 1.0 AS approved_orders,

    COUNT(CASE 
        WHEN order_status = 'delivered' 
        THEN 1 END) * 1.0 AS delivered_orders,

    -- Conversion rates
    COUNT(CASE 
        WHEN order_status != 'canceled' 
        THEN 1 END) * 1.0 / COUNT(*) AS approval_rate,

    COUNT(CASE 
        WHEN order_status = 'delivered' 
        THEN 1 END) * 1.0 / COUNT(*) AS delivery_rate

FROM olist_orders_dataset;


---Monthly funnel Trend 

SELECT 
    DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS month,

    COUNT(*) AS total_orders,

    COUNT(CASE 
        WHEN order_status != 'canceled' 
        THEN 1 END) AS approved_orders,

    COUNT(CASE 
        WHEN order_status = 'delivered' 
        THEN 1 END) AS delivered_orders

FROM olist_orders_dataset
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
ORDER BY month;


--cancellation analysis
SELECT 
    order_status,
    COUNT(*) AS total
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY total DESC;

---check delivery delay

SELECT 
    AVG(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) AS avg_delivery_days
FROM olist_orders_dataset
WHERE order_status = 'delivered';