### Intro

Hey everyone, and welcome. I hope you're enjoying yourself.

So, to get things started: Who here has heard about Beam? (Raise of hands)

Cool, and who has heard about Gleam? (Raise of hands)

So it is clear that this will be new to a lot of you, which is great. Here's the thing: I love learning new languages and technologies, especially if they vastly differ from what I've used before.

For one thing, it's fun in and of itself, but it also sheds light on alternative ways of tackling problems and different ways of expressing your intent through code. Sometimes it is a "huh, that's neat", and other times it can become a whole "woah, why are we not doing it like this?!" sensation!

One of the dangers of being locked into a single ecosystem is buying into "cultural truths". We see this a lot, especially on very standardised enterprise technologies like Java and C#. We do the same thing again and again because we have always done it that way. There is little variation in technology and expression.

Some might argue that is a good thing. That standardisation is great because it is easy to get people into the codebase... but is that a good thing?

What I've seen in the last few years worries me. I see the same architecture copied and pasted across multiple industries and teams. I see developers struggle with even small deviations from "the standard" way of doing things. And I see a lack of fun and interest in the craft.

As developers, we should be good at adapting to different architectures. We should be able to pick up different codebases fairly quickly, and we should think about the best solution for the problem.

This is where looking at other languages becomes important. It challenges our set ways, especially if we look at languages that are really different. Like, how do you solve real problems in a language that has no classes? You can't just throw "@Service" at the top of something and magically have it available. What if you don't have access to loops?
Heck, what if you don't have access to an if statement?

The interesting question here is looking at what other languages do and seeing how they solve these problems. Maybe there's something we can learn from it. Maybe the teaching is that it is neat, but not for you. But once in a while, you might come across something that really changes your perspective on software development as a whole.

### Intro (me)

[Move to introduction slide]

I am John Mikael Lindbakk, and I will be your guide as we explore Beam and Gleam!

So, I have been a developer for about a decade. I've done a few things. I've been an in-house developer, and in more recent years I've been a consultant at bspoke. I write on my website, and I do the occasional talk here and there.

If you've seen me before, it might be from my 2024 talk about automated testing. Sidenote: I assume since that talk you've all done well and started writing plenty of good tests, right? You've had 2 years, so there are no excuses!

[Switch to surtoget slide]

Otherwise, you might know me from Surtoget, where I complained about the state of sørlandsbanen. This is the website that kinda threw me into the Gleam community and pushed me to hold a talk at the first Gleam Gathering in Bristol earlier this year.

[Switch to brunost slide]

A few more of you might know me from my work on Brunost, the nynorsk programming language. It seemed to catch a lot of people's attention, while also catching their need to correct my nynorsk.

[Switch to NoMeatProxy slide]

If not, then I also created the No Meat Proxy page, which is all about how we shouldn't just throw AI stuff at each other.

### Beam

[Switch to slide with regular tech abstraction]

Alright, so let's talk abstractions. 

- At the bottom, we have hardware, or 0 abstractions. Pure metal.

- Then we have the kernel/OS and drivers. 

- On top of that, we might be running a container.

- Then we have our precious JVM.

- And then we have the framework we use, like Spring.

- And lastly, we have... our code.

Just think about how many millions of lines of code are doing stuff before your application gets to print "Hello world".

Don't get me wrong, I'm not a huge performance fanatic. I'm not here trying to push everyone to go back to pure metal. But we should acknowledge that things are weird.

But also, this example _IS_ not an exaggeration. If you run on public cloud or work in a large enough org, then it is likely that the machines running Kubernetes are also virtualised themselves, adding millions upon millions of lines of code on top of the ones that were already running. 

The way I used to think about this was that virtual machines like the JVM aren't compatible with modern development. Why have a machine that runs a virtual machine that runs a container machine, which contains a language virtual machine which runs your code? It sounds very convoluted.

I used to therefore think that something like Go or Rust could help out. Let's cut the virtual machine entirely. Remove one entire abstraction and call it a day.

[Show slide with abstraction stack with VM gone]

This would eliminate over 1 million lines of code from the abstraction tree we got going on here.

But we need to be realistic: Abstractions aren't everything. We can't count them, and we cannot say that "less is automatically more". After all, the JVM helps us out in different ways. It manages our memory, handles our threads, and so forth. There is utility in there that adds value.

