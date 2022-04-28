---
layout: post
title: "Parameterized Rails associations"
modified: 2022-04-28 00:41:06 +0300
description: "Figure out how to make Rails associations parameterized with some global subjects, such as current user."
tags: [ruby, rails]
comments: true
share: true
---

This post shows how to define associations dependent on some global object such as current user
(also we can call these things as **multi-tenant associations**).

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
it needs to list only published songs for not logged in users. So it would always return all songs.

See how to fix that without changing the association name below.

> Keeping the association name is an important requirement. It doesn't need to change the code
everywhere where the existing application has `.includes(:song)`.
That way, it eliminates regression and possible bugs from the forgotten places.

### Solution

ActiveRecord doesn't have any functionality that would allow to parameterize associations. Fortunately,
it allows to specify an optional lambda that can reduce scope of returning objects. Sounds like exactly what we need.
Unfortunately, it's not aware of the fact if current user is present (or user is authenticated).
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
The other places over the app remain the same and don't require any changes, even though.

This is the whole solution. It's as simple as that.

Now, let's check it out:

```ruby
irb(main):001:0> Artist.all.includes(:songs).map(&:songs)
   (0.9ms)  SELECT sqlite_version(*)
  Artist Load (0.5ms)  SELECT "artists".* FROM "artists"
  Song Load (0.7ms)  SELECT "songs".* FROM "songs" WHERE "songs"."status" = ? AND "songs"."artist_id" IN (?, ?)  [["status", "published"], ["artist_id", 1], ["artist_id", 2]]
=>
[[#<Song:0x00000001100331d8 id: 2, status: "published", artist_id: 1, ...],
 [#<Song:0x000000011008be28 id: 3, status: "published", artist_id: 2, ...]]
```

Since, it has no set `Thread.current[:current_user]` we assume it's an anonymous user request. And as you see it returns only published songs.

Now, let's specify `Thread.current[:current_user]`. Doing that in the console we kinda simulate running the code above in controller.

```ruby
irb(main):002:0> Thread.current[:current_user] = User.first
irb(main):003:0> Artist.all.includes(:songs).map(&:songs)
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

The project I applied this solution uses [database cleaner](https://github.com/DatabaseCleaner/database_cleaner) gem in tests.
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

See a working Rails app as an example [here](https://github.com/railsguides/smart-assocs).

While working on a issue try to fix it "locally". That allows to come up with a solution that avoids unnecessary global changes, regression, and bugs. Happy coding!
