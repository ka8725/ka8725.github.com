---
layout: post
title: "Change data in migrations like a boss"
description: "Update data in migrations like a boss. Don't write raw SQL in migration, don't define again your models in migrations again, don't use seeds. Use migration_data gem to keep your migrations up to date, migration data in production, test migration data code and remove them when you want."
tags: [rails, migrations]
---
{% include JB/setup %}

Changing data on change database schema in production is a common problem for Rails developers. Assume that you have a Rails project. Some day you decided to change the database schema and want to add some new column. Then you have to go through all your models and change actual data according this new schema. Currently there are solutions to overcome this. But all of them have their disadvantages. You will see in this chapter them. This post tells about these disadvantages and how to get rid of the issue with the `migration_data` gem.

## Solutions with disadvantages

There are many solutions to avoid the issue. This is a list of them:

* Writing code in migrations without caution
* Duplicate classes in migrations
* Writing raw SQL in migrations
* Using seeds
* Other methods

Now let's look at all of them one by one and see what are problems have these solutions.

### Writing code in migrations without caution

Say we are going to add a column to a `User` model and then update all users in our database. So the migration may look like this:

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

Today this migration works without problems. We are committing this code to our version control system (I hope it's `git`). In a week we will have to run it on the production server. All our team members get this new code and run the migration. It works as expected - perfect! But tomorrow we decide to rename the `User` model to `Customer`. We create new migration to rename the table, rename the `User` model to `Customer` and don't touch the old migrations. Tests are working, new migration is working and everyone is happy. But what will be with this migration in one week when we run it on the production server? It will be broken because at those moment we won't have `User` model yet. We forgot to rename the `User` model in the old migrations. It happens too often in Rails development. So *don't be like a kamikaze and don't write code to update data in migrations*. Never!

### Duplicate classes in migrations

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

Now when you rename the `User` model in the new migration this code won't fail. For this example the solution is suitable. But the problems come when you have to define for example polymorphic association in the migration:

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

The code will work without exception but actually it doesn't set correct association because the defined class are under namespace `AddStatusToUser`. This is what happens in reality:

{% highlight ruby %}
role = AddStatusToUser::Role.create!(name: 'admin')
AddStatusToUser::User.create!(nick: '@ka8725', role: role)
{% endhighlight %}


And when you have the bug in production you may decide to figure out why the association is not set for the user. You open rails console and check the association:

{% highlight ruby %}
user = User.find_by(nick: '@ka8725')
user.role       # => nil
user.role_type  # => AddStatusToUser::Role
{% endhighlight %}

As you see the `role_type` is set incorrectly it should be `Role` without the namespace. That's why this solution bug prone as well.

### Writing raw SQL in migrations

To be honest this solution doesn't have disadvantages except a few. You have to now SQL and sometimes well. And as a result requires more time to write the code. Besides of this Rails developers don't prefer to write raw SQL because if you want to migrate through PostgreSQL to MySQL for example you may have to fix much raw SQL code. Check out [official documentation](http://guides.rubyonrails.org/migrations.html#when-helpers-aren-t-enough) to get examples how to write raw SQL in migrations.

### Using seeds

Rails has useful approach to populate the database. You may write any code in the `db/seeds.rb` file and run `rake db:seed` command. This is great solution to populate the database by some data at first start but then, when your project is released and you have to change the data on changing the database schema this won't help you. Also writing the code in one file may lead to the mess. Of course you may create your own dependent files and then load them in the `seeds.rb` file but anyway you have to worry about what to do on second run. There is also gem which helps to structuring you seeds data - [seedbank](https://github.com/james2m/seedbank). But again it doesn't solve all these problems.

### Other methods

No doubt that there are many other methods. For example create rake tasks, of even going to production console and write code there after deploying (I hope you don't do it). But none of them doesn't solve all problems with the problem.

## Use migration_data gem

Recently I've released gem which solves all these problems. This is the [migration_data](https://github.com/ka8725/migration_data). After it's installing you will able to define a `data` method in your migrations and write the code here. The method runs only on migrating up (i.e. on `rake db:migrate` but doesn't run on `rake db:rollback`). Additionally to keep the code in `data` method up to date just write tests for this. The gem provides `require_migration` method to help load migrations easily to the tests.

Migration example:

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

The test will fail you have some unexpected changes in the code and you will be informed that your migration is not actual immediately. Currently the gem works with Ruby >= 2.0 and Rails >= 4.0.0.rc1.

# Conclusion

The only solution to keep your migrations up to date with any code which lives there is to write tests for them. But if you write the migration data code and code to change database schema simultaneously in `up`, `down` or `change` methods you won't able to write tests for these migrations. Change database schema in tests is not good idea, isn't it? So if you have these problems this gem is what you are looking for.