So let's think about language machines in a different way. Rather than thinking about them as "something that runs our code", let's think of them as something that can add utility.

[Show fictional VM slide]

Let's come up with a VM which can run in a cluster, on different machines even. And let's say that each process within that VM is this tiny virtual thread, kinda like Kotlin Coroutines or green threads we got in Java 21.

Now, for these threads to communicate, we build messaging into the language and VM itself.

And since we have full control over these processes, we can build supervisors around them for reliability, so they can scale as traffic comes in and handle process failures elegantly. 

Now we've created something pretty different from the JVM. Now we have a VM that is also aware of other instances, where processes within them can communicate. And the thing we created is Beam.

Beam is the Erlang VM that Elixir and Gleam compile to, and it has some standout features that take the VM from "Some box that runs my code" into something really useful. And there are cases where we can eliminate Kubernetes as an abstraction.

Granted, you might want to run other things and other kinds of programs, so you can still run Beam within Kubernetes if you want to. Just like the JVM, it will happily run within a container, and many people run it like that. But the difference is that the threshold for needing to do so is higher.

And that is the general thing I want to communicate with Beam: The bar for when you feel like you have to adopt some new tool is higher.

In modern development, we rely on a lot of dependencies. Our systems need to communicate, so we use HTTP, gRPC, Kafka, MQ, and so forth. All of these come with extra libraries that we often use. We also need to store data, so we use a database or caches like Redis.

[Move to dependency slide]

With Beam, we see that a lot of this can be done with Beam itself. We can do a lot of these things with not much work. Need a queue over the network? Just write a small process that contains a queue that other processes can send messages to. 

Need it to be persisted? Use the built-in distributed database. 

Need guarantees of retrivial? Implement a simple "ack" callback. 

In the world of Java, you're more or less forced to adopt some tool. Maybe MQ, maybe Kafka, maybe something else. In either case, you're stuck getting operations on board, figuring out how to run this darn thing in production, setting up the networking correctly, permissions, security, etc. 

In the world of Beam, it all exists within Beam. And since it already exists, that means you don't have to involve a bunch of teams - it is already there. 

Same with a cache. If all you need is to store keys and values, well, you got ETS. It's already there: Built-in. Why mess around with Redis? Again, don't get me wrong: Redis is great, and there are times you might want to use it, but if all you need is a quick, reliable cache? Well, Beam has you covered, and it will get the job done well enough for most of your cases. 

But you also see that this slide repeats a word, and if we squint at reality a little, we could say that all of these things could be replaced with OTP.

And what is OTP? OTP stand for "Open Telecom Platform", which sounds really niche, but it really isn't. Don't focus on the word "Telecom", and instead focus on "Platform". 

OTP is essentially a collection of tools, like a database, a KV storage, a debugger and so forth. All the added functionality we've talked about so far is essentially wrapped into this platform.

But to get to OTP, we first need to understand where Beam came from, and to understand Beam, we need to take a little detour to Erlang.

[Switch to Erlang slide.]

Erlang was built all the way back in the mid 80s at Ericsson. The challenge Ericsson had was that they needed a language that could run on telephone switches, where thousands of calls could be established all of a sudden while a bunch of simulation events were going off.

Not only did the language have to handle all of these calls happening, but on top of that, they had to deal with a bunch of failure modes that could result in calls being disconnected, routing, billing, and so forth. There were a million small things that are really hard to do when you have constant traffic over the wire, and you can't really let a bug drop all calls, nor prevent people from calling just because you gotta do an update.

Now, forwarding to the early 90s and we have the development of Beam, which has seen development ever since!

But let's go back to why Erlang was bult and what Beam had to support. It needed to support a lot of traffic on fairly conservative hardware. It needed to support upgrades without downtime. It needed to handle a lot of tasks at the same time for every caller. Is this that different than what a lot of us have to deal with?

It turns out that a lot of this "telecom stuff" isn't that different than what the web is now, which makes the Beam a pretty compelling thing to build on top of.

___

### Let's learn some Gleam

So we have this very cool VM that can do some neat stuff, but we need a language on top. The original language was Erlang, but a lot of people find Erlang to be a little esoteric for those of us that is used to the C-family of languages.

