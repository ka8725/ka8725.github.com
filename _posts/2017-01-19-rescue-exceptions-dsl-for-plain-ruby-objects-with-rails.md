---
layout: post
title: "Rescue exceptions DSL for plain Ruby objects with Rails"
description: "A solution to consume rescue_from DSL in a Rails application.
              Likewise in Rails controllers we have a useful functionality to
              catch exceptions with rescue_from in order to change the default
              behavior, it's too easy to obtain it for any other type of a Ruby object in Rails applications."
modified: 2017-01-19 22:53:20 +0100
tags: [rails, rescue_from, exceptions, DSL]
comments: true
share: true
---

At some point, you can start to think about how it would be great to have in your pure Ruby objects
of your Rails application the same DSL as Rails' controllers have to rescue exceptions coming from
actions with the `rescue_from` help. If you are interested in this topic then keep reading and I will
show how it's easy to implement it from scratch.

**TL;DR:** use [ActiveSupport::Rescuable](http://api.rubyonrails.org/v5.0/classes/ActiveSupport/Rescuable/ClassMethods.html).

## Introduction

It's not a secret to everyone that it's too easy to catch all targeted exceptions raised in any Rails controller. Just use `rescue_from` in a base controller like this:

```ruby
class ApplicationController < ActionController::Base
  rescue_from CanCan::AccessDenied do
    redirect_to root_path, alert: "You don't have access to this page."
  end
end
```

And that's it. Whenever the `CanCan::AccessDenied` is raised in some action of inherited controllers from the `ApplicationController` the Ruby interpreter jumps into this block, defined with the `rescue_from` and then it's executed. As a result, a user will be redirected to the main page with an alert and the original exception is suppressed. There are different ways how to use the `rescue_from` method, but this post is not about this, so you can find all variations [here](http://api.rubyonrails.org/v5.0/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from).

The main idea of this article is to show you how to add such functionality into some other type of objects of your Rails application. Say, you have a bunch of service objects that reside at the same hierarchy branch.
And you want to catch some general exception in the base class of these service objects easily and, you think,
that it would be good to have this functionality in the descendants.


## Extend custom objects with Rescuable

Actually, it's not a problem at all. All you have to do is just to include the `ActiveSupport::Rescuable`
module into a base class and wrap the method responsible for the execution of some work that could raise an exception which you would like to catch later with the `rescue_from`.

To not be wordy I will just provide the following code snippet which demonstrates the main idea:

```ruby
class BaseService
  include ActiveSupport::Rescuable

  class FieldIsNilError < StandardError; end

  rescue_from FieldIsNilError do |exception|
    puts "Field is empty: #{exception.class} - #{exception.message}"
  end

  def call
    call_with_rescue { useful_yield }
  end

  private

  def call_with_rescue
    yield
  rescue => e
    rescue_with_handler(e) || raise(e)
  end

  def useful_yield
    fail NotImplementedError
  end
end

class LoginUserService < BaseService
  class InvalidEmailError < StandardError; end
  class EmptyEmailError < StandardError; end
  class SecurityError < StandardError; end

  rescue_from InvalidEmailError, EmptyEmailError do |exception|
    puts "Logged invalid login attempt: #{exception.class} - #{exception.message}"
  end

  def initialize(email: nil)
    @email = email
  end

  private

  def useful_yield
    case @email
    when 'invalid'
      fail InvalidEmailError, 'email is invalid'
    when ''
      fail EmptyEmailError, 'email is empty'
    when 'kill -9'
      fail SecurityError, 'throw out'
    when nil
      fail FieldIsNilError, 'email is nil'
    else
      puts 'login ok'
    end
  end
end

LoginUserService.new(email: 'invalid').call
# => Logged invalid login attempt: LoginUserService::InvalidEmailError - email is invalid
LoginUserService.new(email: '').call
# => Logged invalid login attempt: LoginUserService::EmptyEmailError - email is empty
LoginUserService.new(email: 'ok@email.com').call
# => login ok
LoginUserService.new(email: nil).call
# => Field is empty: BaseService::FieldIsNilError - email is nil
LoginUserService.new(email: 'kill -9').call
# => throw out (LoginUserService::SecurityError)
```

The main trick here is in the `include ActiveSupport::Rescuable`. It provides us with the `rescue_from`
method, defined on the class level. And also it adds the `rescue_with_handler` method which tries to find a handler for a raised exception and call this handler if it's found. The handler is defined with the `rescue_from` in a service object - it's just a block. We use this in the `call_with_rescue` method, which wraps that method that does a real job and can raise an exception at some point (this is the `useful_yield` method).
And this exception can be caught with the `rescue_from` and some useful work can be done suppressing the error. Or it will be raised up and an end user will observe it in case if we don't have a defined rescue handler for
this exception.

Now let's experiment with this code. Just place the code above in a `test.rb` file located in a Rails application and execute it with the [rails runner](http://guides.rubyonrails.org/command_line.html#rails-runner) using following command: `rails runner test.rb`. You will have an output similar to this one:

```
Logged invalid login attempt: LoginUserService::InvalidEmailError - email is invalid
Logged invalid login attempt: LoginUserService::EmptyEmailError - email is empty
login ok
Field is empty: BaseService::FieldIsNilError - email is nil
test.rb:49:in `useful_yield': throw out (LoginUserService::SecurityError)
```

If you feel uncomfortable at this point you can change this code and rerun it with the rails runner, it's rather easy, as you see. Or just comment on this post. I would be glad to hear your response and questions.


## Conclusion

Try to understand how interesting things are implemented, that you would like to have in your code, and consume
the implementation. But note, that sometimes it's easier to implement some things yourself
from scratch, there are may be many reasons for this: code quality, lack of functionality that can't be
extended easily and so on. Every case should be analyzed and a correct decision should be taken. But it's not
about this case. The `ActiveSupport::Rescuable` does its work and does it gracefully.
