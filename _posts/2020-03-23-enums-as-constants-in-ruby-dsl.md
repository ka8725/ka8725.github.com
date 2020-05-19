---
layout: post
title: "Enums as constants in Ruby DSL"
modified: 2020-03-23 00:41:06 +0300
description: "The post provides a DSL allows enums definition as constants."
tags: [ruby, enums, DSL]
featured_post: false
comments: true
share: true
---

Many Rails projects have a "constant" list of some predefined things, such as user roles, food categories, types of apartments, etc. These things are usually called "enums".
In the beginning, people prefer some easy implementation for that. For example, someone can use symbols, like `:admin` or `:leader` all over the application code.
And that's perfectly fine... until the time comes for changes. The business decides to rename `:admin` to `:superadmin`.
On try applying this change in the code the initial implementation might seem not so straightforward.
And the problem is that it's not enough just to rename `:admin` to `:superadmin` in all places.
`:admin` can be used in different contexts and might mean not a user role at all.
It might be something else, i.e. scope of a controller, or model, or ... you get the point, right?

If someone goes forward and does the rename, the whole application should be tested manually.
I don't think, there is someone in the world would be happy doing that, don't you?

What to do then?

I suggest to define constants for these things called "enums" and keep them in their namespaces.
Check out the following Ruby snippet:


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
  #   class User
  #     extend HasEnumConstants
  #
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
```

If consume it by `ApplicationRecord` like below all models obtain the DSL that allows enums definition as constants:

```ruby
class ApplicationRecord
  extend HasEnumConstants
end
```

For example, the former `:admin` key could be defined on `User` model like this:

```ruby
class User < ApplicationRecord
  constants_group :KINDS do
    constant :ADMIN
    constant :GUEST
  end
end
```

Feel how it works:

```ruby
> User::KINDS # => ['admin', 'guest']
> User::ADMIN # => 'admin'
> User::GUEST # => 'guest'
```

If apply this practice, all the code refers to `:admin` should refer to constant `User::ADMIN`. Now that name is
pretty unique as you see (because it's scoped by `User`). The chance this thing may mean something else is minimized.

Consider there is a misspelling in the code, i.e. `User::AMDIN` instead of `User::ADMIN`.
If the code has good coverage, the code will fail immediately during the unit tests run with an adequate exception.
Having that exception it's very easy to understand what's the problem.
And this is why it's better than the built-in ActiveRecord enums. ActiveRecord enums are weaker in terms of strong types and preventing mistakes during the development process.
Basically, it's not much better than having just a bunch of not related symbols,
like in the example of this post beginning.

As one might notice, the module can be used by the other layers of a pure Ruby or Rails application, i.e. controllers, services, mailers, etc.

As practice shows, if it comes to release in production and maintenance it's better to follow a practice like that as sooner as better.
