---
layout: post
title: "Integral factories in tests with FactoryGirl"
description: "Keep your FactoryGirl's factories clean and integral with built-in features. This article describes the features and gives advices how to not stuck with an issue when you have inconsistent environment in the tests."
tags: [rails, factory_girl, rspec]
share: true
comments: true
---

Using `FactoryGirl` may cause issues in tests when you have complicated relations in a database. If you don't pay enough attention to integrity in your tests there is a probability to stuck with the inconsistent data. An idea of the blog post to show the problem and give a solution to avoid the situation in your work. Also the solution will prevent some Ruby developers from the issue.

## Problem

Imagine you have a `User` model and it is related to an `Account` with "many to many" relation. Both `User` and `Account` belong to a `Company` and it's impossible to attach a *user* from a *company #1* to an *account* from *company #2*. In general this is the obvious business rule and usually developers don't have a validation or a restriction for the rule in a persistence layer of an application. Mostly the rule is implemented in a business layer (this is a controller's layer in [MVC](http://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller) frameworks).

This is the UML diagram of the tables:

![Account and User relation](/images/account-users.jpeg)

Using `Rails`' `ActiveRecord` we would specify the following classes and relations:

{% highlight ruby %}
class Company < ActiveRecord::Base
  has_many :users
  has_many :accounts
end

class User < ActiveRecord::Base
  has_many :account_users
  has_many :accounts, through: :account_users
  belongs_to :company
end

class Account < ActiveRecord::Base
  has_many :account_users
  has_many :users, through: :account_users
  belongs_to :company
end

class AccountUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :account
end
{% endhighlight %}

> NOTE: We won't discuss here why we don't use the Rails' `has_many_and_belongs_to` association. The topic worse its [own discussion](http://stackoverflow.com/questions/2780798/has-and-belongs-to-many-vs-has-many-through) and its up to you what to use. But the specified relations will allow to understand the problem.

Then using [FactoryGirl](https://github.com/thoughtbot/factory_girl) in the tests you will have the following obvious (at first glance) factories:

{% highlight ruby %}
FactoryGirl.define do
  factory :company do
  end
end

FactoryGirl.define do
  factory :user do
    company
  end
end

FactoryGirl.define do
  factory :account do
    company
  end
end

FactoryGirl.define do
  factory :account_user do
    account
    user
  end
end
{% endhighlight %}


Now we are on the last step to realize the problem. Let's go to rails console in test environment and try to create an *account-user* model with the specified `FactoryGirl`'s factory:

{% highlight ruby %}
$ rails c test
irb(main):001:0> account_user = FactoryGirl.create(:account_user)
=> #<AccountUser id: 1, account_id: 1, user_id: 1>
irb(main):002:0> account_user.user.company
=> #<Company id: 2>
irb(main):003:0> account_user.account.company
=> #<Company id: 1>
{% endhighlight %}

Look at the result of the second and third commands - they return *company #1* and *company #2* respectively and this is the issue. Remember that we have the business rule that the situation is not possible. In a layer above (may be in controllers, form objects, policy objects or elsewhere) we may have the validation and the application is ready to use in production or development mode. But when we run tests we have the inconsistency and this may cause a lot of problems in your tests starting from performance issues and ending with unexpected behavior, which is difficult to debug to identify the problem.

If you still don't get the problem this is a clue which may show that you do things in a wrong way - in tests you can have the following stepped preparation of the environment:

{% highlight ruby %}
company = create(:company)
user = create(:user, company: company)
account = create(:account, company: company)
account_user = create(:account_user, user: user, account: account)
{% endhighlight %}

And this combination gives us a valid relation *account user* finally. Note, to create the valid relation we have four lines of code instead of simple one: `create(:account_user)`. Imagine that you have a lot of such relations in a database and you should understand the nightmare.

## Solution

Hopefully `FactoryGirl` has [much useful functionality](https://github.com/thoughtbot/factory_girl/blob/master/GETTING_STARTED.md) and one of them solves the problem very easily. This is the `ignore` method (from 29 April of 2014 it is [renamed](https://github.com/thoughtbot/factory_girl/commit/9610b389572913da0b01de519f3437cdeb764a59#diff-d41d8cd98f00b204e9800998ecf8427e) to `transient` and as I understand the new release will make you to use the new name). The method allows us to define *virtual* attributes on a factory. After this we will be able to pass additional options constructing a model with the `create` (or `build`) method of `FactoryGirl`.

> This is the simplified explanation a purpose of the method and it explains only my vision to the method. If you are not happy with the explanation or want to know more, please, read full documentation of this [here](https://github.com/thoughtbot/factory_girl/blob/master/GETTING_STARTED.md#transient-attributes).

Secondly we have to know that `FactoryGirl` has [lazy](https://github.com/thoughtbot/factory_girl/blob/master/GETTING_STARTED.md#lazy-attributes) (in other words dynamic) attributes syntax. Pass a block to an attribute when you declare a factory and it will be evaluated on constructing a model each time and set the result to the attribute. The next code snippet will show syntax of the idea and you will understand what's just explained.

Here we are and this is the improved factory:

{% highlight ruby %}
FactoryGirl.define do
  factory :account_user do
    ignore do
      company { create(:company) }
    end

    account { create(:account, company: company) }
    user { create(:user, company: company) }
  end
end
{% endhighlight %}

Now test the factory:

{% highlight ruby %}
$ rails c test
irb(main):001:0> account_user = FactoryGirl.create(:account_user)
=> #<AccountUser id: 1, account_id: 1, user_id: 1>
irb(main):002:0> account_user.user.company
=> #<Company id: 1>
irb(main):003:0> account_user.account.company
=> #<Company id: 1>
{% endhighlight %}

Bingo! We've solved the issue with the few lines of code. Now our factories give us possibility to refactor the tests, they don't create trash in the environment and the data is **integral**!

As a bonus we can even pass a custom *company* to the factory constructor and it will create for us a *user* in the company, an *account* in the company and the *account user* relation:

{% highlight ruby %}
irb(main):001:0> company = FactoryGirl.create(:company)
=> #<Company id: 1>
irb(main):002:0> account_user = FactoryGirl.create(:account_user, company: company)
=> #<AccountUser id: 1, account_id: 1, user_id: 1>
irb(main):003:0> account_user.user
=> #<User id: 1, company_id: 1>
irb(main):004:0> account_user.account
{% endhighlight %}

Awesome, isn't it?

## Conclusion

I know that somebody will say that these are obvious things but I'm sure that many Rails developers still have such issues in their projects. That's why I decided to write the article to warn them.

`FactoryGirl` is powerful software which gives us cool features to use in web development using `Ruby` language. But you  should use it with a caution to identify issues, like you saw in this post and solve them in time. It will prevent you from a nightmare and, may be, will make you a happy Ruby developer. I don't promise that you will be a happy Ruby developer after this, but at least your developing process should bring you more satisfaction.

Now you are armed with a tool which prevents you from the pitfalls which we have in our project. I wish you to not stuck into the issue.
