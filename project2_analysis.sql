-- ==============================================================
-- 项目2：Olist 巴西电商数据分析
-- 作者：陈恩溢（NE）
-- 日期：2026.09.30
-- 数据库环境：MySQL 5.7（部分写法兼容 8.0）
-- 描述：包含 RFM 客户分层、留存分析、转化漏斗三大模块
-- ==============================================================

-- --------------------------------------------------------------
-- 1. RFM 客户分层分析
-- 业务目的：识别高价值客户与流失预警客户，为精细化运营提供依据
-- --------------------------------------------------------------
SELECT 
    customer_segment AS '客户分层',
    COUNT(*) AS '客户数量',
    ROUND(AVG(monetary), 2) AS '平均消费金额',
    ROUND(AVG(frequency), 2) AS '平均购买频次'
FROM (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price + oi.freight_value) AS monetary,
        CASE 
            WHEN DATEDIFF('2018-10-17', MAX(o.order_purchase_timestamp)) <= 180 
                 AND SUM(oi.price + oi.freight_value) >= 200 THEN '高价值客户'
            WHEN DATEDIFF('2018-10-17', MAX(o.order_purchase_timestamp)) <= 180 
                 AND COUNT(DISTINCT o.order_id) >= 1 THEN '活跃客户'
            WHEN DATEDIFF('2018-10-17', MAX(o.order_purchase_timestamp)) > 180 
                 AND SUM(oi.price + oi.freight_value) >= 200 THEN '流失预警高价值客户'
            ELSE '一般客户'
        END AS customer_segment
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS t
GROUP BY customer_segment
ORDER BY 客户数量 DESC;


-- --------------------------------------------------------------
-- 2. 留存分析（次日留存、7日留存）
-- 业务目的：衡量用户粘性，验证电商复购模型（该数据集为纯交易数据，留存率极低）
-- --------------------------------------------------------------
SELECT 
    f.first_date AS '首次购买日期',
    COUNT(DISTINCT f.customer_unique_id) AS '新增用户数',
    COUNT(DISTINCT CASE WHEN DATEDIFF(a.active_date, f.first_date) = 1 THEN a.customer_unique_id END) AS '次日留存数',
    COUNT(DISTINCT CASE WHEN DATEDIFF(a.active_date, f.first_date) = 7 THEN a.customer_unique_id END) AS '7日留存数'
FROM (
    SELECT c.customer_unique_id, MIN(DATE(o.order_purchase_timestamp)) AS first_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) f
LEFT JOIN (
    SELECT DISTINCT c.customer_unique_id, DATE(o.order_purchase_timestamp) AS active_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
) a ON f.customer_unique_id = a.customer_unique_id
GROUP BY f.first_date
ORDER BY f.first_date;


-- --------------------------------------------------------------
-- 3. 转化漏斗分析
-- 业务目的：监控核心环节转化与流失情况，评估物流与风控效率
-- --------------------------------------------------------------
SELECT 
    COUNT(DISTINCT CASE WHEN order_status IN ('created', 'approved', 'invoiced', 'processing', 'shipped', 'delivered') THEN order_id END) AS '下单数',
    COUNT(DISTINCT CASE WHEN order_status IN ('approved', 'invoiced', 'processing', 'shipped', 'delivered') THEN order_id END) AS '批准数',
    COUNT(DISTINCT CASE WHEN order_status IN ('shipped', 'delivered') THEN order_id END) AS '发货数',
    COUNT(DISTINCT CASE WHEN order_status = 'delivered' THEN order_id END) AS '妥投数'
FROM orders;