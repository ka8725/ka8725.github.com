---
layout: post
title: "Change data in migrations like a boss"
description: "Update data in migrations like a boss. Don't write raw SQL in migration, don't define models in migrations again, don't use seeds. Use migration_data gem to keep your migrations up to date, migrate data in production, test data migration code and clean them up."
tags: [rails, migrations]
share: true
featured_post: false
comments: true
redirect_from:
  - /2014/01/30/change-data-in-migrations-like-a-boss/
---


Changing data in production is a common problem for Rails developers. Assume you have a Rails project. One day you decide to change the database schema and want to add some new column. Then you have to go through all existing records and change data to be actual according to this new schema. There are solutions to overcome this. But they have disadvantages. You will see them in this article. And finally, figure out how to avoid the issues with `migration_data` gem.

## Solutions with disadvantages

There are many approaches to deal with data migrations in Rails application:

* Use model classes in migrations carelessly
* Redefine models in migrations
* Write raw SQL in migrations
* Use seeds
* Other methods

Now let's look at all of them one by one and see what problems these solutions have.

### Use model classes in migrations carelessly

Let's say, we are going to add a column to `User` model and then update all users in our database. So the migration may look like this:

{% highlight ruby %}
class AddStatusToUser < ActiveRecord::Migration
  def up
    add_column :users, :status, :string
    User.find_each do |user|
      user.status = 'active'
      user.save!
    end
  end

  def down
    remove_column :users, :status
  end
end
{% endhighlight %}

