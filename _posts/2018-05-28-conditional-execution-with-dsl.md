---
layout: post
title: "Conditional execution with DSL in Ruby"
modified: 2018-05-28 00:41:06 +0300
description: "This is a howto describing an alternative solution for if-clause in Ruby."
tags: [ruby, dsl, if, clause, condition]
comments: true
share: true
---

I'm a fan of minimalistic and clear code. Recently, I've faced some repetitive code. I believe, that everyone should keep the code as DRY (don't repeat yourself) as possible. The code was like this: call to a third party API, check the response and do something if it's successful, do something else if it's not. A basic code, but the implementation is boring.

### Problem

To not be verbose and not repeat that I've already said, I just provide an example of the code:

```ruby
response = StripeCall.new(number: 'valid').call
if response.success?
  puts response.body
else
  puts response.body
end
```

Basically, there is no any issue with this code. But, I find it's not good enough, because there are too many details to be aware of:
- the two classes for which their public interface is has to be known (it's `StripeCall` and the class of `response` object);
- don't forget to check the response everywhere where it's used and use for this `if` clause;
- don't forget to instantiate the object of `StripeCall` class properly (pass `params` into `new`, but not into `call`).

There are may be other objections, but unfortunately I can't identify them for now. All in all, we are humans and everyone has their own feelings.

### Solution

From my practice, the bad feelings could be eliminated by introduction some sort of DSL. Start with imagination, but don't go too far away from Ruby syntax (otherwise there will be needed a new language implemented, but I don't want this today as I'm good with Ruby). Firstly, the problem with keeping in mind the details wether pass `params` into `new` or `call` can be rid of by defining `call` method on the class level. Then, knowing that `.call(params)` can be replaced with `.(params)`, the number of typed symbols is reduced. After this, knowledge from other languages comes into the action: in Javascript there is pretty syntax for processing similar cases like this - `.onSuccess(func1).onError(func2)`. I personally find it useful and handy. So, the final solution could be look something like this:


```ruby
StripeCall.(number: 'valid')
  .on_success { |response| puts response.body }
  .on_error { |response| puts response.body }
```

Let's implement it:

```ruby
# A base class for all classes implement calls to API.
class ApiCall
  attr_reader :params

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
  end

  def call
    @res = execute
    self
  end

  def on_success
    yield @res if @res.success
    self
  end

  def on_error
    yield @res unless @res.success
    self
  end

  private

  def execute
    fail NotImplementedError
  end
end
```

```ruby
# A concrete class implements call to API.
class StripeCall < ApiCall
  Response = Struct.new(:success, :body)

  private

  def execute
    success = params[:number] == 'valid'
    body = success ? 'ok response' : 'bad response'
    Response.new(success, body)
  end
end
```

Now the code is ready to be played with:

```ruby
StripeCall.(number: 'valid')
  .on_success { |response| puts response.body }
  .on_error { |response| puts response.body }
# => ok response

StripeCall.(number: 'invalid')
  .on_success { |response| puts response.body }
  .on_error { |response| puts response.body }
# => bad response
```


Actually, the definition of blocks everywhere can be annoying. Therefore, is simplified as well:

```ruby
def handle_success(response)
  puts response.body
end

def handle_error(response)
  puts response.body
end

StripeCall.(number: 'valid')
  .on_success(&method(:handle_success))
  .on_error(&method(:handle_error))
```

Now only 1 class intercase is needed to be memorized - it's `StripeCall`. The lines number is reduced from 6 to 3 (the implementation of conditional branches is not taken into account). But the main strength of such a DSL is that the implementation is hidden and there could be raised and caught exceptions along the way. By catching them and processing in the base class we reduce even more repetitive code.

For example, the call method of the base class could be implemented like this:

```ruby
class ApiCall
  ...
  def call
    @res = begin
             execute
           rescue StripeError => e
             OpenStruct.new(success: false)
           end
    self
  end
  ...
end
```

### Conclution

A big project usually has a lot of code (surprise!). Every new line of code increases coupling and introduces complications. It gets harder to maintain and test it, especially when the code doesn't follow [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) paradigm, in other words, it's repetitive. Keep your code clean and don't hesitate to introduce your DSL to solve YOUR issues. And this way the code will be readable and close to the business domain, what is dreamed by every developer. Happy coding!

