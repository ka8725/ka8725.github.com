---
layout: post
title: "Polish Rails migrations"
modified: 2018-04-14 00:41:06 +0300
description: "Sometimes, it's needed to re-run a new migration in a new pull request back and forth several times after code changes, rebasing and etc. The process gets annoying when there are many migrations in the PR and that one, that's being changed, is somewhere in the middle of the history. In this post there is a solution how to relieve the pain."
tags: [rails, migrations]
comments: true
share: true
---

Sometimes, it's needed to re-run a new migration in a feature-branch back and forth several times due to code changes, a typo fixing, performance improvement, rebasing and etc. That can be done by using the most popular rake commands: `rake db:rollback` so many types as it's needed to get to the migration should be changed (or even easier `rake db:rollback STEP=3` where 3 is the number of steps back), change this migration and run `rake db:migrate` - that's all, easy-peasy. Isn't it? But, what if there is a typo or mistake in this migration again? What do you do? Repeat the process again? That issue might get too annoying. In this post I show you an alternative idea how to relieve the pain and start feeling more comfortable in writing migrations.

### Problem

Just imagine the situation below. There is the list of migrations in your Rails app:

```
< > 20180317144803_migration1.rb
< > 20180317144804_migration2.rb
...
< > 20180317144814_migrationN.rb
```

These all migrations have been run locally. The migration `1` should be altered. Moreover, it's clear there is no need to re-run them all migrations from `2` to `N`. Migrating all of them back to the first migration might turn into a pain, especially working on a big problem in a big team, that changes the migrations list too often. Just especially for that case, there is a special list of rake tasks kindly provided by Rails.


### Solution

Long story short, to run the migration (it and only it!) back use this command:

```
rake db:migrate:down VERSION=20180317144803
```

Then make a necessary change in the migration. And run the migration forth:

```
rake db:migrate:up VERSION=20180317144803
```

Taking these rake tasks as the problem solution, pay attention that migrations can be run in any order in Rails. But sometimes, they might depend on each other. This happens more often at the beginning of a project development. So, to be on the safe side run all of them down and forth at least once like this:

```
rake db:rollback STEP=12
rake db:migrate
```

`12` is the `N` here.


### To boot

And for the dessert, check out this command that shows status for all migrations in a Rails project:

```
rake db:migrate:status
```

This is the output I got on a test project:

```
database: test-dev

 Status   Migration ID    Migration Name
--------------------------------------------------
   up     20180322190630  Remove special name
   up     20180326210602  Add default for users
  down    20180405124704  Add email
   up     20180406205508  Remove email
```

So, in this particular example when it's executed `rake db:migrate:up VERSION=20180405124704` the status turns into this state:

```
database: test-dev

 Status   Migration ID    Migration Name
--------------------------------------------------
   up     20180322190630  Remove special name
   up     20180326210602  Add default for users
   up     20180405124704  Add email
   up     20180406205508  Remove email
```

When `rake db:migrate:down VERSION=20180405124704` to the previous state correspondingly.


### Conclusion

A migration adjustment could be a huge pain. But thankfully Rails, this process is a pleasure to work with. There are may be provided many pieces of advice for this kind of job. But I would rather caution you that it's not possible to have written an instruction for every case you have in your daily work. Just read the errors you have in the migrations and follow common sense. For example, when an error says there is no such table `x` that is being tried to be deleted, then maybe you are doing something wrong and have a mess in your DB. So maybe, the DB should be re-initiated with the new data. Or you can just comment this line in the migration for this run and uncomment it back when it's done (this can be accepted in some circumstances when you are experimenting with a new migration you are working on).
