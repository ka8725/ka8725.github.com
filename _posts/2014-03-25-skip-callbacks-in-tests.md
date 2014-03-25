---
layout: post
title: "Skip callbacks in tests"
description: "Simple solution to skip callbacks in tests if they should not be run there. The solution is for Rails ActiveRecord."
tags: [rails, callbacks]
---
{% include JB/setup %}

There are a lot of troubles around callbacks in Rails's ActiveRecord. In common people use callbacks to process complicated operations such as sending emails, creating related models and etc. Basically all of them should be prevented from execution in tests because of slowing down speed and increasing time execution of the tests. It's not a secret that there are best practices to avoid the problem, but in some cases it's almost impossible to apply them on your project.
This post shares idea about how to prevent the callbacks execution if you are in the same situation.


## Problem

Consider the most frequent use case. We have a `User` model and we want to send an email on its creation. With callbacks we could have the code like this:

{% highlight ruby %}
class User < ActiveRecord::Base
  after_create :send_greating_email

  private

  def send_greating_email
    NotificationSystem.send_email(:greeting, user)
  end
end
{% endhighlight %}

Here we have one `after_create` callback `:send_greeting_email` which will be called after user creation. The callback should send real email to the user.

> Note: We are not provided here with the `NotificationSystem` class because it is not required to understand the problem.

For the first glance there is no problem with this code. But when you start to test it you may have a problem. The problem is that the callback should not be run in all tests except one place where we want to test only the callback. How to do it?

One of possible solution may be to just stub the `send_greeting_email` in all tests and *unstub* it where its call is really needed. Of course this solution will work but it requires some monkey business because you have to place the stubbing code in all test files of your project. This is possible `RSpec` code to do it:

{% highlight ruby %}
describe User do
  before(:all) do
    User.any_instance.stub(:send_greeting_email)
  end

  context "tests which don't require sending greeting email" do
    # Common tests are here
    # ...
  end

  context 'testing sending greeting email' do
    before(:all) do
      User.any_instance.unbstub(:send_greeting_email)
    end

    # Test sending greeting email
  end
end
{% endhighlight %}

And the code in `before(:all)` blocks we should include in all tests where we have some manipulations with a `user` object. It's not convenient solution at all and moreover is not robust, because, if you change the callback name, you will have to fix a number of tests. Finally, remember, that we have to test class's interface but not its internals, but here, stubbing the callback method, we violate the rule.

Another solution may be using [rails observers](https://github.com/rails/rails-observers). Having observers you may disable them in tests as default and enable in desired places. Simple speaking this solution works on some straightforward projects. But the observers bring to problems in debugging process on complicated projects where you have models inheritance, many observers per model and so on. So, this solution is not our case either, because, as you've already guessed, we have a complicated project.

So this solution won't work for us.

## Trending solutions

The most popular solution is to don't trap in this problem at all. You may use best practices like [service objects](http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/) or [form objects](http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/). It will allow you to write callbacks' logic separately from the model. With this approach we won't have defined callbacks in models at all. Also service or form objects can be tested easily in isolation.

But despite of the fact that this solution doesn't have minuses there are cases where the appliance may be too expensive. For example, if you already have a big project with a lot of objects and controllers. In this case we will have to write a number of service of form objects and change code in almost all controllers. It is a huge piece of work.

## Solution with skipping callbacks

Reasonable solution here can be just turn off all callbacks in tests and turn on them in particular places. We can do it with implementing a switcher in all models and add a condition for all callbacks. The condition will check for the switcher's status and will pass callbacks if it's allowed and will deny them if it's prohibited.

Let's implement it. Firstly, add switcher to the models with this monkey patch:

{% highlight ruby %}
class ActiveRecord::Base
  cattr_accessor :skip_callbacks
end
{% endhighlight %}

> Note: the most suitable place for this code in a Rails project is the `config/initializers` folder. If you place the code in `config/initializers/active_record.rb`, for example, it will run on each application start.

On the next step add the condition to the controlled callbacks. Check out how to do it on the `User` model:

{% highlight ruby %}
class User < ActiveRecord::Base
  after_create :send_greating_email, unless: :skip_callbacks

  private

  def send_greating_email
    NotificationSystem.send_email(:greeting, user)
  end
end
{% endhighlight %}

That's all. Now we can turn on callbacks and turn off them where we need it:

{% highlight ruby %}
ActiveRecord::Base.skip_callbacks = true
User.create # callbacks won't be run
ActiveRecord::Base.skip_callbacks = false
User.create # callbacks will be run
{% endhighlight %}

> You can find the ready to use example [here](https://gist.github.com/ka8725/9767340) and run it with the command `ruby <exmaple>.rb`. To run the code you should have installed *Rails* any version.

With this approach you even may write simple switcher for the tests. Place this code to the `spec/spec_helper.rb`:

{% highlight ruby %}
RSpec.configure do |config|
  config.before(:all, callbacks: true) do
    ActiveRecord::Base.skip_callbacks = false
  end

  config.after(:all, callbacks: true) do
    ActiveRecord::Base.skip_callbacks = true
  end
end


ActiveRecord::Base.skip_callbacks = true
{% endhighlight %}

Now you are able to write context or tests with enabled/disabled callbacks in your tests:

{% highlight ruby %}
describe User do
  # As default callbacks are turned off, so we don't have to switch off them explicitly
  context "tests which don't require sending greeting email" do
    # Common tests are here
    # ...
  end

  # These tests should run callbacks - add "callbacks" option with the "true" value
  context 'testing sending greeting email', callbacks: true do
    # Test sending greeting email
  end
end
{% endhighlight %}

If you want you may even turn on/off callbacks for particular model:

{% highlight ruby %}
User.skip_callbacks = true
User.create
# Callbacks are run
User.skip_callbacks = false
User.create
# Callbacks are not run
{% endhighlight %}

## Conclusion

If you start a new Rails project think over and avoid using callbacks. Use service objects or form objects instead callbacks. But if your project already started and it has a lot of models the skipping callbacks solution may save you.
