---
layout: post
title: "Define enums in your Rails app with confidence"
modified: 2020-02-16 00:41:06 +0300
description: "The post provides a DSL that allows enums definition that are constants."
tags: [ruby, enums, DSL]
comments: true
share: true
---

Many Rails projects have a "constant" list of some predefined things, such as user roles, food categories, types of properties, etc. These things are usually called "enums".
In the beginning people, prefer some easy implementation for that. For example, someone can use symbols, like `:admin` or `:leader` all over the application code.
And that's perfectly fine... Until the time comes for changes. The business decides to rename `:admin` to `:superadmin`.
This time the implementation may seem not so straightforward.
The problem is that it's not enough just to rename `:admin` to `:superadmin` in all places.
`:admin` may be used in different contexts and might mean not a user role at all.
It might be something else, i.e. scope of a controller, or model, or ... you get the point, right?

If someone goes forward and does the rename, the whole application should be tested manually.
I don't think, there is someone in the world who would be happy doing that.

What to do then?

I suggest to define constants for these things and keep them in their namespaces.
Check out the following Ruby snippet, that's the constant definitions for enums:


```ruby
module HasEnumConstants
  class ConstantsBuilder
    def initialize(namespace, const)
      @namespace = namespace
      @collection = @namespace.const_get(const)
    end

    def constant(name)
      val = name.to_s.downcase
      @collection.push(val)
      @namespace.const_set(name, val)
    end
  end

  # Introduces DSL for constants definition.
  # The all defined contants are put into the `collection` constant.
  #
  # Usage example:
  #   class User < ApplicationRecord
  #     constants_group :KINDS do
  #       constant :ADMIN
  #       constant :GUEST
  #     end
  #   end
  #   User::KINDS # => ['admin', 'guest']
  #   User::ADMIN # => 'admin'
  #   User::GUEST # => 'guest'
  def constants_group(collection, &block)
    const_set(collection, [])
    ConstantsBuilder.new(self, collection).instance_eval(&block)
    const_get(collection).freeze
  end
end

class ApplicationRecord
  extend HasEnumConstants
end
```

The code is put into `ApplicationRecord` so that all models now can use the DSL described in the comments above.
If apply this practice, all the code refers to `:admin` should refer to constant `User::ADMIN`, and that name is
pretty unique as you see and the chance this thing may mean something else is minimized.

Actually, the code can be shared with the other layers of Rails application, i.e. controllers, services, mailers, etc.

As practice shows it's better to follow this practice as sooner as better.
