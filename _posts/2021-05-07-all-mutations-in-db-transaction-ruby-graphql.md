---
redirect_to:
  - https://blog.widefix.com/all-mutations-in-db-transaction-ruby-graphql
layout: post
title: "Easy solution to run all mutations in DB transactions"
modified: 2021-05-17 00:41:06 +0300
description: "Learn an easy solution to wrap all mutations in DB transactions using the graphql-ruby gem."
tags: [ruby, graphql]
comments: true
share: true
---

The [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) is a cool gem that allows a server definition for GraphQL on Ruby.
It provides a ton of useful functionalities out of the box. So, you won't find them in the [official docs](https://graphql-ruby.org/).

This post reveals one of the features that's so useful that worth being in the docs.

Consider a Rails application that defines a GraphQL server using the [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) gem.
The app has a base mutation for all:

```ruby
class BaseMutation < GraphQL::Schema::Mutation
end
```

The rest mutations are inherited from it:

```ruby
class SomeMutation < BaseMutation
  # fields definition

  def resolve(**params)
    SomeModel1.create!(**params[:name])
    SomeModel2.create!(**params[:email])
  end
end
```

Also, as you may guess, the app has many mutations, not just this one.
Potentially, any of these mutations might have several DB writes (an `update`/`delete`/`insert` SQL statement) as in the `SomeMutation` above.
To guarantee the mutation [atomicity](https://en.wikipedia.org/wiki/Atomicity_(database_systems)) (all DB inserts occur or none, if any of them is unsuccessful)
the both `create!` operations should be wrapped into a DB transaction:

```ruby
class SomeMutation < BaseMutation
  # fields definition

  def resolve(**params)
    ApplicationRecord.transaction do
      SomeModel1.create!(**params[:name])
      SomeModel2.create!(**params[:email])
    end
  end
end
```

Besides that, any new mutation might require this wrapper as well. But as it's created by humans that thing might be easily missed.
That's why we want the transaction open implicitly for all mutations.
Also, we don't want to change all mutations that have defined the `#resolve` method as above and have missed an open transaction.
Rewriting all mutations would be a monkey business, and it's too risky.

In cases like this one we jump into the gem internals and see what's defined in the base.
We need to figure out how these `#resolve` methods are called and try to extend the functionality so that we achieve the desired behavior.
It's not hard to find the searching code on [GitHub](https://github.com/rmosolgo/graphql-ruby/blob/bace1e4027900fc8779a5c2fd393ff6456046cea/lib/graphql/schema/resolver.rb#L65-L119).

Specifically, these lines we are interested in:

```ruby
# Finally, all the hooks have passed, so resolve it
if loaded_args.any?
  public_send(self.class.resolve_method, **loaded_args)
else
  public_send(self.class.resolve_method)
end
```

Aha! It turns out that in the end, it calls a method name that's dynamic, it's defined in the `self.class.resolve_method`.
By default, as expected it's set to `:resolve`, it's easy to check in a Rails console:

```ruby
> BaseMutation.resolve_method
=> :resolve
```

Somewhere close to this code we can find out that this value can be changed, see the [related code](https://github.com/rmosolgo/graphql-ruby/blob/bace1e4027900fc8779a5c2fd393ff6456046cea/lib/graphql/schema/resolver.rb#L204-L209):

```ruby
# Default `:resolve` set below.
# @return [Symbol] The method to call on instances of this object to resolve the field
def resolve_method(new_method = nil)
  if new_method
    @resolve_method = new_method
  end
  @resolve_method || (superclass.respond_to?(:resolve_method) ? superclass.resolve_method : :resolve)
end
```

That means we can define our own "resolve" method that will be called by the gem internals instead of the default `#resolve` one.

Using that knowledge, it's easy to see that we've got a solution with all needs:
- define a custom resolver in the `BaseMutation`
- it will be a wrapper for the already defined `#resolve` methods in all mutations
- it will call these already defined `#resolve` methods inside an opened DB transaction.

That's all what we need:

```ruby
class BaseMutation < GraphQL::Schema::Mutation
  resolve_method :resolve_in_transaction

  def resolve_in_transaction(*args)
    ActiveRecord::Base.transaction do
      resolve(*args)
    end
  end
end
```


Ta-da! That's all that should be done. A few lines of code and we've solved a complex problem.


## Conclusion

See how it's important to have code organized, that has the same API (set of public methods) and behavior.
Changing just a base code with just a few lines of code we easily change the whole family of classes!
