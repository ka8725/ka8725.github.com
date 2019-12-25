---
layout: post
title: "Transition from has many to has and belongs to many"
modified: 2019-12-23 00:41:06 +0300
description: "This post describes how to move from a belongs to/has many to has and belongs to many association in running Rails application in production."
tags: [postgresql, sql, ruby, rails, active_record]
comments: true
share: true
---

### Problem

Picture the case when a Rails application has deployed to production and needs a change for an already implemented association. For example, given user model **has many** managers, i.e. manager **belongs to** user, it needs to be users has and belongs to many managers. Or speaking from business point of view, change UI so that it allow to select many managers for a user instead of one.

There are many ways how
