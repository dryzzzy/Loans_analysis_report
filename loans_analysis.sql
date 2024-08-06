use financial16_65;
select * from financial16_65.trans;

# Database structure. We can see that there is multiple transactions assigned to one account_id
SELECT
    account_id,
    count(trans_id) as amount
FROM trans
GROUP BY account_id
ORDER BY 2 DESC;


# Query that prepares a summary from the loans given in the following dimensions:
# - year, quarter, month,
# - year, quarter,
# - year,
# - total.

SELECT
    extract(YEAR FROM date) as loan_year,
    extract(QUARTER FROM date) as loan_quarter,
    extract(MONTH FROM date) as loan_month,
    sum(amount) as loan_amount_sum,
    avg(amount) as loan_amount_average,
    count(amount) as loan_total_number
FROM loan
GROUP BY 1, 2, 3
WITH ROLLUP
order by 1, 2, 3;

# A query that distinguish paid loans and unpaid loans.

# Loans paid hav the status A, C; 203 (A) + 403 (C) = 606,
# Loans unpaid B, D; 31 (A) + 45 (C) = 76.

select count(*) from loan;
SELECT
    status,
    count(status)
FROM loan
GROUP BY 1
ORDER BY 1;

# A query that will rank accounts by the following criteria:
# - number of loans granted (descending),
# - amount of loans granted (descending),
# - average loan amount.
# Only repaid loans are taken into account.

with cte as (select account_id,
                    count(loan_id) as loan_total_number,
                    sum(amount)    as loan_amount_sum,
                    avg(amount)    as loan_amount_average
             from loan
             where status in ('A', 'C')
             Group by account_id)

SELECT
    *,
    ROW_NUMBER() over (ORDER BY loan_amount_sum DESC) AS rank_loans_amount,
    ROW_NUMBER() over (ORDER BY loan_total_number DESC) AS rank_loans_count
FROM cte;

# Balance of loans repaid by customer gender.

SELECT
    c.gender,
    sum(l.amount) as amount
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
WHERE l.status IN ('A', 'C')
group by c.gender;

# verification
drop table if exists tmp_results;
create temporary table tmp_results as
SELECT
    c.gender,
    sum(l.amount) as amount
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
WHERE true
    and l.status IN ('A', 'C')
    and d.type = 'OWNER'
group by c.gender;

with cte as (
    select sum(amount) as amount
    from loan as l
    where l.status in ('A', 'C')
)
select (select sum(amount) from tmp_results) - (select amount from cte);

# Which gender has more paid loans - males or females?

SELECT
    c.gender,
    count(l.loan_id) as amount
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
WHERE l.status IN ('A', 'C')
group by c.gender;

# jaki jest średni wiek kredytobiorcy w zależności od płci? What is the average age of borrower by gender?

drop table if exists tmp_analysis;
create temporary table tmp_analysis as
SELECT
    c.gender,
    2021 - extract(year from birth_date) as age,
    sum(l.amount) as amount,
    count(l.amount) as loans_count
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
WHERE true
    and l.status IN ('A', 'C')
    and d.type = 'OWNER'
group by c.gender, 2;

select
    gender,
    avg(age) as avg_age
from tmp_analysis
group by gender;

# in which region there are the most customers,
# in which region the most loans have been repaid by volume,
# in which region the most loans were repaid by amount.


DROP TABLE IF EXISTS tmp_district_analytics;
CREATE TEMPORARY TABLE tmp_district_analytics AS
select
    d2.district_id,
    count(distinct c.client_id) as customer_amount,
    sum(l.amount) as loans_given_amount,
    count(l.amount) as loans_given_count
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
inner join
    district as d2 on
        c.district_id = d2.district_id
WHERE true
    and l.status IN ('A', 'C')
    and d.type = 'OWNER'
group by d2.district_id;

select * from tmp_district_analytics;

# in which region there are the most customers,
select *
from tmp_district_analytics
order by customer_amount desc
limit 1;

# in which region the most loans have been repaid by volume,
select *
from tmp_district_analytics
order by loans_given_count desc
limit 1;

# in which region the most loans were repaid by amount.
select *
from tmp_district_analytics
order by loans_given_amount desc
limit 1;

# Percentage share of each region in the total amount of loans granted
with cte as
(
         select d2.district_id,
         count(distinct c.client_id) as customer_amount,
         sum(l.amount) as loans_given_amount,
         count(l.amount) as loans_given_count
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
inner join
    district as d2 on
        c.district_id = d2.district_id
WHERE true
    and l.status IN ('A', 'C')
    and d.type = 'OWNER'
group by d2.district_id
    )

select
    *,
    loans_given_amount/sum(loans_given_amount) over () * 100 as share
from cte
order by share desc;

# Are there customers in the database who meet the following conditions:
# - account balance exceeds 1000,
# - they have more than five loans,
# We assume that the account balance is the amount of the loan - deposit.
SELECT
    c.client_id,

    sum(amount - payments) as client_balance,
    count(loan_id) as loans_amount
FROM loan as l
         INNER JOIN
     account a using (account_id)
         INNER JOIN
     disp as d using (account_id)
         INNER JOIN
     client as c using (client_id)
WHERE True
  AND l.status IN ('A', 'C')
  AND d.type = 'OWNER'
GROUP BY c.client_id
HAVING
    SUM(amount - payments) > 1000
#     AND COUNT(loan_id) > 5;
order by loans_amount desc; -- clients have at most 1 loan

# - born after 1990

select
    c.client_id,
    sum(l.amount - l.payments) as client_balance,
    count(l.loan_id) as loans_amount
FROM
    loan as l
inner join
    account as a using (account_id)
inner join
    disp as d using (account_id)
inner join
    client as c using (client_id)
INNER JOIN
        district as d2 on
            c.district_id = d2.district_id
WHERE true
    and l.status IN ('A', 'C')
    and d.type = 'OWNER'
#     and extract(year from c.birth_date) > 1990
group by c.client_id;-- there are no clients born after 1990

# A procedure that will refresh the table created (cards_at_expiration) containing the following columns:
# - customer id,
# - id_card,
# - expiration date - assume that the card can be active for 3 years after issuance,
# - customer address (A3)

create table cards_at_expiration
(
    client_id       int                      not null,
    card_id         int default 0            not null,
    expiration_date date                     null,
    A3              varchar(15) charset utf8 not null,
    generated_for_date date                     null
);

DELIMITER $$
DROP PROCEDURE IF EXISTS generate_cards_at_expiration_report;
CREATE PROCEDURE generate_cards_at_expiration_report(p_date DATE)
BEGIN
  truncate table cards_at_expiration;
  insert into cards_at_expiration
    with cte as (select c2.client_id,
                        c.card_id,
                        DATE_ADD(c.issued, interval 3 year) as expiration_date,
                        d2.A3                               as client_adress
                 from card as c
                          inner join
                      disp as d using (disp_id)
                          inner join
                      client as c2 using (client_id)
                          inner join
                      district as d2 using (district_id))
select *,
       p_date
from cte
where p_date between DATE_ADD(expiration_date, interval  -7 day) and expiration_date;
END $$;
DELIMITER ;

# result
CALL generate_cards_at_expiration_report('2001-01-01');
SELECT * FROM cards_at_expiration;