-- QUERY 1: Gross vs. Net Revenue and Profitability (Adjusted for Returns)
-- Business Question: How much actual net revenue and profit does each product 
--                    category generate after accounting for customer refunds?

select p.category,
count(o.row_id) as total_orders,
count(r.return_id) as returned_orders,
round(count(r.return_id)::numeric/count(o.row_id)*100,2) as return_rate_pct,
sum(o.sales) as gross_sales,
sum(coalesce(r.refund_amount,0)) as total_refunds,
sum(o.sales) - sum(coalesce(r.refund_amount,0)) as net_sales,
sum(o.profit) as gross_profit,

sum(o.profit - coalesce(r.refund_amount,0)) as net_profit,
round(sum(o.profit - coalesce(r.refund_amount,0))/
nullif(sum(o.sales - coalesce(r.refund_amount,0)),0)*100,2) as net_margin_pct
from orders o
inner join products p on
o.product_id = p.product_id
left join returns r on 
o.row_id = r.row_id
group by p.category
order by net_profit desc;


-- QUERY 2: High Discount Policy Impact Analysis
-- Business Question: At what discount threshold does the company erode its 
--                    profit margin and start generating net losses?

select round(o.discount * 100,0) as discount_pct,
case 
when o.discount = 0 then 'No Discount (0%)'
when o.discount <= 0.15 then 'Low Discount (5-15%)'
when o.discount <= 0.30 then 'Medium Discount (20-30%)'
else 'High Discount (40%+)'
end as discount_tier,
count(o.row_id) as transactions_count,
round(avg(o.quantity),2) as avg_items_per_order,
sum(o.sales) as total_sales,
sum(o.profit) as total_profit,
round(avg(o.profit), 2) as avg_profit_per_order,
round(sum(o.profit) / nullif(sum(o.sales), 0) * 100, 2) as profit_margin_pct
from orders o
group by o.discount, discount_tier
order by o.discount asc;

-- QUERY 3: Product Quality & Return Rate Diagnostics by Channel and Brand
--Which sales channels and brands suffer most from quality 
--             issues ('Defective' or 'Not as Described')?

--3A. Sales Channel Comparison (Online vs. In-Store)

select o.sales_channel,
count(o.row_id) as total_orders,
count(r.return_id) as total_returns,
ROUND(count(r.return_id)::numeric / count(o.row_id) * 100, 2) as return_rate_pct,
sum(case when r.return_reason in ('Defective', 'Not as Described')then 1 else 0 end) as quality_issues_count,
sum(coalesce(r.refund_amount, 0)) as lost_revenue_refunds
from orders o
left join returns r on 
o.row_id = r.row_id
group by o.sales_channel
order by return_rate_pct desc;


--3B. Top 10 Brands by Quality-Related Return Rate (min. 50 orders)
select p.brand,p.category,
count(o.row_id) as total_orders,
sum(case when r.return_reason in ('Defective', 'Not as Described') then 1 else 0 end) as quality_returns,
ROUND(sum(case when r.return_reason in ('Defective', 'Not as Described') then 1 else 0 end)::numeric
/count(o.row_id) * 100, 2) as quality_return_rate_pct,
sum(coalesce(r.refund_amount, 0)) as total_refunds
from orders o
inner join products p on o.product_id = p.product_id
left join returns r on o.row_id = r.row_id
group by p.brand, p.category
having count(o.row_id) >= 50
order by quality_return_rate_pct desc
limit 10;


-- QUERY 4: RFM Customer Segmentation (Recency, Frequency, Monetary)
-- Who are our highest-value customers, and which valuable 
--       segments are at risk of churning?

with customer_metrics as (
select  c.customer_id,c.customer_name, c.segment as customer_type,c.region,

(select max(order_date) from orders) - max(o.order_date) as recency_days,
count(distinct o.order_id) as frequency_orders,
sum(o.sales - coalesce(r.refund_amount, 0)) as monetary_net_sales
from customers c
inner join orders o on 
c.customer_id = o.customer_id
left join returns r on
o.row_id = r.row_id
group by c.customer_id, c.customer_name, c.segment, c.region
),
rfm_segmented as (
select *, case
when recency_days <= 90 and frequency_orders >= 5 and monetary_net_sales >= 1000 then 'Champions'
when recency_days <= 180 and frequency_orders >= 3 then 'Loyal Customers'
when recency_days > 180 and monetary_net_sales >= 800 then 'At Risk (High Value)'
when recency_days > 365 then 'Lost / Churn'
else'Potential / Regular'
end as rfm_segment
from customer_metrics
)

select rfm_segment,
count(customer_id) as customers_count,
round(avg(recency_days), 0) as avg_recency_days,
round(avg(frequency_orders), 1) as avg_orders,
round(sum(monetary_net_sales), 2) as total_segment_revenue,
round(avg(monetary_net_sales), 2) as avg_ltv_revenue
from rfm_segmented
group by rfm_segment
order by total_segment_revenue desc;


-- QUERY 5: Analytical Data Mart Creation (VIEW) for R and Excel

create or replace view v_clean_sales_summy 
as select 
o.row_id,
o.order_id,
o.order_date,
cal.year,
cal.quarter,
cal.month_number,
cal.month_name,
cal.year_month,
cal.weekday,
cal.weekend,
o.sales_channel,
o.ship_mode,
c.customer_id,
c.segment as customer_segment,
c.region,
s.store_name,
s.store_type,
p.product_id,
p.product_name,
p.category,
p.sub_category,
p.brand,
o.quantity,
o.unit_price,
o.discount,
o.sales as gross_sales,
o.cost,
o.profit as gross_profit,

case when r.return_id is not null then 1 else 0 end as is_returned,
coalesce(r.return_reason,'No Return') as return_reason,
coalesce(r.quantity_returned,0) as quantity_returned,
coalesce(r.refund_amount,0) as refund_amount,

(o.sales - coalesce(r.refund_amount,0)) as net_sales,
(o.profit - coalesce(r.refund_amount,0)) as net_profit
from orders o
inner join calendar cal on 
o.order_date = cal.cal_date
inner join customers c on 
o.customer_id = c.customer_id
inner join stores s on 
o.store_id = s.store_id
inner join products p on
o.product_id = p.product_id
left join returns r on 
o.row_id = r.row_id;

select * from v_clean_sales_summy 
limit 10;















