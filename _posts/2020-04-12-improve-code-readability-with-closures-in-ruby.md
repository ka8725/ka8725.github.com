---
layout: post
title: "Improve code readability with closures in Ruby"
modified: 2020-04-12 00:41:06 +0300
description: "Reduce Ruby code complexity code with closures."
tags: [ruby]
comments: true
share: true
---

Code readability is a very critical parameter for any project maintainability.
Serious business needs reacting to failures and fixing bugs as soon as possible.
That allows not to lose old clients and make the service more attractive for new ones.

But how to improve readability? One might think that installing, configuring, and following automatic tools
 such as [Rubocop](https://github.com/rubocop-hq/rubocop) or [Reek](https://github.com/troessner/reek)
 is more than enough. Indeed, these tools are great. They are highly recommended and really help a lot.
 Unfortunately, they are not a silver bullet. They cannot eliminate one important factor - distance to natural language.
 As closer code to natural language as better its readability. This is the measure everyone should strive to.

Languages that support higher-order functions has
a nice concept called closures. Closures are just functions (anonymous or not) that are received by other functions as arguments.
The receiving functions can optionally call the passed closures whenever it's needed. An interesting fact is that closures are bounded to
the context from which they are passed. That allows interfering into executing of distant contexts.

> If that definition sounds cumbersome and scary, I recommend to look into [this](https://www.w3schools.com/js/js_function_closures.asp) introduction
by an example based on JavaScript.

Ruby has functions equivalent called methods. Even though Ruby doesn't allow having method names as arguments,
it's possible to implement closures.

Check out this example demonstrating that methods cannot be used as arguments:

```ruby
def foo
  puts 'hello from foo'
end

def bar(f)
  f()
end

bar(foo) # => NoMethodError (undefined method `f' for main:Object)
```

Ruby has [lambdas and procs](https://www.rubyguides.com/2016/02/ruby-procs-and-lambdas/) to implement the closures concept.

Moving further, a method is an object as [anything else](https://www.ruby-lang.org/en/about/).
That means it's possible getting an object that represents a method. Here is how to do that:

```ruby
method(:foo) # => #<Method: main.foo>
```

But the example above will still not work:

```ruby
bar(method(:foo)) # => NoMethodError (undefined method `f' for main:Object)
```

Execution of lambdas, procs, and `Method` objects with `()` is not possible.
They `#call` method for that. Applying a fix with that knowledge:

```ruby
def bar(f)
  f.call()
end
bar(method(:foo)) # => hello from foo
```

Ta-da! Finally, the closure works!

By the way, there is a shorthand for `f.call()`, that's `f.()`:

```ruby
def bar(f)
  f.()
end
bar(method(:foo)) # => hello from foo
```

It's rare in commercial development, but often used in popular open sourced projects.

Enough theory. Switching into real work. Assume, we need to write an application that sends text messages
to particular recipients. Look at the following code one might come up with implementing that idea:

```ruby
User = Struct.new(:phone, :active)

class SMSGateway
  # @param phone [String]
  # @param message [String]
  def self.send_message(phone, message)
    puts "Hello #{phone}, #{message}"
  end
end

class MessageService
  # @param message [String]
  # @param recipients [Array<User>]
  def broadcast(message, recipients)
    recipients.each do |recipient|
      SMSGateway.send_message(recipient.phone, message) if recipient.active
    end
  end
end

recipients = [
  User.new('+12222222222', true),
  User.new('+13333333333', false)
]
service = MessageService.new
service.broadcast('have a good day!', recipients)
```

Now, picture how humans read the code. I will speak from myself. In order to grasp the code idea fast,
I start from learning the application programming interface (API) first.
I don't start from nitty-gritty details. That works at least for me and I find this way to learn the code very useful.

So, I begin from these two lines:

```ruby
service = MessageService.new
service.broadcast('have a good day!', recipients)
```

I see the API immediately. The `MessageService#broadcast` method is our "entry point". At this point
it's already clear what it does intuitively. That's because the method has a good name.

> It's not always like that, unfortunately.
> Imagine, if someone named this method as `call` or `perform`, then its responsibility would not be so obvious.
> In practice, there are examples that are completely confusing and even worse than obscured `call/perform/whatever`.
> API and naming are very important! Feel that by this example.

Then I want to learn more details about `#broadcast` and jump into its implementation:

```ruby
def broadcast(message, recipients)
  recipients.each do |recipient|
    SMSGateway.send_message(recipient.phone, message) if recipient.active
  end
end
```

It's pretty straightforward, but nevertheless it already forces to stop my eyes for a while and think.
I need to keep at least 3 variables in my memory to understand this code. For this particular code, it's not a problem.
But in the real world a method like this is not a 3 lines of code, even though it lays on the very top of API.
It's usually a huge piece of ... (you know what I mean, right?)
Therefore, the question of its improvement is of paramount importance.

Here is my solution that makes it better using the theory above:

```ruby
class MessageService
  # @param message [String]
  # @param recipients [Array<User>]
  def broadcast(message, recipients)
    recipients.each(&send_message(message))
  end

  private

  # @param message [String]
  # @return [Proc] a closure sends the given message to the recipient
  def send_message(message)
    ->(recipient) { SMSGateway.send_message(recipient.phone, message) if recipient.active}
  end
end
```

> Working example is located [here](https://gist.github.com/ka8725/4fa4e94b059a9b1f7c4fe5393fa7e850).

I move all low level details down to `#send_message` and use another transition from method to proc (that's what `&` does).
That allows me using the method as a block expected by `each`.

`#send_message` returns a closure in the flesh of proc constructed with `->` shorthand.
Consider it as a deferred message send to a `recipient` that comes from the `recipients.each` iterator.

> Read more about the "method to proc" technique [here](https://www.brianstorti.com/understanding-ruby-idiom-map-with-symbol/).

Agree or not, but the resulted `#broadcast` method implementation is a way more readable than the previous version:

```ruby
# @param message [String]
# @param recipients [Array<User>]
def broadcast(message, recipients)
  recipients.each(&send_message(message))
end
```

When I read it I see immediately what's is happening
just using my intuition and natural language knowledge. If I need more details I can jump into `#send_message`
and learn even more details. To traverse a bug stopping at this point could be enough.
This point doesn't have a lot details anymore. Hence, it's easier and faster to spot a bug.

As a bonus, the method separation gives an opportunity documenting it and outlining types for
params and returned values. Lack of types that draw a strict API is another pain in Ruby
and we should do everything to improve it, I believe.

Happy complexity relief in your Ruby code!
