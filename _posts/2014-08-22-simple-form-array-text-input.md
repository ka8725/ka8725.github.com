---
redirect_to:
  - https://blog.widefix.com/simple-form-array-text-input
layout: post
title: "Simple form array text input"
description: "Use simple_form to generate array of text fields. Add custom input for the PostgreSQL array in Rails."
tags: [rails, SimpleForm, array, PostgreSQL, text, input]
share: true
comments: true
---

Since Rails 4 supports PostgreSQL array type out of the box it would be great to have an opportunity to use it for getting from a form on client side an array of text fields (it may be collection of zips, for example) and pass it to a model. I love [SimpleForm gem](https://github.com/plataformatec/simple_form) to generate a form in Rails but it allows to generate only collection of radio buttons or checkboxes and unfortunately it doesn't support the functionality. In this post I will show how to solve the problem.

## Problem

This screenshot will explain what I have to do without any words:

![Account and User relation](/images/zips.jpg)

In database I'm going to use [PostgreSQL arrays in ActiveRecord](http://blog.plataformatec.com.br/2014/07/rails-4-and-postgresql-arrays/) for saving the data. But in the view we don't have some tool to generate the fields with Rails out of the box. So let's do it with SimpleForm.

## SimpleForm and custom inputs

It may not be surprise for you, but SimpleForm gives us possibility to define our own [custom input](https://github.com/plataformatec/simple_form/wiki/Custom-inputs-examples). It's very easy to do it: just define your own class inherited from base SimpleForm's input and call when generating inputs.

This is the custom attribute for the array input:

{% highlight ruby %}
class ArrayInput < SimpleForm::Inputs::StringInput
  def input
    input_html_options[:type] ||= input_type

    Array(object.public_send(attribute_name)).map do |array_el|
      @builder.text_field(nil, input_html_options.merge(value: array_el, name: "#{object_name}[#{attribute_name}][]"))
    end.join.html_safe
  end

  def input_type
    :text
  end
end
{% endhighlight %}

In the form use this example to generate a collection of text fields:

{% highlight ruby %}
form_for @location do |f|
  f.input :zips, as: :array
end
{% endhighlight %}

One note here is that the `@location` object must have the `zips` attributes and it should be an array. If you have not empty array of `zips` this peace of code will generate them in a form. I you have an empty array of `zips` you will have to worry about how to initialize the attribute on the server before rendering a form.

All the generated inputs will get name like this: `location[zips][]`. And all of them will have the same name. Browser will  join them together before sending to a server. Rails will understand that this is an array of inputs because their names ending with `[]`. Finally you will get a parameter of an array in `params` controllers' object. It means that you will be able to get the values in a controller with this code: `params[:location][:zips]`.

We've just being said that the browser will join parameters in one line with the same name and this is an example how they will go to the server: `"location[zips][]=11111&location[zips][]=22222"`. Rails will parse their into a hash with
`Rack::Utils.parse_nested_query` method. Let's summarize to understand the process and to see the results of the parsing attributes:

{% highlight ruby %}
$irb --simple-prompt
>> require 'rack'
=> true
>> Rack::Utils.parse_nested_query "location[zips][]=11111&location[zips][]=22222"
=> {"location"=>{"zips"=>["11111", "22222"]}}
{% endhighlight %}

If you use [StrongParameters](http://edgeapi.rubyonrails.org/classes/ActionController/StrongParameters.html) to filter out parameters going from a client you may be interested how to manage this. It's very simple task - just don't forget to identify that you are expecting array rather than one attribute:

{% highlight ruby %}
params.require(:location).permit(zips: [])
{% endhighlight %}

Note the `[]` is after the `zips:` - it's necessary to not forget to write it like this. In other case (if you write `permit(:zips)`, for example) you will get an exception because an array goes from server but StrongParameters expects a single object in such definition.

> Implementing "+Add another" link won't be described in this post because it's rather trivial task. You will have to write a little JavaScript and it's up to you.

Hope this article will help somebody.