Today this migration works without problems. We are committing this code to our version control system (I hope it's `git`). All our team members fetch this new code and run the migration. It works as expected - perfect! But tomorrow we decide to rename the `User` model to `Customer`. We create a new migration to rename the table, rename the `User` model to `Customer` and don't touch the old migrations. Tests are working, new migration is working and everyone is happy. But what will be with this migration in one week when it gets run on the production server? It will fail because at that moment we won't have `User` model already. We forgot to rename the `User` model in the old migration. It happens too often in a startup follows the agile development approach.

Obviously, this solution is not recommended.

### Redefine models in migrations

There is a similar solution to the previous one and it may be useful in some cases. Just define the `User` model in the migration:

{% highlight ruby %}
class AddStatusToUser < ActiveRecord::Migration
  class User < ActiveRecord::Base
  end

  def up
    add_column :users, :status, :string
    User.find_each do |user|
      user.status = 'active'
      user.save!
    end
  end

  def down
    remove_column :users, :status
  end
end
{% endhighlight %}

Now when you rename the `User` model in the new migration this code won't fail. For this example the solution is suitable. But the problems come when you have to define a polymorphic association in the migration:

{% highlight ruby %}
class AddStatusToUser < ActiveRecord::Migration
  class User < ActiveRecord::Base
    belongs_to :role, polymorphic: true
  end

  class Role < ActiveRecord::Base
    has_many :users, as: :role
  end

  def up
    add_column :users, :status, :string
    role = Role.create!(name: 'admin')
    User.create!(nick: '@ka8725', role: role)
  end

  def down
    remove_column :users, :status
  end
end
{% endhighlight %}

The code will work without exception but it doesn't set correct association, because the defined classes are under namespace `AddStatusToUser`. This is what happens in reality:

{% highlight ruby %}
role = AddStatusToUser::Role.create!(name: 'admin')
AddStatusToUser::User.create!(nick: '@ka8725', role: role)
{% endhighlight %}


A bug in production pops up after run of a migration like this. You connect to the server, open rails console, and see what's the heck:

{% highlight ruby %}
user = User.find_by(nick: '@ka8725')
user.role       # => nil
user.role_type  # => AddStatusToUser::Role
{% endhighlight %}

As you see the `role_type` is set incorrectly it should be `Role` without the namespace. That's why this solution is bug-prone as well. It's definitely not recommended. Nevertheless, it's like a standard way to overcome the problem in Rails community.

### Writing raw SQL in migrations

To be honest, this solution doesn't have disadvantages except one - you have to know SQL and sometimes very well. So it might require more time to write the code. Even if Rails community don't prefer to write raw SQL I would recommend this approach. Once SQL skills are grasped you can cope with any data problems in production.

Refer to [official documentation](http://guides.rubyonrails.org/migrations.html#when-helpers-aren-t-enough) for examples of raw SQL in migrations.

### Use seeds

Rails has useful approach to populate DB. You may write any code in the `db/seeds.rb` file and run `rake db:seed` command. This is a great solution to populate the database by some data at first start but then, when your project is released and you have to change the data on changing the database schema this approach is not handy anymore. Also writing the code in one file may lead to a mess. Of course, you may split the code into files and then load them in the `seeds.rb` file. But anyway, you have to worry about what to do on the second run, i.e. seeds usually are not idempotent. There is also gem which helps to structure you seeds data - [seedbank](https://github.com/james2m/seedbank). But again, this doesn't solve anything, moreover, this solution is not for the problem at all. Don't even try this approach, it just messes up two different concepts. I've provided this solution merely to notice it's not acceptable and I saw examples of this.

### Other methods

No doubt, there are many other methods. For example, rake tasks migrate data. Or even writing code in production console after deploy (I hope you don't do this). Below is an attempt to overcome the problem.

## Use migration_data gem

I've formed a gem tries to solve these problems - [migration_data](https://github.com/ka8725/migration_data). The idea behind is very easy: how to ensure code doesn't fail? Correct - with aid of tests. So, why not to write tests for data migrations?

The gem allows defining a special method called `data` in schema migrations. Write the data migration code there. Keep in mind, this method runs only on migrate up, i.e. on `rake db:migrate`, but doesn't run on `rake db:rollback`. Additionally, to keep the code in `data` method actual just write tests for it. That's it.

To have the ability testing migrations there is `require_migration` method loads migrations code easily.

Check out a migration example below:

{% highlight ruby %}
class CreateUsers < ActiveRecord::Migration
  def change
    # Database schema changes as usual
  end

  def data
    User.create!(name: 'Andrey')
  end
end
{% endhighlight %}

And this is a test for the migration:

{% highlight ruby %}
require 'spec_helper'
require 'migration_data/testing'
require_migration 'create_users'

desribe CreateUsers do
  describe '#data' do
    it 'works' do
      expect { CreateUsers.new.data }.to_not raise_exception
    end
  end
end
{% endhighlight %}

The test will fail on some unexpected changes in the code related to `User` model and you will be immediately informed that the migration is not actual anymore on your CI (you have one set up, right?).

# Conclusion

The only solution to keep your migrations up to date with any code lives there is to write tests for them. But if you write the migration data code and code to change database schema simultaneously in `up`, `down` or `change` methods you won't able to write tests for these migrations. Changing database schema in tests is not a good idea, isn't it? So if you have these problems this gem is what you are looking for.

# Update 06/11/2015:

Over time you may notice that it's rather hard to maintain old migrations. Especially, it's true when the code is changing a lot. At this point the best solution that I know is to just remove all the old migrations. After the removal we have to just insert current database structure into the last migration. This way we will have clean migrations history and it will be possible to run them on a new database.

To perform the **migrations squash** I've added a rake task into [the gem](https://github.com/ka8725/migration_data#clean-old-migration) today. The task name is `db:migrate:squash`. And finally, don't forget to remove the migrations tests. Enjoy!

One note for the rake task. You have to make sure all team members and deployment servers have already run all current migrations before the **squashing**. Otherwise, they can have collisions. This process can be automated later.


# Update 08/12/2015

Once you can get the following state:

{% highlight text %}
              Timeline
                  |
                  |
                  |<— change in the DB schema
                  |
                  |
         Squash —>|
                  |
                  |
{% endhighlight %}

This happens when somebody does the squashing and some other person is creating a new migration. This way you can have inconsistency - the migration for change can try altering the not created yet tables (for example, it just adds a new column to the `users` table, but as it applied to the fresh DB accordingly to the DB history it unfortunately fails). In other words, make sure you don't have a migration before the squashed one. The issue fix is pretty easy: you have to update timestamps for the migration change to be newer than the squash migration.

# Update 18/01/2017

When you have to update a lot of data then the `migration_data` gem might be not a good choice. It takes time to process huge amount of data and the deployment process will be slowed down dramatically. It will increase downtime of your application that's not acceptable for a production application with many online clients. So, if you have such type application then, please, don't use this gem. There are may be used other techniques has already discussed in other great posts and gems:

- [Rails Migrations with Zero Downtime](https://blog.codeship.com/rails-migrations-zero-downtime/)
- [Data Migrations in Rails](https://robots.thoughtbot.com/data-migrations-in-rails)
- [Seed Migration](https://github.com/harrystech/seed_migration)
- [data-migrate](https://github.com/ilyakatz/data-migrate)
