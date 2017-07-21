---
layout: post
title: "Travel in time during testing a Rails application"
modified: 2017-07-22 00:41:06 +0300
description: "There will be explained how to test a Rails application when the current time change is needed every time. In other words how to travel in time and not corrupt your operating system."
tags: [rails, time travel, testing]
comments: true
share: true
---

During testing an application, written with Rails, it's often needed to check that some event has to be occurred in the future after performing some actions. For example, when a user signs up on "22 July 2017" he gets a bonus. In order to test this manually, the current time has to be set to "22 July 2017". At first glance, it looks like a pretty trivial task. Just open system settings, disable synchronization with the servers that provide current time and change the local current time for the operating system. This will work and there is no surprise here. But problems come later when the current time is not returned back to the real current time. This is the list of possible problems: messages in chats are messed up, secured sites can't be opened because of the complaints about HTTPS issues, a commit can be created with wrong timestamps and the version control system's history is cluttered and so on and so forth. So if these problems look familiar for you, welcome aboard and enjoy the thoughts flow!

## Excursus

I too often need to test a Rails application that has to be done at some particular time, mostly in the future. And I always have been doing that by changing operating system time that leaded to the problems described above. On some day it just annoyed me a lot and I started to think about solutions that won't change operating system time but will allow to emulate current time. Inspired by the feature on linux based machines that allows to spoof a time zone by setting `TZ` environment variable, I started to think in this direction. But unfortunately I couldn't manage to find some opportunity to spoof current time with on the system level. And I finally invented my own solution based on a Ruby gem. I did this using [Timecop](https://github.com/travisjeffery/timecop). But you can use any other gem whenever you like. In this post I just describe the general idea. So **never change your operating system time manually** due to the issues described above and keep reading!


## The solution

Before showing the main idea behind the solution I would like to share some hack that will be handy not only in this particular case but in other circumstances too.

Sometimes there is a need to change code in a Rails application locally, but these changes must not be deployed to production server or committed to a version control system. For example, I want to set an alias locally to some namespace, because it's too long and I don't want to type a lot during debugging or investigating something in rails console. I.e. I want to do `GW = ActiveMerchant::Billing::TrustCommerceGateway`. It would be great to not set this alias every time manually right after opening rails console. A possible solution could be just defining a custom initializer (I hope that's not news for you what is that and it's known that initializers are located in the `config/initializers/` folder of a Rails application, more about Rails initializers [here](http://guides.rubyonrails.org/configuring.html)). But it will be automatically tracked by a version control system. And this is not a problem - those can be configured to be ignored. E.g. for Git this file's path can be put in the `.gitignore` and that's it.

I would recommend to define one such initializer, that will be general for all of your aliases, local monkey-patches and so on. By the way, check out one of very useful monkey-patch you will love:

```ruby
class BigDecimal
 def inspect
   to_s('F')
 end
end

```


And now when you fetch an ActiveRecord instance from DB in the Rails console instead of unreadable things you will see human-readable float numbers for `BigDecimal`'s. E.g. before that was `#<BigDecimal:7fb8301a25a8,'0.5005E3',18(18)>`, after - `500.50`.


Enough introduction and excursuses, here the solution of the current time changes problem:

```ruby
class TravelTime
  def self.take
    File.read(ENV['TRAVEL_TIME']).chomp
  end
end

class TravelTimeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    Timecop.travel(TravelTime.take) do
      @app.call(env)
    end
  end
end

module MyApplication # Name of your application, find it in the config/application.rb
  class Application
    if ENV['TRAVEL_TIME']
      require 'timecop'

      config.middleware.use TravelTimeMiddleware

      Timecop.travel(TravelTime.take) # For Rake tasks, console and other similar processes

      class Delayed::Worker
        alias origin_run run

        def run(job)
          Timecop.travel(TravelTime.take) do
            origin_run(job)
          end
        end
      end
    end
  end
end

```
