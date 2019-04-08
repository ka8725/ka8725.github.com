---
layout: post
title: "Efficient algorithm to check dates overlap"
modified: 2019-04-07 00:41:06 +0300
description: "Need for coming up with an efficient algorithm checks a date range overlapping with some denoted set of date ranges? This article explains how to solve this problem with an efficient approach."
tags: [postgresql, sql, ruby, rails, active_record]
comments: true
share: true
---

**TL;DR:** use SQL `end_date2 >= start_date1 and end_date1 >= start_date2`.

### Problem

Consider the following scenario. A real estate site's guest wants to book a hotel for specific dates and the system should check whether these dates are available, i.e. if they aren't overlapping with some other already existing booking. Assume for this hypothetical site written in Rails software engineers have come up with `Booking` model represents `bookings` table with two columns `start_date` and `end_date` of `date` type. Also it's supposed there is a validation somewhere checks that `start_date <= end_date`. Although the solution below describes how to cope with this specific situation, it can be applied to another similar data model.

### Solution

Probably, the easiest solution of this problem could be written in Rails way. Just define a custom validation inside `Booking` model that performs every time when a new booking creates or existing one updates:

```ruby
class Booking < ApplicationRecord
  # ... some code missed here for the sake of simplicity
  validate :validate_other_booking_overlap

  def period
    start_date..end_date
  end

  private

  def validate_other_booking_overlap
    other_bookings = Booking.all
    is_overlapping = other_bookings.any? do |other_booking|
      period.overlaps?(other_booking.period)
    end
    errors.add(:overlaps_with_other) if is_overlapping
  end
end
```

But unfortunately there is a performance bottleneck here. Keep in mind, all the bookings should be fetched from the database first, then deserialized into the `Booking` model instance and after that each of their period should be checked against the creating/updating `Booking` instance. Such easy code at first glance, but how many complicated things it actually does! It creates so many objects consume a lot of memory on the machine runs this code, what's actually the main reason of any software slowness. However, sometimes this attempt can be viable. I.e., when the number of objects fetched from DB is not high. Whether to go with it or not is up to the developer and should be picked wisely considering the possible drawback.

If this approach doesn't work a new one should be searched for. What can be done to improve this? In order to answer this question the root cause of the problem should be understood. And it's actually highlighted above - the number of allocated objects is huge. Hence, we need to reduce it. A possible way could be moving the loop into DB and luckily ActiveRecord accepts SQL. This is the code one might end up with using PostgreSQL:

```ruby
def validate_other_booking_overlap
  sql = "daterange(start_date, end_date, '[]') && daterange(:start_date, :end_date, '[]')"
  is_overlapping = Booking.where(sql, start_date: c.start_date, end_date: c.end_date).exists?
  errors.add(:overlaps_with_other) if is_overlapping
end
```

> Read the statement `daterange(start_date, end_date, '[]')` as "create a range of dates from `start_date` to `end_date`, right and left edges inclusively". The third argument `[]` points to the property of inclusiveness. More about this can be found [here](https://www.postgresql.org/docs/9.3/rangetypes.html).

> The `&&` operator used here to check for ranges overlap. Check out the [documentation](https://www.postgresql.org/docs/9.3/functions-range.html) if still have questions.

What's the issue with this try? Well, this code is much more efficient comparing to the first one. But still, it creates objects for the date ranges, but on DB level this time. Remember, unnecessary number of objects is a  cause of slow program. That's why number of allocations should be reduced if possible. This code is literally translated from the previous version emphasised on readability. So even now after the into-SQL transformation it's more or less readable. But how to speed it up? This time the readability emphasise is the clue. Usually, when deal with performance issues current solution may be rewritten in a more efficient way, but sacrificing readability. Trying this way one may go with piece of SQL:

```ruby
sql = <<~SQL
  (
    (start_date <= :start_date and :start_date <= end_date) or
    (start_date <= :end_date and :end_date <= end_date)
  ) or (
    (:start_date <= start_date and start_date <= :end_date) or
    (:start_dae <= end_date and end_date <= :end_date)
  )
SQL
```
> The rest of the code is omitted because it remains the same. From now on only the line from the validation method that defines `sql` variable changes.

It simply checks whether any edge of the first range is inside of the second one or whether any edge of the second range is inside of the first range. This solution allocates even less objects, so it must be faster than the previous one. But look at this, it's a bit cumbersome, readability is obviously lower. Can it be better? It turns out it can:

```ruby
sql = ":end_date >= start_date and end_date >= :start_date"
```

What the logic behind this formula? Ranges overlap if and only if it's not the case they overlap from the left and it's not the case when they overlap from the right. I.e. the following is not happening:

```
                      start_date          end_date
                          |--------------------|
:start_date     :end_date
|-------------------|
```

or

```
start_date          end_date
    |--------------------|
                           :start_date        :end_date
                              |-------------------|
```

The proof of this is rather obvious: all possible situations could be drawn and checked, after that it would be clear that all other cases lead to an intersection.

Transforming this statement to boolean formula:

```sql
not (:end_date < start_date or end_date < :start_date)
```

Getting read of the leading negation all statements inside parentheses replace with their negations:

=>
```sql
not (:end_date < start_date) and not (end_date < :start_date)
```
=>
```
:end_date >= start_date and end_date >= :start_date
```

> If this explanation is not clear please check out [this](https://stackoverflow.com/questions/3269434).

The final formula is derived. But are there downsides of this solution? Well, it's the matter of taste, but in my opinion it's less readable than the Rails way solution. But from the other hand, it's the most efficient one we've come up with so far. If someone thinks this code is not clear there could be just documentation provided, so everyone reads this code could understand what happens there.

### Conclusion

This article provides a solution of rather popular problem - ranges of dates overlap. Sometimes it's hard to pick a proper solution for a specific problem, but there should be always balance between code readability and efficiency. Credit goes to my colleagues who reviewed my pull request solved a similar problem and where all of these issues and approaches were discussed.

Never give up finding a good solution of your problem, there is always opportunity to improve. Happy coding!
