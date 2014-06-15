---
layout: post
title: "Make a free landing page"
description: "This blog post describes how to make a startup landing page with minimum effort. All described tools to make the landing page are free. And as a special bonus you will see how to add a sign up form to the landing page to collect visitors' emails."
tags: [github, mailchimp]
---
{% include JB/setup %}

A **landing page** may be useful in many cases for those people who want to have business on the Internet. The main goal of the **landing page** is to promote a business idea. The target may be a site, which you are going to have (or have already released) or a book, if you are the author. The page basically contains some static content with contact information, cool images and javascript or css effects to attract people. Often there is a sign up form with mandatory email field on the page. Having an one-page site like this on the Internet you have to solve at least the following issues: writing the static site, choosing a hosting, deploying the site, looking for the back-end. In this post you will see how to solve these issues with minimal effort and cost, all tools to overcome the problems are **free** of charge.

This solution can be applied to many other types of site such as **launching soon** or **coming soon page**. The type of site doesn't matter, the main facility of these sites is that all they have static content with and, optionally, a sign up form.

## Introduction

First of all if you don't have some specific requirements for the **landing page** and you are fine with ready solutions you may be interested in ready site builders for the problem.

One of the most famous product is [LaunchRock](http://launchrock.co). It has built-in site builder with site templates, which even doesn't require to know html or css. It even has the sign up form with one field (it is email), all data from the form goes to their back-end. You may see statistic of registered users there, you are able to set your domain for the page.

But when you want to go far away from their site templates you can get to a trap. An example of such issue may be adding a field to the sign up form. You are restricted with their back-end and if you really want to add the field you have to move to your solution. Other problem is in deployment. There is no automating deployment tool. We are developers, so it's vital thing for us! We want to track our changes in a control version system (mostly [GitHub](https://github.com/)), push there changes and they will have to be fetched by a hosting server automatically.

## Hosting and deployment

There are many choices how to setup deployment process of you site. You may buy a shared hosting, virtual private or dedicated server. The same is true for deployment, there are special tools (for example, [Capistrano](https://github.com/capistrano/capistrano)) to automate delivering code to the server and restart web browser to apply it. Also you may do it manually through a [FTP](http://ru.wikipedia.org/wiki/FTP) or [SMB](http://en.wikipedia.org/wiki/Server_Message_Block) server (hello, PHP!). But to setup the process like this you have to spend time and money for some solutions.

Fortunately, there is [GitHub Pages](https://pages.github.com). It's an instrument which covers a half of work during building a **landing page**.

* It closes issue with the deployment process. You shouldn't care about it at all. Just push your changes to git repository and that's it. The changes will be applied to the site automatically.
* It provides free shared hosting for static sites.
* It works with *git*. So the desire to have a *control version system* is satisfied.
* It provides an opportunity to point you domain or subdomain to the web server. More information about this you can find [here](https://help.github.com/articles/setting-up-a-custom-domain-with-github-pages).

Three points from four are closed with the tool and also one more possible wish to have a custom domain for the site. Not bad for one tool. Also, don't forget - it's absolutely free.

> You will not see here how to set up a github pages project. It's other kind of story. Don't be sad, it's not hard as it seems. In [this article](/2012/07/19/jekyll-feature-blog-engine/) you will see how to do it. Also there is tutorial on the [official site](https://pages.github.com/).

May be main problem in this solution may be *git* if you don't familiar with this. Unfortunately, you can't use this solution if you don't know [git basics](http://git-scm.com/book). So if you are in such situation you have two choices: learn git or hire a specialist.

## Signup form

If you are going to gather some information from your visitors, you may be interested in a sign up form. Because *GitHub Pages* doesn't allow to do save forms you have to choose a back-end server. Again you have a choice here: you can write it by yourself or use ready third party servers. Writing own server seems good idea but it requires a hosting and time, that's why it's not our decision. We choose third party tool, for example it may by [Google Forms](http://www.google.com/google-d-s/createforms.html). If you choose this tool, you will have to use this [jquery plugin](https://github.com/kctess5/jqGoogleForms) to save data from your server to the *Google* remotely.

But may be the best choice for this will be [MailChimp](http://mailchimp.com). It allows to create custom forms, it has a built-in functionality to approve sent emails for site visitors through confirmation emails. There are three type of forms in *MailChimp*: **general**, **embedded** and **integration**. The *general* form is hosted on MailChimp's server, *embedded* form may be included to your site as iframe, it means that you are won't be able to change css and javascript for this type of form and finally the **integration** form allows to create any kind of form on your site, it's fully customizable.

Choosing *MailChimp* you get a bonus with sending emails to the visitors. You can create there pretty email templates and save their to your customers. This solution is free but has limitations which you may see on [this page](http://mailchimp.com/pricing).


## Conclusion

Choosing *GitHub Pages* and *MailChimp* brings us profit if we have to create a site such as *landing page* or *comming soon page* with an *email sign up form*. This is a free solution but requires some knowledge, so it may be not suitable for those people who are not familiar with *git*, for instance.

This is a [working solution](http://introduction.mezuka.com/). The site is hosted on *GitHub Pages* and uses *MailChimp* for sign up forms. Cost of usage - 0$.

![GitHub pages + MailChimp = landing page](/images/gh_mailchimp.jpg)
