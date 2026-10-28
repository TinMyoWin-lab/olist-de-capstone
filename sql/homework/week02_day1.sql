-- Week 2 · Day 1 homework — core querying (SELECT, GROUP BY, HAVING)

-- Q1: How many customers are there in each state? Show the top 5 states.
select customer_state,count(*) as customers
from customers
group by customer_state
order by customers desc 
limit 5;

--Q2: How many distinct real customers (customer_unique_id) are there?
select count(distinct customer_unique_id)  from customers;


-- Q3: Which payment_type is used most, and what is its total payment_value?
select payment_type,count(*) payment,sum(payment_value) as total_value
from order_payments
group by payment_type
order by total_value desc
limit 1;

-- Q4.How many reviews are there for each review_score (1 to 5)? What is the overall average score?
select review_score , count(*) as review_count, 
(select avg(review_score) from order_reviews) as overall_avg_score
from order_reviews
group by review_score
order by review_score;

-- Q5.Sellers by state: which states have more than 50 sellers?
select seller_state,count(*) as seller_count
from sellers
group by seller_state
having count(*) > 50
order by seller_state ;

-- Q6.Average price and freight per order item, rounded to 2 decimals
-- TODO: grouping by order_item_id gives one average per item position; the question wants one overall average.
select order_item_id,Round(avg(price),2) as average_price,Round(avg(freight_value),2) as average_freight
from order_items
group by order_item_id 
order by order_item_id ;
