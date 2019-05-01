---
layout: post
title: "Efficient algorithm to check dates overlap"
modified: 2019-04-07 00:41:06 +0300
description: "Do you need an efficient algorithm that checks a date range overlapping with some denoted set of date ranges? This article explains how to solve this problem with a subtle approach."
tags: [postgresql, sql, ruby, rails, active_record]
comments: true
share: true
---

**TL;DR:** use SQL `end_date2 >= start_date1 and end_date1 >= start_date2`.

### Problem

Picture this. A real estate site's guest wants to book a hotel for specific dates and the system should check whether these dates are available, i.e. if they are not overlapping with some other already existing booking. Let's say, this hypothetical site is written in Rails and software engineers have come up with `Booking` model representing `bookings` table with two columns: `start_date` and `end_date` of `date` type. Also suppose, there is a validation somewhere checking `start_date <= end_date`. Although, the solution below describes how to cope with this specific situation, it can be applied to another similar data model.

### Solution

Probably, the easiest solution of this problem could be handled with a Rails way. Just define a custom validation inside `Booking` model that performs every time when a new booking is created or existing one is updated:

```ruby
class Booking < ApplicationRecord
  # ... some code is skipped here for simplicity's sake
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

But unfortunately there is a performance bottleneck here. Keep in mind, all the bookings are fetched from the database first. Then they are deserialized into the `Booking` model instance and after that the period of each is checked against the creating/updating `Booking` instance. At first glance - such an easy code, but how many complicated things it actually does! It creates so many objects consuming a lot of memory on the machine running this code. That is actually the main reason of any software slowness. However, sometimes this attempt can be viable, i.e. when the number of objects fetched from DB is not high. Whether to go with it or not is up to the developer and should be picked wisely considering the possible drawback.

If this approach doesn't work a new one should be searched. What can be done to improve this? In order to answer this question the root cause of the problem should be understood. And it's actually highlighted above - the number of allocated objects is huge. Hence, we need to reduce it. A possible way could be moving the loop into DB and luckily ActiveRecord accepts SQL. This is the code one might end up with using PostgreSQL:

```ruby
def validate_other_booking_overlap
  sql = "daterange(start_date, end_date, '[]') && daterange(:start_date, :end_date, '[]')"
  is_overlapping = Booking.where(sql, start_date: c.start_date, end_date: c.end_date).exists?
  errors.add(:overlaps_with_other) if is_overlapping
end
```

> Read the statement `daterange(start_date, end_date, '[]')` as "create a range of dates from `start_date` to `end_date`, right and left edges inclusively". The third argument `[]` points to the property of inclusiveness. More about this can be found [here](https://www.postgresql.org/docs/9.3/rangetypes.html).

> The `&&` operator used here to check for ranges overlap. Check out the [documentation](https://www.postgresql.org/docs/9.3/functions-range.html) if any questions arise.

What's the issue with this try? Well, this code is much more efficient compared to the first one. But still creates objects for the date ranges, however on DB level this time. Remember, unnecessary number of objects is a slow program cause. That's why, if possible, a number of allocations should be reduced. This code is literally translated from the previous version accenting readability. Therefore, even after the into-SQL transformation it is more or less readable. But how to speed it up? This time the readability emphasis is the key. Often, to fix performance issues current solution may be rewritten in a more efficient way. But this usually sacrifices clarity. Trying this way one may end up the next piece of SQL:

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
> The rest of the code is omitted because it remains the same. From now on, only the line changes from the validation method defining `sql` variable.

It simply checks whether any edge of the first range is inside of the second one. Or whether any edge of the second range is inside of the first one. This choice allocates even less objects, so it must be faster than the previous one. But look at this - it's a bit cumbersome. Can it be better? It turns out it can:

```ruby
sql = ":end_date >= start_date and end_date >= :start_date"
```

What is the logic behind this formula? Ranges overlap if and only if it's not the case they overlap from the left and it's not the case they overlap from the right. Or the following doesn't happen:

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

The proof of this is rather obvious: all possible situations could be drawn and checked. After that it would be clear that all other cases intersect.

Transform this statement to boolean formula:

```sql
not (:end_date < start_date or end_date < :start_date)
```

Get rid of the leading negation and replace all statements inside the parentheses with their negations:

=>
```sql
not (:end_date < start_date) and not (end_date < :start_date)
```
=>
```
:end_date >= start_date and end_date >= :start_date
```

> If this explanation is not clear, please check [it](https://stackoverflow.com/questions/3269434).

The final formula is derived. But are there any downsides? Well, it's a matter of taste. On the one hand, it's less readable than the Rails way solution, in my opinion. On the other hand, it's the most efficient one we've come up with so far. If someone thinks this tricky formula is not clear, there could be just documentation provided. So everyone reading this code could understand what's hidden behind it.

### Conclusion

This article provides a solution of a rather popular problem, in particular ranges of dates overlap. Sometimes it's hard to tackle a specific problem balancing between comprehension and efficiency. This journey supposes to show it up and directs to a solution.

Credit goes to the colleagues who reviewed my pull request solving a similar problem. The suggested final approach was not clear for me and even seemed not working. But a bit of thinking made me to change the opinion. That process of thinking and the proof were pretty interesting. It made me to write this down.

Never give up finding a good solution to your problem. There is always an opportunity to improve. Happy coding!