Then we have Elixir. A more modern take that borrows a lot of its ideas from Ruby. I really like Elixir, but I like to work with staticly typed languages. I enjoy using typing to make some conditions impossible. While Elixiri has a pretty good gradual type system, it isn't really as strict as I want.

No, for me, the choice was Gleam. 

[Move to Gleam slide]

Gleam is the language that "felt right" from the beginning, but it's not all about syntax. After all, I'm the kind of person which has part of his website written in Clojure.



### Typing

- Learn about types in Gleam.

- Learn how to enforce correctness through types.

- Learn how we can do something similar in Java.

### Errors when there are no exceptions

Another thing about Gleam is that it has no exceptions. In Java we throw exceptions all over the place! A field not formatted the way we like? Exception! A number that is negative that shouldn't be negative? Exceptions! The database returning two things instead of one? Exceptions!

In the Java-world we essentially use exceptions as a hidden return type, wich is what they are unless you use checked exceptions... and those annoy most people, so it seems like most just opts out of that.

Therefore we end up in a situation where exceptions becomes this secret thing that might happen that just breaks the flow of the application. I don't like that. Especially not when dependencies use the same pattern and may decide to just blow up your applicatio.

I prefer developers having to decide whether or not to propegate an error. Doing so forces developers to make an active decision, which is healthy.

Gleam solves this by having errors as values.

[Slide to Result type]

Gleam uses a `Result` type, which is essentially a typed Tuple or Pair. It has one result in case there's a success, and one if there's a failure. 

To get to the success response we must also make a decision about what to do in case there's an error. In other words, we have to manage failure.

I reckon most seasoned developers have had the scenario where a 500 HTTP response has been thrown, or the application has simply quit because it crashed due to an uncaught exception. This is not rare in the world of Java when all we use is unchecked exceptions. It has been culturaly acceptable to risk the operability of our systems because we don't want to deal with the errors.

Frameworks like Spring also assumes this, so they run the try-catch for us and formats the exception to the best of their ability, which is great, but also kinda unfortunate. Why can't we have control over our own code?

//TODO: Talk about the difference between exceptions and errors?

There is a meaningful distinction here though: Errors we can revove

- Show Kotlin

### Let it crash

"Let it crash" has been the mantra for Erlang since the 80s. The idea behind is that the world is messy, things happen and the unexpected will occur. Therefore, rather than building systems that assumes perfect conditions, we instead build systems where it is expected that things will crash.

So what does that mean in practice?

In the world of Gleam and Beam that means having supervisors watching over smaller worker threads. Like for example you might have worker threads that serves HTTP requests. If one of them dies, the supervisor will create a new one.

Since these are tiny processes, the restart is near instant, and no real downtime impacts the end user.

Remember that we are talking about excetions here: The things we cannot meaningfully recover from, not even with Spring wrapped around it.

In the world of Java we would see a total failure that takes down the entire VM. We'd usually run this in something like Kubernetes which would discover the crash and spin up a new container, but now we're looking at the start of the container itself and a complete fresh start of the JVM and whatever Spring needs to do on startup.

This is mostly fine when running multiple instances and only one of them crashes, but it can have cascading effects as the time it takes for one instance to recover can impact other instances.

//TODO: Doesn't this issue also exists on supervised green threads?

### Size matters

[Show size matters slide]

// Do "size matters" joke, call out the audience

[Show language size matters slide]

It is LANGUAGE size that matters! And it genuinly does matter!

This is something I first discovered when learning Clojure. For those who doesn't know, Clojure is a lisp dialect, and Lisp is a language that is as small as it can get, yet allow you to write complex, working and reliable software. It casts a stark contrast to other languages with much more complexity built-in.

Gleam is also a small language. It only has 22 reserved keywords. That is in stark difference to Java which has 68, or Kotlin with over 70. Not to speak about C# that is edging on 80.

So why does this matter?

One could assume that "more keywords" would mean more flexibility. More room for the developer to express themselves and do things they mean is right. And that is true, but that also opens the door to inconsistencies within the application and ecosystem as a whole.

More importantly, for me, is that a large language often tries to do much and generally lacks opinion on what the "correct" way of coding is. For example, Kotlin is built its reputation by being a "better Java" by simplifying syntax and enabling more functional programming patterns. But is this a good thing?



### Wrapping up


