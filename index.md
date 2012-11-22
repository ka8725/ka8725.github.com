---
layout: page
title: Ruby On Rails Guides
description: "Hello! This is my blog. It contains a few posts which are presented as a little Rails guides. Recently I find a lot of interesting situations, so I decided to create this blog and describe these situations and share my ideas, axperience and thoughts with you. I hope you will enjoy my posts"
tagline: Supporting tagline
---
{% include JB/setup %}

##List of recent posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>
