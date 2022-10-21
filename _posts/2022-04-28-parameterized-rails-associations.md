---
redirect_to:
  - https://blog.widefix.com/parameterized-rails-associations
layout: post
title: "Parameterized Rails associations"
modified: 2022-04-28 00:41:06 +0300
description: "Figure out how to make Rails associations parameterized with some global subjects, such as current user."
tags: [ruby, rails]
comments: true
share: true
---

This post shows how to define associations dependent on some global object such as current user
(also we can call these things **multi-tenant associations**).

### Problem

Picture a Rails project with three models: User, Artist, Song. Artist has many Songs/Song belongs to Artist.
Anonymous users can see only published songs, authenticated users can see all songs.

```ruby
class User < ApplicationRecord
end

class Song < ApplicationRecord
  enum :status, {draft: 'draft', published: 'published'}
  belongs_to :artist
end

class Artist < ApplicationRecord
  has_many :songs
end
```

Somewhere in controllers there is a code that optimizes N+1 problem:

```ruby
@artists = Artist.includes(:song)
```

But the `songs` association defined on the `Artist` is not aware of our requirement that
it needs to list only published songs for not logged-in users. So it would always return all songs.

See how to fix that without changing the association name below.

> Keeping the association name is an important requirement. It doesn't need to change the code
everywhere where the existing application has `.includes(:song)`.
That way, it eliminates regression and possible bugs from forgotten places.

### Solution

ActiveRecord doesn't have any functionality that would allow to parameterize associations. Fortunately,
it allows specifying an optional lambda that can reduce the scope of returning objects. Sounds like exactly what we need.
Unfortunately, it's not aware of the fact if the current user is present (authenticated).
But we can define a global thread-safe variable and use it there.

The global variable can be set by `ApplicationRecord` within `around_filter`:

```ruby
class ApplicationController < ActionController::Base
  around_action :set_current_user_globally

  private

  def set_current_user_globally
    Thread.current[:current_user] = current_user
    yield
  ensure
    Thread.current[:current_user] = nil
  end
end
```

Then it becomes easy to use it within associations:

```ruby
class Artist < ApplicationRecord
  has_many :songs, -> { Thread.current[:current_user] ? all : where(status: :published) }
end
```

The application starts working according to the new requirement that anonymous can see only published songs.
Note, that the other places over the app remain the same and don't need any changes.

That's whole solution. It's as simple as that.

Let's check it in action:

```ruby
irb(main):001:0> Artist.includes(:songs).map(&:songs)
   (0.9ms)  SELECT sqlite_version(*)
  Artist Load (0.5ms)  SELECT "artists".* FROM "artists"
  Song Load (0.7ms)  SELECT "songs".* FROM "songs" WHERE "songs"."status" = ? AND "songs"."artist_id" IN (?, ?)  [["status", "published"], ["artist_id", 1], ["artist_id", 2]]
=>
[[#<Song:0x00000001100331d8 id: 2, status: "published", artist_id: 1, ...],
 [#<Song:0x000000011008be28 id: 3, status: "published", artist_id: 2, ...]]
```

It has no set `Thread.current[:current_user]` - assuming it's an anonymous user request. That's why the result has only published songs.

On the next test we specify `Thread.current[:current_user]` - doing that in the console we kinda simulate running the around filter above in the controller.

```ruby
irb(main):002:0> Thread.current[:current_user] = User.first
irb(main):003:0> Artist.includes(:songs).map(&:songs)
  Artist Load (0.2ms)  SELECT "artists".* FROM "artists"
  Song Load (0.4ms)  SELECT "songs".* FROM "songs" WHERE "songs"."artist_id" IN (?, ?)  [["artist_id", 1], ["artist_id", 2]]
=>
[[#<Song:0x00000001108c82d0 id: 1, status: "draft", artist_id: 1, ...>,
  #<Song:0x00000001108c8140 id: 2, status: "published", artist_id: 1, ...>],
 [#<Song:0x0000000110923f90 id: 3, status: "published", artist_id: 2, ...>,
  #<Song:0x0000000110923e28 id: 4, status: "draft", artist_id: 2, ...>]]
```

Now it returns all songs regarding their status. You also can see that on the generated SQL.

The association became really smart and very flexible.

### Drawbacks

1. This solution works until you face the case when the association should behave differently all over the app.
It's when one place needs the result reduced and at the same time, another place needs all items within the result.
In this case, the solution should be advanced (yes, it's possible to make it even smarter) or replaced by something else.

2. The project I applied this solution uses [database cleaner](https://github.com/DatabaseCleaner/database_cleaner) gem in tests.
Even though, the following RSpec example looks ok it would break this gem work:

```ruby
around do |example|
  Thread.current[:current_user] = user
  example.run
ensure
  Thread.current[:current_user] = nil
end
```

The code clears the global var in the `ensure` block above is run after the database cleaner hooks.
But all objects kept within `Thread.current` are [not being cleaned by database cleaner](https://github.com/DatabaseCleaner/database_cleaner/issues/123#issuecomment-1090902223).
So, if there are some specs in the projects that use an around block like above the tests can start fail randomly because of the kept users in DB across the tests (test examples usually rely on a empty DB).

I come up with the following workaround:

- Use `before` block instead of `around`.

```ruby
before { Thread.current[:current_user] = user }
```

- Change database cleaner setup.

```ruby
config.after(:each) do
  # Thread.current[:current_user] is set in some tests
  # it should be cleaned before database cleaner runs, otherwise it won't be dropped from DB.
  Thread.current[:current_user] = nil
  DatabaseCleaner.clean
end
```

Not a very elegant solution, but it works well.

### Conclusion

See a working Rails app as an example [here](https://github.com/widefix/smart-assocs).

While working on an issue try to fix it "locally". That allows us find a solution that avoids unnecessary global changes, regression, and bugs. Happy coding!


### Update 28 Apr 2022

I've got several feedbacks suggesting to use [ActiveSupport::CurrentAttributes](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html)
instead of `Thread.current`. Can't disagree with that, it looks much safer and cleaner. Thanks to everyone who suggested that.


### Update 1 May 2022

Got an interesting and very useful response on [reddit](https://www.reddit.com/r/rails/comments/udr0ne/comment/i6kw9vg/?utm_source=reddit&utm_medium=web2x&context=3).
Reposting it here.

Sequel has this functionality out of box:

```ruby
class Artist < Sequel::Model
  one_to_many :songs
end

# somewhere in the controller
Artist.eager(songs: -> (ds) { current_user ? ds : ds.where(status: :published) })
```

[I've submitted a feature request to Rails](https://discuss.rubyonrails.org/t/dynamic-eager-loading-associations/80569).
