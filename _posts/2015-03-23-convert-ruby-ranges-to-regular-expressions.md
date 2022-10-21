---
layout: post
title: "Convert Ruby ranges to regular expressions"
description: "In this post I will share the gem which allows to convert Ruby ranges to regular expressions."
tags: [ruby, gem]
share: true
comments: true
---
Recently I noticed that there is no a Rubyß library that allows to convert Ruby ranges to regular expressions. That's why I decided to write it by myself and this post is just a sharing the gem's link and a few examples how to use the gem.

## Problem

Assume you have a Ruby **range** and have to transform it to a **regular expression**. Say, you have `-9..9` and have to get `/-[1-9]|\d/`. For the first glance the solution looks rather easy but to get an optimized solution it requires a lot of time if you don't know an algorithm to do this.

Recently I had to solve an issue like this and, honestly, I couldn't solve the task in 2 hours. Then I started to search a ready solution in Google and finally I found its implementation in Python. Thankfully my curiosity I've already learned Python and could manage to translate the algorithm into Ruby within 1 hour. And finally I released a gem with the algorithm.

So if you have the issue the gem may be helpful for you.

## Solution

The gem is called `range_regexp` and located [here](https://github.com/ka8725/range_regexp).

These are few examples of its usage:

{% highlight ruby %}
require 'range_regexp'
converter = RangeRegexp::Converter.new(-9..9)
converter.convert # => /-[1-9]|\d/
converter = RangeRegexp::Converter.new(12..3456)
converter.convert # =>/1[2-9]|[2-9]\d|[1-9]\d{2}|[1-2]\d{3}|3[0-3]\d{2}|34[0-4]\d|345[0-6]/
{% endhighlight %}

## Conclusion

Now we can convert ranges to regular expressions easily using Ruby. You don't have to reinvent a wheel, just get the gem and use it. If you have any suggestions or questions, feel free to contact me.
