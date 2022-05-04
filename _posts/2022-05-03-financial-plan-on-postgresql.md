---
layout: post
title: "Financial plan on PostgreSQL"
modified: 2022-05-03 00:41:06 +0300
description: "See how to build a financial plan on pure SQL using PostgreSQL database. Advance your SQL skills on the practical example."
tags: [postgresql, sql]
comments: true
share: true
image: financial-plan.jpg
---

This post shows how to build a **financial plan** on pure SQL using PostgreSQL database.

Later on, the solution can be reused in a Rails application. So that we can have a **website** that helps to generate a **personal financial plan**.

Along the way, the post teaches very useful PostgreSQL and common SQL concepts such as **views**, **window functions**, **inner/left join**, aggregate and special functions, grouping, ordering, aliasing.

### Tasking

A financial plan is an easy but, same time, comprehensive concept.
Definition of this thing merits a separate post or even a book.
But this post, for simplicity and the purpose of the tech aspects demonstrating, doesn't go too far.
Let's agree on the following definition. A financial plan is a concept that builds an accumulative profit based on coming in and going out cash flows.

The system takes an income (that can be a monthly salary, paid dividends, etc.) and expenses (taxes, utility bills, expenses for food, etc.).
Then, using that data, it calculates profit for each month during a year and accumulates to the total. It results in an easy table that's easy to understand for everyone.
Even though it's very primitive, it still can be useful as it could tell when you can afford the next video game, a car, or even the house of your dream.

### Setting up

Create PostgreSQL DB and log into its console:

```shell
$ createdb finance_plan
$ psql -d finance_plan
```

Create `incomes` and `expenses` tables where the corresponding monthly and quarterly amount is kept. The `type` column signifies whether it's monthly or quarterly.

```sql
create table incomes (amount int, type varchar);
create table expenses (amount int, type varchar);
```

> Note, here and further we omit details related to multi-tenancy and performance issues for simplicity of the article aspects demonstration.


These are all tables a **financial plan** needs.

Now let's add some data to the tables that will be used by the code that generates the plan:

```sql
insert into incomes (amount, type) values (2000, 'monthly');
insert into incomes (amount, type) values (500, 'quarterly');
insert into expenses (amount, type) values (500, 'monthly');
insert into expenses (amount, type) values (1000, 'quarterly');
```

