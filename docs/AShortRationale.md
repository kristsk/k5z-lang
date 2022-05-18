# A Short Rationale

Here I try to explain whats, hows and whys.

## Contents

* [What Is K5Z?](#what-is-k5z)
* [Why Is K5Z?](#why-is-k5z)
* [How is K5Z?](#how-is-k5z)
* [Features of K5Z](#features-of-k5z)

# What is K5Z?

It is my research project. Main goal of the project is to explore a different web application development approach.
However, the language itself is not hard-tied to web-world. It would be possible, for example, to do a weird CLI program
that suspends its state between runs. No idea why anyone would want that, but it could be done.

There are no practical applications using K5Z. But I did manage to get my Master's degree for it, but the thesis is in
Latvian and thus not that convenient for a wider public.

Sadly, I do not remember exactly why the name K5Z was chosen. And at this point there is little point to change it.

# Why is K5Z?

In my very early years of doing PHP I happened to do the admin side for some web-page-shop-thing. As one did back then,
I had happily written my own "framework", and was quite pleased with it, as it did almost everything I wanted the way I
wanted it to happen. The whole thing had some principles of the venerable MVC pattern.

Everything was there - forms, validation, templates, access control, models. I went the way of "URL is an action"
and had some abstract controllers implementing different control flow patterns for those actions, e.g. - one for action
with confirmation, one for action with form validation and so on. In case controller needed some state for it, it was
passed around in requests. This allowed using same code for control flow logic throughout the site, which mostly was
CRUDs. This way repetitive control flow logic was moved out of the of business logic.

However, there were some control flows that somewhat stumped my nicely abstracted action controllers - when one CRUD is
accessed from other CRUD and after user is done with later, he should somehow return to former. This makes perfect sense
from users point of view. On framework side, though, this was a problem, because now there was some state that persisted
for more than one action cycle. That meant it had to be stored, read and processed somewhere outside the action
controllers. Schlepping it around in requests parameters did not seem right at all.

The most obvious solution was a pragmatic one - "well, son, use the session to store where you came from and then check
and handle it specially, per actual implementation." And after some deliberation that was what I did.

But the solution did not sit quite right with me. What if you have more complex flow? How would loops be handled? And
what about some completely arbitrary flow?

I pondered for a while, but had no good answer, and then gave it a rest (or so I thought). This particular project did
not require any of the fancier flows, and I delivered everything as it was. And the client was happy. Yay.

Soon after I landed a job where I did not have to work with front end of web, and control flow problems associated with
did were not on my daily.

But I kept thinking about the problem from time to time, which had distilled to more abstract question - **"How to
properly do arbitrary control flow for web applications?"** (for some definition of "properly"). Nowadays, the answer
would probably be something along the line of "well, you do the control flow stuff on client side, and use REST for data
exchange, no state related to control flow on server-side, problem solved". But back then the time of single page web
application hath not cometh yet, and thus, I knew nothing of it.

After some time I arrived at the unbounded conclusion that the only way solve the problem "properly" is to somehow
persist (store and load) whole state of program between requests. Seemed crazy, as I had not seen this approach
anywhere.

Then the next question was - **"Eh, how much of the state is there in web application anyway?"**. From a glance it
seemed that is actually not that much, and You if that got organized into something resembling a stack for call frames,
it would go a long way.

Then the next question - **"How do I arrange the framework to persist application state and still be able to work in a
convenient enough way?"** - was harder to answer. And I sat on this for quite some time, like a year.

I arrived at realisation that capturing _state of program_ is hard to do in a clean way while using the framework
approach. And I desperately wanted it to be clean.

Okay, so if a framework does not give you enough control, what is next level up the abstraction tree? A programming
language level. You control how and what is done.

**He who controls the compiler, controls the program state.**

And that, in short, is how this journey began.

# How is K5Z?

Compiler:

* Written in Java
* ANTLR v3 for parser generation
* log4j for logging
* Google kryo for compiled library serialisation
* jgrapht for generating graphs for library dependencies and CFGs of declarations
* Apache Commons CLI for command line options

Now in year 2021 ANTLR v3 is old-old-old. But back then it was quite recent and with some coaxing, did what I wanted.

# Features of K5Z

1. K5Z compiles to PHP, runs on a toaster.
2. Allows for "natural" program execution flow in server-side, shared-nothing execution model.
3. Has closures, and they are nice - see section about closures and anonymous functions.
4. Compiler does data flow analysis and warns about reads before writes.
5. Functions can have named arguments.
6. Allows including and reuse PHP of code (some limitations apply).
7. Checks function usage and errors on undefined functions or bad arguments.
8. A somewhat naive, but convenient concurrency model using "green" threads is present and can be (ab)used.
