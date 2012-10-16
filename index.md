---
layout: page
title: Ruby On Rails Guides
tagline: Supporting tagline
---
{% include JB/setup %}

##List of recent posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>
