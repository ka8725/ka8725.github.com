---
layout: post
title: "Rails migration for belongs_to association with custom table name"
modified: 2020-02-16 00:41:06 +0300
description: "How to write a Rails migration for a belongs_to association which name does not correspond to the joined table name."
tags: [ruby, rails, active_record, migrations]
featured_post: false
comments: true
share: true
---

**TL;DR:** Provide `to_table` option like that `foreign_key: {to_table: :<table_name>}`.

When it comes to a Rails migration for a `belongs_to` association which name doesn't correspond to the joined table name, it may hard to find out how to do that quickly after reading the Rails documentation or sources. This post should help with that.

Let's start with the following example:
- there is a `User` model in the system already
- we need to add `Payment` model
- `Payment` should belong to a `receiver`, that's `User`.

In the code it would look like that:

```ruby
class User < ApplicationRecord
end

class Payment < ApplicationRecord
  belongs_to :receiver, class_name: 'User'
end
```

Let's try to generate a this model and a migration that creates the DB table for it as per the [documentation](https://edgeguides.rubyonrails.org/active_record_migrations.html#model-generators):

```shell
rails g model payment receiver:references
```

That produces the following migration:

```ruby
class CreatePayments < ActiveRecord::Migration[6.0]
  def change
    create_table :payments do |t|
      t.belongs_to :receiver, null: false, foreign_key: true
      t.timestamps
    end
  end
end
```

Surprisingly, `rake db:migrate` produces the following error:

```
PG::UndefinedTable: ERROR:  relation "receivers" does not exist
```

And the reason is clear. The migration tries to add a foreign key for a not existing table. It takes the association name `receiver` and supposes, as default, that it points to a table that's plural `receivers`. And there is nothing wrong with that. Except the fact, there is no `receivers` table and `users` table should be used instead.

Unfortunately, after significant time spent on docs reading one may even end up with no solution. It's hard to spot one line in the examples somewhere in the deep of Rails code. Hence, I provide a solution here:

```ruby
class CreatePayments < ActiveRecord::Migration[6.0]
  def change
    create_table :payments do |t|
      t.belongs_to :receiver, null: false, foreign_key: {to_table: :users}
      t.timestamps
    end
  end
end
```

And now the migration runs without any failures and produces a correct result that's the created `payments` table with the `receiver_id` column and a foreign key points to the joined `users` table.

So, the solution is to use `foreign_key: {to_table: :users}` for that example above.

I kindly ask you to participate in the docs improvement. Just vote for this [PR](https://github.com/rails/rails/pull/38469). Thank you!

UPDATE 02/20/2020: The PR got merged, what means the documentation got improved!
