create table customers (
customer_id serial primary key,
customer_name varchar(50) not null,
segment varchar(50) not null,
city varchar(100),
state varchar(50),
postal_code varchar(30),
region varchar(20)
);

alter table customers
alter column customer_id type varchar(20);

create table products (
product_id varchar(30) primary key,
product_name varchar(200) not null,
category varchar(50) not null,
sub_category varchar(50) not null,
brand varchar(100),
unit_cost numeric(10, 2) check (unit_cost >= 0),
list_price numeric(10, 2) check (list_price >= 0)
);

create table stores (
store_id varchar(20) primary key,
store_name varchar(100) not null,
city varchar(100),
state varchar(50),
postal_code varchar(20),
region varchar(50),
store_type varchar(50)
);

create table calendar (
cal_date date primary key,
year smallint not null,
quarter varchar(10) not null,
month_number smallint not null,
month_name varchar(20) not null,
year_month varchar(20) not null,
weekday varchar(20) not null,
weekday_number smallint not null,
weekend varchar(20) not null
);

create table orders (
row_id integer primary key,
order_id varchar(30) not null,
order_date date not null references calendar(cal_date),
ship_date date not null,
ship_mode varchar(50),
customer_id varchar(100) not null references customers(customer_id),
store_id varchar (50) not null references stores(store_id),
product_id varchar(20) not null references products(product_id),
sales_channel varchar(30) not null,
quantity integer not null check (quantity > 0),
unit_price numeric (10,2) not null,
discount numeric (4,2) not null check (discount>0 and discount <= 1),
sales numeric (10,2) not null,
cost numeric (10,2) not null,
profit numeric (10,2) not null,
region varchar(50)
);

create table returns (
return_id varchar (40) primary key,
row_id integer not null references orders(row_id),
return_date date not null,
return_reason varchar(100) not null,
quantity_returned integer not null check (quantity_returned>0),
refund_amount numeric (10,2) not null check (refund_amount>=0)
);

create table calendar_staging (
date text,
year text,
quarter text,
month_number text,
month_name text,
year_month text,
weekday text,
weekday_number text,
weekend text
);

insert into  calendar (
cal_date, year, quarter, month_number, month_name,
year_month, weekday, weekday_number, weekend
)
select
TO_DATE(date, 'DD/MM/YYYY'),
year::smallint,
quarter,
month_number::smallint,
month_name,
year_month,
weekday,
weekday_number::smallint,
weekend
from calendar_staging;

create table order_staging (
row_id text,
order_id text,
order_date text,
ship_date text,
ship_mode text,
customer_id text,
store_id text,
product_id text,
sales_channel text,
quantity text,
unit_price text,
discount text,
sales text,
cost text,
profit text,
region text
);

select conname
from pg_constraint
where conrelid = 'orders'::regclass and  contype = 'c';

alter table orders drop constraint orders_discount_check;

alter table orders
add constraint orders_discount_check check(discount >= 0 and discount <= 1);

insert into orders (
row_id, order_id, order_date, ship_date, ship_mode,
customer_id , store_id , product_id, sales_channel,quantity,
unit_price, discount, sales, cost , profit , region
)
select
row_id::integer,
order_id,
TO_DATE(order_date, 'YYYY-MM-DD'),
TO_DATE(ship_date, 'YYYY-MM-DD'),
ship_mode,
customer_id,
store_id,
product_id,
sales_channel,
quantity::integer,
replace(replace(replace(unit_price, '$', ''), ' ', ''), ',', '.')::numeric(10,2),
    (replace(replace(discount, '%', ''), ',', '.')::numeric / 100)::numeric(4,2),
    replace(replace(replace(sales, '$', ''), ' ', ''), ',', '.')::numeric(10,2),
replace(replace(replace(cost, '$', ''), ' ', ''), ',', '.')::numeric(10,2),
    replace(replace(replace(profit, '$', ''), ' ', ''), ',', '.')::numeric(10,2),
region
from order_staging;

create table returns_staging (
return_id  text,
row_id text,
return_date text,
return_reason  text,
quantity_returned text,
refund_amount text
);

insert into  returns (
return_id, row_id, return_date, return_reason, quantity_returned,
refund_amount
)
select
return_id,
row_id::integer,
TO_DATE(return_date, 'DD/MM/YYYY'),
return_reason,
quantity_returned::integer,
refund_amount::numeric(10,2)
from returns_staging;