---
redirect_to:
  - https://blog.widefix.com/how-to-generate-rake-task
layout: post
title: "How to generate rake task"
description: "Ruby on Rails guides for generate rake task. If you want to write new rake task you can use rails generate task generator. It is Ruby On Rails generator which generates scaffold for the rake task"
tags: [ruby, rails, rake]
share: true
featured_post: true
comments: true
redirect_from:
  - /2012/03/14/how-to-generate-rake-task/
---


Have you ever written your own __rake tasks__? If you write them very often this post will be very useful for you. I won't describe what is __rake task__ here because there are a lot of information about it yet. I will tell you how to easy _generate_ __rake task__.


<a onclick="_gaq.push(['_trackEvent', 'Reference', 'Packt', '#rake-task-management-essentials']);" href="https://www.packtpub.com/product/rake-task-management-essentials/9781783280773?_ga=2.19088061.400786981.1668522155-1689462152.1668522155" target="_blank">
  <img src="/images/rake_book.jpg" alt="Rake Task Management Essentials" align="right" vspace="5" hspace="5" width="120"/>
</a>

> Recently I have written a book about **Rake**. It's called **Rake Task Management Essentials**. If you like this post's content and interested in **Rake**, if you would like to know more about this great tool you can buy it [here](https://www.packtpub.com/product/rake-task-management-essentials/9781783280773?_ga=2.19088061.400786981.1668522155-1689462152.1668522155). I promise that after reading the book you will understand main goals of **Rake**, how to use it in your development process, daily work or just for fun. You will understand how to refactor and speed up rake tasks. You will be introduced to all **Rake**'s features by straightforward and practical examples.


Today I found interesting generator in __Ruby On Rails__. I have never read about it in any post, doc, book or tutorial, I have never seen it in any screencast, I've never heart about it from any podcast and I wondered that Google doesn't tell me nothing about it. So I decided to write about it here.

If you want to write your own __rake task__ you have 2 ways to do it (I thought so before):

1. Write it from scratch
2. Copy-paste code from another ready __rake task__ and change code to required

But there is a 3rd way to do it. Just use this __rake generator__:

	$ rails g task my_namespace my_task1 my_task2
	$ create lib/tasks/my_namespace.rake

It will generate scaffold for our new __rake task__:
>lib/tasks/my_namespace.rake

{% highlight ruby %}
namespace :my_namespace do
  desc "TODO"
  task :my_task1 => :environment do
  end

  desc "TODO"
  task :my_task2 => :environment do
  end
end
{% endhighlight %}

It is awesome! And now you can write here your code for new __rake tasks__.

Let's make sure these __rake tasks__ are exist and we are able to use them:

	$ rake -T | grep my_namespace
	rake my_namespace:my_task1  # TODO
	rake my_namespace:my_task2  # TODO

Perfect! As you can see it is very easy to write your own __rake task__. It is easier as you do it before. Thanks for reading!
