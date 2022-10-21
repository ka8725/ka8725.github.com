---
redirect_to:
  - https://blog.widefix.com/stub-active-record-associations
layout: post
title: "Stub Rails ActiveRecord associations in your tests"
modified: 2018-11-27 00:41:06 +0300
description: "Explains a technique that allows stubbing ActiveRecord associations easily so that your tests are getting faster."
tags: [rails, active_record, rspec]
comments: true
share: true
---

Have you ever struggled with slow tests in your Rails application? Do you know why your tests were slow? Well, it may seem not obvious, but most of the time tests spend on interacting with a database. We don't prove this fact here because it's quite [known one](https://evilmartians.com/chronicles/testprof-a-good-doctor-for-slow-ruby-tests), but we discuss a possible solution that might be helpful in some circumstances.

### Problem

Given a Rails app uses RSpec for tests and some Factory (FactoryBot for example) to create models in tests. The tests where models created with factory are slow. We want to make them faster.

### Solution

There are some bits of advice on how to speed up tests and they are clearly defined in this [article](https://evilmartians.com/chronicles/testprof-a-good-doctor-for-slow-ruby-tests). They are very helpful and, I must admit, they work well. But what if we want to gain more speed from our tests for whatever reason? As it's already said, tests are slow because of interaction with a database. So what can we do then? It's quite obvious - stub the code calls DB and call it a day. The only problem is that our app talks to DB for two reasons: to save data and to read data. And these are completely different problems that each require a specific approach. In this article, we discuss only the "read" situation. The "write" situation is left for the reader thoughts.

We already know they are slow because of touching DB. But which code exactly causes the issue? Let's think first why we need real models created when we test a decorator. You may argue, but as I see, most of the time we need persisting models there to satisfy some select from DB, that's actually **scopes** or **associations** in the Rails models layer. So, why not to stub these things?

Ok, we figured out that we need to stub associations and scopes in a test for a decorator. But how to do this exactly? Suppose, there is a code somewhere in deep of our models that's called by our decorator: we test `SubscriptionDecorator.new(subscription).active_users` that actually turns into call `subscription.users.active.verified` underneath. A stub like this `allow(subscription).to receive(users).and_return([User.new])` won't work, because there are no defined `active` or `verified` methods on it. So, looks like we need to stub it wisely. And here is what I suggest. Let's create a clone of `ActiveRecord::Relation` that copies an association behavior:

```ruby
class ActiveRecordRelationStub
  attr_reader :records
  alias to_a records

  # @param model_klass [ActiveRecord::Base] the stubbing association's class
  # @param records [Array] list of records the association holds
  # @param scopes [Array] list of stubbed scopes
  def initialize(model_klass, records, scopes: [])
    @records = records

    scopes.each do |scope|
      fail NotImplementedError, scope unless model_klass.respond_to?(scope)
      define_singleton_method(scope) do
        self
      end
    end
  end
end

```

Having this in place, we can stub our association and scope:

```ruby
user1 = build_stubbed(:user)
user2 = build_stubbed(:user)
allow(subscription).to receive(:users).and_return(ActiveRecordRelationStub.new(User, [user1, user2], scopes: [:active, :verified]))
```

In order to demonstrate how it works, for the sake of simplicity let's have our `SubscriptionDecorator` class defined in the following way:

```ruby
class SubscriptionDecorator
  # ... details are hidden here
  def active_users
    subscription.users.active.verified
  end
end
```

And now when the call `SubscriptionDecorator#active_users` in tests with `SubscriptionDecorator.new(subscription).active_users` returns the stubbed relation with the records provided exactly like real models would behave. But keep in mind, here we don't care about internal details of how the scopes (`verified` or `active`) are defined, what filters they use and so on. The real behavior of the scopes should be tested in the models on which they are defined. In other words, on decorators layer we rely on the scopes implementation and assume they work correctly and tested well, so that we can safely stub them. Please note, to prevent the mistake with stubbing an association that's not defined, it's better to use [verifying partial doubles](https://relishapp.com/rspec/rspec-mocks/docs/verifying-doubles/partial-doubles). If use it properly, RSpec checks whether the stubbed method is really defined or not, and if it's not an exception is raised. So you are informed about this typo or mistake and can fix it not waiting for an error happened in production because you relied on tests that were weak. I highly recommend you to turn this option on globally for your tests to be on the safe side.


### Conclusion

I used the technique described in this article once and it was pretty successful. I managed to make our tests much faster. And of course, this approach can be used not only in tests for decorators, but for view specs, controllers specs and in any place when you don't really need to check whether DB works properly but rather want to check **your** code. But this is not the whole story. There should be also defined aggregate functions, some filter methods and so on. If this approach works for you as well, I offer to comment on what functionality lacks [here](https://gist.github.com/ka8725/de9e6a87d83a0f58ad3e3ba20ebaf3ae).

### PS

If you have some questions left after reading this article, like "Why should I care about tests speed?" or "What other possible options exist?" please read [this article](https://evilmartians.com/chronicles/testprof-a-good-doctor-for-slow-ruby-tests) and especially the docs for [TestProf](https://test-prof.evilmartians.io).
