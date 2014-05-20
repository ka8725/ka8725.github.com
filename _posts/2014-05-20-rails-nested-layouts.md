---
layout: post
title: "Nested layouts in Rails"
description: "Use partials as layouts in Rails applications. It allows to nest layouts and get rid of code duplication
in views."
tags: [rails, layouts, render, partial]
---
{% include JB/setup %}

Rails provides us great functionality for managing **layouts** in a web application.
The **layouts** removes code duplication in view layer. You are able to slice all your application pages
to blocks such as header, footer, sidebar, body and etc. This is an example of typical web application page, almost
every site has these blocks. And as a rule the *body* block differs on each page. But sometimes we get into situation
when there are several pages with similar elements. For instance, it may be a progress bar in a wizard form.
If there are many steps in the wizard form then it gets annoying to copy and paste the progress bar's code
to the each step. Fortunately, Rails has functionality out of the box to solve this problem ideally.
And this is an aim of this post. For the first glance the problem may seem to be common, but I personally
didn't find the solution in any book for Rails which I'd read. I've met it in the Rails documentation only.
Because of this reason the post may be useful for every Rails developer.

# The problem

This is a prototype of a general web page:

![Typical layout of a web page](/images/layout.jpg)

Every Rails developer knows how to specify a layout for it. Let's revise the knowledge.
A generated Rails application has a default layout and
it's defined in the *app/views/layouts/application.html.erb*. On the screen above there is only one dynamic block - it's
the **body**, the **footer**, the **header** and the **sidebar** are common blocks for each page. So the code for the layout
may look like this:

{% highlight html %}
<!DOCTYPE html>
<html>
<head>
</head>
<body>
  <%= render 'shared/header' %>
  <%= render 'shared/sidebar' %>
  <%= yield %>
  <%= render 'shared/footer' %>
</html>
{% endhighlight %}

The **yield** in the code above is the place in which any action template will be rendered.
This is a default Rails behavior.

But assume that you have to make a layout system in the **body** block. On the picture below you can see an example of
such situation:

![Wizard form](/images/steps.jpg)

As you see each of these three steps includes common blocks: they are the progress bar, the "Submit" button and when
you start to implement the steps you will see that it contains repetitive code. It may be, for example, form tags. This is
the problem of nested layout. Of course we may copy paste the code of these separated by us blocks but this is not our way.

## The solution

As you guess, Rails provides functionality to solve the problem out of the box. The problem solved by using partials
as layouts. `render` helper method accepts `:layout` option and there you can pass an path to the partial which will be
the layout at the same time. Repeat it again, a **partial is a layout at the same time**.

Define the partial which will be the layout for the wizard form. Path for the partial may look like this
*app/views/wizard/_step.html.erb*:

{% highlight html %}
<%= render_progress_bar(current_step) %>
<%= yield %>
{% endhighlight %}

Notice that it uses the same approach to get dynamic blocks, the **yield** doing here the same stuff. And now when you are on some step of the wizard form use **render** helper with **:layout** option and pass there the
path to the partial. This is our 1st step which is placed in the following file *app/views/wizard/step1.html.erb*:

{% highlight html %}
<%= render layout: 'step' do %>
  <%= form_for resource, url: submit_path do |f| %>
    <%= f.input :some_field %>
    <%= f.submit %>
  <% end %>
<% end %>
{% endhighlight %}

Now when the first action renders the application layout is applied firstly then rendering reaches this template and renders
the *app/views/wizard/_step.html.erb* *partial as layout* firstly and passes the rendered form to the *yield* place (2nd line in the *app/views/wizard/_step.html.erb*).

The problem is solved - we don't have repetitive annoying code in each step template which renders the progress bar. But
we still have repetitive code with creating forms with the **form_for** tag and the "Submit" button in the each template.
We also can move this code to the partial-layout and pass the form variable **f** as an argument of the **yield**:

{% highlight html %}
<%= render_progress_bar(current_step) %>
<%= form_for resource, url: submit_path do |f| %>
  <%= yield f %>
  <%= f.submit %>
<% end %>
{% endhighlight %}

And now our template for the first step contains much less code:

{% highlight html %}
<%= render layout: 'step' do |f| %>
  <%= f.input :some_field %>
<% end %>
{% endhighlight %}

In the templates of other steps we should change only the fields of their forms.

If you want to know more about **render**'s opportunities, please, follow the [official documentationn](http://guides.rubyonrails.org/layouts_and_rendering.html).

## Conclusion

Nesting layouts reduces a lot of code duplication. Use the **render layout** approach described in this post and the coding
will bring you more joy.
