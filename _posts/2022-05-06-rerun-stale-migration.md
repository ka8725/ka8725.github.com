---
layout: post
title: "Rerun stale migration in Rails"
modified: 2022-05-06 00:41:06 +0300
description: "Figure out how to apply a migration that has already run and the standard rake migration-related tasks don't work."
tags: [rails, migrations]
comments: true
share: true
---

Consider the following scenario. You are reviewing a pull request (PR) of your colleague.
That PR has a migration that adds a new table into the DB.
You run that migration to test the PR. The migration creates `settings` table.
Forgetting to reverse the migration so that it doesn't mess up your local DB state,
you go to another branch and continue your work.
Later, the PR gets this table renamed to `user_settings`. Finally, it gets merged.

Then you update the main branch and run migrations. Surprisingly, you've got changes in `schema.rb`.
Git shows that it wants to add `settings` and remove `user_settings` table.
You realize that you've run the migration that's kinda stale now.
You try to roll this migration back with `rails db:migrate:down VERSION=20220505072316` command. No luck:

```ruby
ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR:  table "user_settings" does not exist
: DROP TABLE "user_settings"
```

Dead-end? See how to cope with it.

### Solution

To understand which migration is run and which is not Rails has a special table in DB `schema_migrations`.
Look at its structure inside DB console (jump into it with `rails db` command or use any other DB client).
The is the description of this table inside PostgreSQL:

```sql
~# \d schema_migrations
                 Table "public.schema_migrations"
 Column  │          Type          │ Collation │ Nullable │ Default
═════════╪════════════════════════╪═══════════╪══════════╪═════════
 version │ character varying(255) │           │ not null │
Indexes:
    "unique_schema_migrations" UNIQUE, btree (version)
```

Whenever you run migration it inserts a new row into this table with column `version` equal to the timestamp of the migration file.
For example, a migration inside file `20220505072316_create_settings.rb` inserts row with `version=20220505072316`.

Next time when you run migrations Rails checks if that migration file timestamp is already inside `schema_migrations` table.
If it's not there, it applies the migration, otherwise skips it. That way `rails db:migrate` command guarantees idempotency.

That knowledge gives us a glue on what to do. If delete that migration timestamp from `schema_migrations` we can run it again.
That will add `user_settings` table but won't delete the stale `settings` table. But that's not a big deal - we can do that manually in the DB console.
Once we do that `rails db:migrate` command won't generate any diff anymore.

Run these commands within the DB console:

```sql
delete from schema_migrations where version = '20220505072316';
drop table settings;
```

Run `rails db:migrate` and make sure there are no changes on your `schema.rb`.