Literally, that defines monthly income $2,000 (assume it's our salary) and quarterly income $500 (that can signify some bonuses).
And two expenses: $500 monthly, e.g. utility bills and $1,000 quarterly, e.g. a payment for education.

### The plan as a table

Generating the plan can be done within one SQL query that generates a table with columns: Month, Income, Expenses, Profit, Accumulative Profit.
A row represents calculations for a specific month. There are as many rows as months - 12.

To generate 12 rows that represent a month number we can use series:

```sql
select * from generate_series(1, 12) as month;
 month
═══════
     1
     2
     3
     4
     5
     6
     7
     8
     9
    10
    11
    12
(12 rows)
```

Not to write this SQL again and again we can create a short-cut that can be kinda a virtual table,
but behave like a real table when it comes to retrieving data. PostgreSQL has a special concept for that - **views**.

```sql
create view months as (select * from generate_series(1, 12) as month);
```

This is how it can be used by `select`:

```sql
select month from months;
 month
═══════
     1
     2
     3
     4
     5
     6
     7
     8
     9
    10
    11
    12
(12 rows)
```

Moving one step forward, let's select the sum of monthly expenses and incomes:

```sql
select month, sum(monthly_expenses.amount) as monthly_expenses
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  group by month
  order by month;
 month │ monthly_expenses
═══════╪══════════════════
     1 │              500
     2 │              500
     3 │              500
     4 │              500
     5 │              500
     6 │              500
     7 │              500
     8 │              500
     9 │              500
    10 │              500
    11 │              500
    12 │              500
(12 rows)
```

`join expenses as monthly_expenses on monthly_expenses.type = 'monthly'` means inner joining only monthly expenses and register them by name `monthly_expenses`.
Later on, that allows to use this logical and clear for us name in the select.
`group by month` allows to aggregate the data and use sum as there can be many monthly expenses.

Using the same idea, we select quarterly expenses:

```sql
select month, sum(monthly_expenses.amount) as monthly_expenses, sum(quarterly_expenses.amount) as quarterly_expenses
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ monthly_expenses │ quarterly_expenses
═══════╪══════════════════╪════════════════════
     1 │              500 │                  ¤
     2 │              500 │                  ¤
     3 │              500 │               1000
     4 │              500 │                  ¤
     5 │              500 │                  ¤
     6 │              500 │               1000
     7 │              500 │                  ¤
     8 │              500 │                  ¤
     9 │              500 │               1000
    10 │              500 │                  ¤
    11 │              500 │                  ¤
    12 │              500 │               1000
(12 rows)
```

Note, how `quarterly_expenses` are joined now. It uses additional condition `month % 3 = 0` because there only 4 months with quarterly expenses: 3, 6, 9, 12.
And all of these numbers are multipliers of 3.
In case there are no expenses we don't want the rows crossed out by the select, so it uses `left join` instead of inner one.


To better feel left join need check out how the result looks like using inner join:

```sql
select month, sum(monthly_expenses.amount) as monthly_expenses, sum(quarterly_expenses.amount) as quarterly_expenses
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ monthly_expenses │ quarterly_expenses
═══════╪══════════════════╪════════════════════
     3 │              500 │               1000
     6 │              500 │               1000
     9 │              500 │               1000
    12 │              500 │               1000
(4 rows)
```

Not exactly what we want, agreed?

It's time to summarize all expenses (monthly + quarterly) for each month:

```sql
select
    month,
    sum(monthly_expenses.amount) as monthly_expenses,
    sum(quarterly_expenses.amount) as quarterly_expenses,
    sum(monthly_expenses.amount) + sum(quarterly_expenses.amount) as expenses
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ monthly_expenses │ quarterly_expenses │ expenses
═══════╪══════════════════╪════════════════════╪══════════
     1 │              500 │                  ¤ │        ¤
     2 │              500 │                  ¤ │        ¤
     3 │              500 │               1000 │     1500
     4 │              500 │                  ¤ │        ¤
     5 │              500 │                  ¤ │        ¤
     6 │              500 │               1000 │     1500
     7 │              500 │                  ¤ │        ¤
     8 │              500 │                  ¤ │        ¤
     9 │              500 │               1000 │     1500
    10 │              500 │                  ¤ │        ¤
    11 │              500 │                  ¤ │        ¤
    12 │              500 │               1000 │     1500
(12 rows)
```


Note, the `¤` symbol in the table. That's not what we want. Only the months without quarterly expenses have these weird symbols.
They mean `null` (this is how my PostgreSQL console is configured, it's possible to configure to show `null` in some other way).
`sum(quarterly_expenses.amount)` gives `null` on the rows with empty joined quarterly expenses and if sum it up with some other number it results in `null` as well.

But we don't need that, this `null` should be `0` in fact. Use `coalesce` for that:

```sql
select
    month,
    sum(monthly_expenses.amount) as monthly_expenses,
    coalesce(sum(quarterly_expenses.amount), 0) as quarterly_expenses,
    sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0) as expenses
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ monthly_expenses │ quarterly_expenses │ expenses
═══════╪══════════════════╪════════════════════╪══════════
     1 │              500 │                  0 │      500
     2 │              500 │                  0 │      500
     3 │              500 │               1000 │     1500
     4 │              500 │                  0 │      500
     5 │              500 │                  0 │      500
     6 │              500 │               1000 │     1500
     7 │              500 │                  0 │      500
     8 │              500 │                  0 │      500
     9 │              500 │               1000 │     1500
    10 │              500 │                  0 │      500
    11 │              500 │                  0 │      500
    12 │              500 │               1000 │     1500
(12 rows)
```


Here we go! Now it has correctly calculated sum of expenses for each month.

Repeat the same manipulations with incomes:

```sql
select
    month,
    sum(monthly_expenses.amount) as monthly_expenses,
    coalesce(sum(quarterly_expenses.amount), 0) as quarterly_expenses,
    sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0) as expenses,
    sum(monthly_incomes.amount) as monthly_incomes,
    coalesce(sum(quarterly_incomes.amount), 0) as quarterly_incomes,
    sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0) as incomes
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  join incomes as monthly_incomes on monthly_incomes.type = 'monthly'
  left join incomes as quarterly_incomes on quarterly_incomes.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ monthly_expenses │ quarterly_expenses │ expenses │ monthly_incomes │ quarterly_incomes │ incomes
═══════╪══════════════════╪════════════════════╪══════════╪═════════════════╪═══════════════════╪═════════
     1 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     2 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     3 │              500 │               1000 │     1500 │            2000 │               500 │    2500
     4 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     5 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     6 │              500 │               1000 │     1500 │            2000 │               500 │    2500
     7 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     8 │              500 │                  0 │      500 │            2000 │                 0 │    2000
     9 │              500 │               1000 │     1500 │            2000 │               500 │    2500
    10 │              500 │                  0 │      500 │            2000 │                 0 │    2000
    11 │              500 │                  0 │      500 │            2000 │                 0 │    2000
    12 │              500 │               1000 │     1500 │            2000 │               500 │    2500
(12 rows)
```

We are too close to our expected resulting table that should have. Remember, the desired columns: Month, Income, Expenses, Profit, Accumulative Profit.
Let's remove those temp columns monthly_expenses, quarterly_expenses, monthly_incomes, quarterly_incomes.
They are good for details and use this information for debugging, but as we are sure now that it has no mistakes, we simplify it:

```sql
select
    month,
    sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0) as expenses,
    sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0) as incomes
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  join incomes as monthly_incomes on monthly_incomes.type = 'monthly'
  left join incomes as quarterly_incomes on quarterly_incomes.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ expenses │ incomes
═══════╪══════════╪═════════
     1 │      500 │    2000
     2 │      500 │    2000
     3 │     1500 │    2500
     4 │      500 │    2000
     5 │      500 │    2000
     6 │     1500 │    2500
     7 │      500 │    2000
     8 │      500 │    2000
     9 │     1500 │    2500
    10 │      500 │    2000
    11 │      500 │    2000
    12 │     1500 │    2500
(12 rows)
```

It's easy to add profit column that's `incomes - expenses`:

```sql
select
    month,
    sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0) as expenses,
    sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0) as incomes,
    (sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0)) -
    (sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0)) as profit
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  join incomes as monthly_incomes on monthly_incomes.type = 'monthly'
  left join incomes as quarterly_incomes on quarterly_incomes.type = 'quarterly' and month % 3 = 0
  group by month
  order by month;
 month │ expenses │ incomes │ profit
═══════╪══════════╪═════════╪════════
     1 │      500 │    2000 │   1500
     2 │      500 │    2000 │   1500
     3 │     1500 │    2500 │   1000
     4 │      500 │    2000 │   1500
     5 │      500 │    2000 │   1500
     6 │     1500 │    2500 │   1000
     7 │      500 │    2000 │   1500
     8 │      500 │    2000 │   1500
     9 │     1500 │    2500 │   1000
    10 │      500 │    2000 │   1500
    11 │      500 │    2000 │   1500
    12 │     1500 │    2500 │   1000
(12 rows)
```

To get the accumulative profit column that summarizes the current row profit with the previous one we should use a **window function**.
That's another concept of PostgreSQL that allows to capture the current row and to apply an aggregate function on the other rows.
In our case, we want to summarize the current row profit with the previous one. The piece if SQL is pretty easy to do that: `sum(profit) over (order by month)`.
But as `profit` it's a dynamic value calculated on the fly using another `sum` function it doesn't allow to nest them.

To move forward and unblock this constraint, we create another view from the current result:

```sql
create view monthy_profits as (
  select
    month,
    sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0) as expenses,
    sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0) as incomes,
    (sum(monthly_incomes.amount) + coalesce(sum(quarterly_incomes.amount), 0)) -
    (sum(monthly_expenses.amount) + coalesce(sum(quarterly_expenses.amount), 0)) as profit
  from months
  join expenses as monthly_expenses on monthly_expenses.type = 'monthly'
  left join expenses as quarterly_expenses on quarterly_expenses.type = 'quarterly' and month % 3 = 0
  join incomes as monthly_incomes on monthly_incomes.type = 'monthly'
  left join incomes as quarterly_incomes on quarterly_incomes.type = 'quarterly' and month % 3 = 0
  group by month
  order by month
);
```

Now, we can easily select the result:

```sql
select * from monthy_profits;
 month │ expenses │ incomes │ profit
═══════╪══════════╪═════════╪════════
     1 │      500 │    2000 │   1500
     2 │      500 │    2000 │   1500
     3 │     1500 │    2500 │   1000
     4 │      500 │    2000 │   1500
     5 │      500 │    2000 │   1500
     6 │     1500 │    2500 │   1000
     7 │      500 │    2000 │   1500
     8 │      500 │    2000 │   1500
     9 │     1500 │    2500 │   1000
    10 │      500 │    2000 │   1500
    11 │      500 │    2000 │   1500
    12 │     1500 │    2500 │   1000
(12 rows)
```

And finally, add the accumulative profit column:

```sql
select month "Month", expenses "Expenses", incomes "Income", profit "Profit", sum(profit) over (order by month) "Accumulative Profit" from monthy_profits;
 Month │ Expenses │ Income │ Profit │ Accumulative Profit
═══════╪══════════╪════════╪════════╪═════════════════════
     1 │      500 │   2000 │   1500 │                1500
     2 │      500 │   2000 │   1500 │                3000
     3 │     1500 │   2500 │   1000 │                4000
     4 │      500 │   2000 │   1500 │                5500
     5 │      500 │   2000 │   1500 │                7000
     6 │     1500 │   2500 │   1000 │                8000
     7 │      500 │   2000 │   1500 │                9500
     8 │      500 │   2000 │   1500 │               11000
     9 │     1500 │   2500 │   1000 │               12000
    10 │      500 │   2000 │   1500 │               13500
    11 │      500 │   2000 │   1500 │               15000
    12 │     1500 │   2500 │   1000 │               16000
(12 rows)
```

Note, how it's possible to give complex names to column aliases using quotes `"`, also the `as` keyword can be omitted.

That's the complete financial plan. The Accumulative Profit column allows understanding when we can afford to buy something expensive.
Say, if we want to buy a car that costs $10,000 we can do that only in month 8. Only on that month we have cash more than $10,000 that's equal to $11,000.
