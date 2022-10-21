---
redirect_to:
  - https://blog.widefix.com/safe-enums-in-ruby
layout: post
title: "Safe enums in Ruby"
description: "Safe enums implementation in Ruby. Why and what for? Read this post about the
              mezuka/enum gem."
modified: 2015-12-27 17:03:55 +0300
tags: [ruby, gem]
comments: true
share: true
---

For those people who came into Ruby from Java, C# and similar OOP languages, it may be very
surprising that Ruby doesn't have enums implementation out from box. Someone could argue that
there is `Symbol` type in Ruby and it will be enough using this instead. Well, it may be true for
a very small project but if you have a big one things go much harder.

**TL;DR:** use [this gem](https://github.com/mezuka/enum).

## What the heck?

Firstly let's try to understand what are *enums*, which issues they solve and what for they were
invented. I will quote [Wikipedia](https://en.wikipedia.org/wiki/Enumerated_type#Rationale) for this:

> *...* If a programmer wanted a variable, for example `myColor`, to have a value of `red`, the variable `red` would be declared and assigned **some arbitrary value**, usually an integer constant. The variable `red` would then be assigned to `myColor`*...*

> These arbitrary values were sometimes referred to as **magic numbers** since there often was no explanation as to how the numbers were obtained or whether their actual values were significant. These magic numbers could make the source code harder for others to understand and maintain.

> Enumerated types, on the other hand, made the code more self-documenting. Depending on the language, the compiler could automatically assign default values to the enumerators thereby hiding unnecessary detail from the programmer. These values may not even be visible to the programmer. Enumerated types can also prevent a programmer from writing illogical code such as performing mathematical operations on the values of the enumerators. If the value of a variable that was assigned an enumerator were to be printed, some programming languages could also print the name of the enumerator rather than its underlying numerical value. A further advantage is that enumerated types can allow compilers to enforce semantic correctness. For instance:
`myColor = TRIANGLE`
can be forbidden, whilst
`myColor = RED`
is accepted, even if `TRIANGLE` and `RED` are both internally represented as `1`.

> Conceptually, an enumerated type is similar to a list of nominals (numeric codes), since each possible value of the type is assigned a distinctive natural number. A given enumerated type is thus a concrete implementation of this notion. When order is meaningful and/or used for comparison, then an enumerated type becomes an ordinal type.

In brief currently we have implementations of enums in many programming languages (note that only **Python** from scripting family implements them and it's interestingly that starting only from one of latest versions - 3.4). Earlier people used integers for the purpose of enumeration of values and this approach had drawbacks. In programming the enum type basically solves the following issues:

- Unpredictable behavior;
- Maintenance;
- Code readability.

And this type has the following characteristics:

- It defines a set of identifiers (set of named values, called enumerators of the type or elements);
- The elements behave as constants;
- A variable that has been declared as having an enumerated type can be assigned any of elements.

Notably that neither existing Symbols nor other standard Ruby types cover all of the enum definition.

## The solution

In our project ([Mezuka](https://mezuka.com)) we have a lot of entities that should behave like enums. And we, actually, used one of the already implemented gem (to be honest I used many implementations of enums in Ruby in my projects before). But it wasn't fit to us and has excess functionality. During yet another refactoring we introduced our own library that solves the issues and completely fits us. And finally we released this [gem](https://github.com/mezuka/enum) which is called [safe-enum](https://rubygems.org/gems/safe-enum).

So, what the issues does it solve?:

- Serialization into DB - the value should be as written as read and represented in Ruby without any pitfalls;
- Safety - if there is not defined enum value I should have runtime error (ideally complication error, but, remember, in Ruby we don't have a compiler);
- Easy to define - simple DSL;
- It should be an ordinal type - we should be able to compare the enum values and sort them sometimes;
- It should be used in pure Ruby classes (not only with ActiveRecord or other ORM);
- Easy enum values internationalization (I18n) and their keys maintenance.

And these are architect decisions of the [gem](https://rubygems.org/gems/safe-enum) that allows to implement it as we wanted:

- As the enum value should be written into DB, due to the integer disadvantages and the fact that symbols (or atoms) are not supported by our DB (PostgreSQL) all the enum values are represented only and only as strings in the gem internals.
- The enums are saved into `Set` in order to quickly figure out if the value is valid and defined;
- The order of the values definition is saved and they have their integer representation for comparison (just their definition index for simplicity);
- Raise an **exception** if there is no defined enum value when there is an attempt to use it;
- Easy to use DSL for the enum values and the I18n keys definition.

I paste here a few examples of the gem usage:

{% highlight ruby %}
require 'enum'
require 'i18n'
require 'yaml'


# The enum values definition feature demo:
class Side < Enum::Base
  values :left, :right
end


# The safe enums retrieving feature demo:
Side.enum(:left) # => "left"
Side.enum('left') # => "left"
Side.enum(:invalid) # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side
Side.enum('invalid') # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side
Side.all # => ['left', 'rigth', 'whole']
Side.enums(:left, :right) # => ['left', 'right']


# The I18n feature demo:
I18n.enforce_available_locales = false

# This is the content of yaml file that holds the enum values translations:
translations = <<-YAML
enum:
  Side:
    left: 'Left'
    right: 'Right'
YAML

I18n.backend.store_translations(I18n.locale, YAML.load(translations))

Side.name(:left) # => "Left"
Side.name('left') # => "Left"
Side.name(:right) # => "Right"
Side.name('right') # => "Right"
Side.name(:invalid) # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side

# The enum values comparison feature demo:
class WeekDay < Enum::Base
  values :sunday, :monday, :tuesday, :wednesday, :thusday, :friday, :saturday
end
WeekDay.index(:sunday) == Date.new(2015, 9, 13).wday # => true
WeekDay.index(:monday) # => 1
WeekDay.indexes # => [0, 1, 2, 3, 4, 5, 6]
{% endhighlight %}

> Note: the I18n functionality is optional. So If you don't have installed I18n in your project NameError exception will be raised on the name method call.


As a bonus we introduced safe setters and convenient predicates in order to manipulate the enum values in a Ruby object:

{% highlight ruby %}
class Table
  extend Enum::Predicates

  attr_accessor :side

  enumerize :side, Side
end

@table = Table.new
@table.side_is?(:left) # => false
@table.side_is?(nil) # => false

@table.side = Side.enum(:left)
@table.side_is?(:left) # => true
@table.side_is?(:right) # => false
@table.side_is?(nil) # => false
@table.side_is?(:invalid) # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side

@table.side = 'invalid'
@table.side_is?(nil) # => false
@table.side_is?(:left) # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side
@table.side_any?(:left, :right) # => true
@table.side_any?(:right) # => false
@table.side_any?(:invalid, :left) # => Enum::TokenNotFoundError: token 'invalid'' not found in the enum Side
{% endhighlight %}

> If you pass to the predicate `nil` or have `nil` value in the field the result will be always `false`. If you want to check that the field is `nil` just use Ruby's standard method `nil?`.

## Alternatives

There are many other gems that tried to implement Ruby enums but as I already said no one of them suites us. And there are many reasons why. I won't review them in this post separately but, in two words, I can say here that all of them violates the rule - **enums should behave like constants**. Some of the implementations break other rules of the enum definition of have redundancy.

## Conclusion

In our gem we tried to follow the enum definition rules and having easy solution to use and maintain. I think we managed to do this. If you have any feedback please comment, post issues in [github](https://github.com/mezuka/enum/issues) and your pull requests are always welcome.
