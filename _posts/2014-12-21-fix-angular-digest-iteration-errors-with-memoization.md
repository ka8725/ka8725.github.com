---
layout: post
title: "Fix Angular's digest iterations errors with memoization"
description: "Memoize your methods in Javascript to avoid performance problems in Angular and errors saying that 10 digest iterations reached."
tags: [angular, javascript, errors]
share: true
comments: true
---
Sometimes I have failed Angular code with the following exception message: **Error: 10 $digest() iterations reached. Aborting!** and I had no idea what is going on there while didn't get an explanation how Angular's bindings work. In this article I will share an idea how to avoid the problem and how to get better performance in Angular applications with memoization technique.

## The $digest problem

So, when you get the error message **Error: 10 $digest() iterations reached. Aborting!** in your Angular application what it actually means? Well, to answer on the question we have to understand how Angular detects changes to show them on UI immediately.

The algorithm is very simple - when you output a variable or function in html templates via bindings, a watcher is created. During life cycle of the application, the watchers's expressions are called many times and their results matched with the previous values, and, if values differ, an event is fired about this and the new values shown in the templates. To get more information about detecting the changes you can refer this [article](https://www.ng-book.com/p/The-Digest-Loop-and-apply/). But for now it's enough to understand that the possible issue is a function which returns an array of objects and the function is called in the digest cycle.

It's very simple to demonstrate it. Assume that we want to iterate through users list which is generated in a controller's function:

{% highlight javascript %}
var app = angular.module('plunker', []);

app.controller('MainCtrl', function($scope) {
  var data = [
    {firstName: 'John', lastName: 'Smith'},
    {firstName: 'Andrei', lastName: 'Kaleshka'}
  ];

  $scope.getUsers = function() {
    var result = [];
    angular.forEach(data, function (user) {
      result.push({fullName: user.firstName + ' ' + user.lastName});
    });
    return result;
  }
});
{% endhighlight %}

{% highlight html %}
<div ng-repeat="user in getUsers()">
  {{user.fullName}}
</div>
{% endhighlight %}

[Demo](http://plnkr.co/edit/ZuGB6ecpAQaHW2GFZLzC?p=preview)

The issue happens because the `getUsers()` returns different result every call despite of the fact that properties of the array items are the same:

{% highlight javascript %}
var res1 = [{fullName: 'John Smith'}, {fullName: 'Andrei Kaleshka'}];
var res2 = [{fullName: 'John Smith'}, {fullName: 'Andrei Kaleshka'}];
res1 === res2; // false
{% endhighlight %}

That's why Angular's digest cycle will infinitely call the `getUsers`. The error message **Error: 10 $digest() iterations reached. Aborting!** informs us about this.

## Solution

To fix the problem we can cache the results of the function. For this purpose I prefer to use **Lo-Dash**'s [memoize](https://lodash.com/docs#memoize) function:

{% highlight javascript %}
var app = angular.module('plunker', []);

app.controller('MainCtrl', function($scope) {
  var data = [
    {firstName: 'John', lastName: 'Smith'},
    {firstName: 'Andrei', lastName: 'Kaleshka'}
  ];

  $scope.getUsers = _.memoize(function() {
    var result = [];
    angular.forEach(data, function (user) {
      result.push({fullName: user.firstName + ' ' + user.lastName});
    });
    return result;
  });
});

{% endhighlight %}

[Demo](http://plnkr.co/edit/KBmk4J2ZCt0SsmZlnKZi?p=preview)

## Conclusion

Using this technique we improve performance of our Angular application, get rid of exception **Error: 10 $digest() iterations reached. Aborting!**, implement functions on `$scope` which return an array of objects and the functions can be used in Angular's templates.
