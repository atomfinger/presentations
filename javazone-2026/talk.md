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

So here's my ask: even if you never touch Gleam again after this talk, try to walk out with at least one concrete habit you can steal for your Java or Kotlin code on Monday. I'll call those out explicitly as we go, section by section, so you don't have to do the translation work yourself.

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

---

### What is BEAM

[Switch to slide with regular tech abstraction]

Alright, so let's talk abstractions. 

- At the bottom, we have hardware, or 0 abstractions. Pure metal.

- Then we have the kernel/OS and drivers. 

- On top of that, we might be running a container.

- Then we have our precious JVM.

- And then we have the framework we use, like Spring.

- And lastly, we have... our code.

Just think about how many millions of lines of code are doing stuff before your application gets to print "Hello world".

And I'm not just being dramatic here: the Linux kernel alone clocks in around 30 million lines of code, and the JVM's own codebase - the C++ and Java that make up HotSpot - is itself several million lines before your code even gets a chance to run.

Don't get me wrong, I'm not a huge performance fanatic. I'm not here trying to push everyone to go back to pure metal. But we should acknowledge that there's a lot of "stuff" between our code and the CPU.

But also, this example _IS_ not an exaggeration. If you run on a public cloud or work in a large enough org, it is likely that the machines running Kubernetes are also virtualised, adding millions upon millions of lines of code on top of the ones already running. 

The way I used to think about this was that virtual machines like the JVM aren't compatible with modern development. Why have a machine that runs a virtual machine that runs a container machine, which contains a language virtual machine which runs your code? It sounds very convoluted.

I used to therefore think that something like Go or Rust could help out. Let's cut the virtual machine entirely. Remove one entire abstraction and call it a day.

[Show slide with abstraction stack with VM gone]

This would eliminate several million lines of code from the abstraction tree we got going on here.

But we need to be realistic: Abstractions aren't everything. We can't count them, and we cannot say that "less is automatically more". After all, the JVM helps us out in different ways. It manages our memory, handles our threads, and so forth. There is utility in there that adds value.

So let's think about language machines in a different way. Rather than thinking about them as "something that runs our code", let's think of them as something that can add utility.

[Show fictional VM slide]

Let's come up with a VM which can run in a cluster, on different machines even. And let's say that each process within that VM is this tiny virtual thread, kinda like Kotlin Coroutines or green threads we got in Java 21.

Now, for these threads to communicate, we build messaging into the language and VM itself.

And since we have full control over these processes, we can build supervisors around them for reliability, so they can scale as traffic comes in and handle process failures elegantly. 

Now we've created something pretty different from the JVM. Now we have a VM that is also aware of other instances, where processes within them can communicate. And the thing we created is Beam, which is the VM that Erlang, Elixir and Gleam use.

---

### Why BEAM?

[Show AXD301 slide: 141 nodes, 191 OTP behaviour instances, ~50,000 connections per node]

This is the AXD301: a carrier-class ATM switch shipped in 1998 by Ericsson - the kind of box that sits in a phone network's backbone, routing traffic between exchanges, expected to just stay up indefinitely because it's telecom infrastructure, not a website. And I want that date to actually land: this is eight years before AWS existed, fifteen years before Docker, sixteen before Kubernetes. 

Nobody involved had a cloud provider to lean on, or a container orchestrator to restart a failed instance for them - the reliability had to come from the software itself. It ran over 1.7 million lines of Erlang code, a supervision tree of 141 nodes built from 191 instances of OTP behaviours, handling up to about 50,000 connections per node. This fictional VM we just built up from scratch? It's real, and it ran telecom infrastructure - over a decade before the rest of the industry got serious about this problem.

Given that Beam was built to be a platform, there are cases where we can eliminate Kubernetes as an abstraction altogether. Beam can handle auto-scaling, message handling, data storage, monitoring, and so forth.

Granted, you might want to run other things and other kinds of programs. Beam allows that just fine - Just like the JVM, it will happily run within a container, and many people do so. But the difference is that the threshold for doing so is higher.

And that is the general thing I want to communicate with Beam: The bar for when you feel you have to adopt a new tool is higher.

In modern development, we rely on many dependencies. Our systems need to communicate, so we use HTTP, gRPC, Kafka, MQ, and so forth. All of these come with extra libraries that we often use. We also need to store data, so we use a database or caches like Redis.

Now, before I go further: I don't think dependencies are inherently bad. Kafka is great. Redis is great. If you actually need what they offer, use them, and don't feel bad about it.

But every dependency you adopt has a cost, and that cost is bigger than the line in your build file. It's a team that now needs to run it in production. It's a security review. It's networking, permissions, upgrades, on-call knowledge, and a new thing that can page someone at 3am. That cost is fixed, more or less, whether you need one queue or a hundred. And the question worth asking before you pay it is: how much do I actually need, versus how much am I adopting because it's "just what you do"?

[Move to dependency slide: what do you actually need vs. what does the tool give you]

Say all you need is to fan out one event to a handful of interested parts of your own system - no cross-datacenter delivery guarantees, no exactly-once semantics, just "tell these three things this happened." Do we really need to get half of the organisation involved and aligned on something, or can we get away with writing a little bit of Gleam?

[Show Gleam code for fan-out]

Need it to be persisted? Use the built-in distributed database - it's called Mnesia, and it ships with OTP itself.

Need guarantees of retrivial? Implement a simple "ack" callback. 

In the world of Java, you're more or less forced to adopt some tool. Maybe MQ, maybe Kafka, maybe something else. In either case, you're stuck getting operations on board, figuring out how to run this darn thing in production, setting up the networking correctly, permissions, security, etc. 

In the world of Beam, it all exists within Beam. And since it already exists, that means you don't have to involve a bunch of teams - it is already there. 

Same with a cache. If all you need is to store keys and values, well, you got ETS. It's already there: Built-in. Why mess around with Redis? Again, don't get me wrong: Redis is great, and there are times you might want to use it, but if all you need is a quick, reliable cache? Well, Beam has you covered, and it will get the job done well enough for most of your cases. 

So this isn't "never adopt a dependency," it's "let the size of the problem decide the size of the tool." A fan-out to three subscribers doesn't need Kafka's replication and partitioning story. A quick lookup cache doesn't need Redis's clustering and persistence options. Beam just happens to make the small version of these things cheap enough that you can build it yourself in an afternoon, instead of the smallest available unit being "adopt an entire platform."

But you also see that this slide repeats a word, and if we squint at reality a little, we could say that all of these things could be replaced with OTP.

And what is OTP? OTP stand for "Open Telecom Platform", which sounds really niche, but it really isn't. Don't focus on the word "Telecom", and instead focus on "Platform". 

OTP is essentially a collection of tools, like a database, a KV storage, a debugger and so forth. All the added functionality we've talked about so far is essentially wrapped into this platform.

But to get to OTP, we first need to understand where Beam came from, and to understand Beam, we need to take a little detour to Erlang.

[Switch to Erlang slide.]

Erlang was built all the way back in the mid 80s at Ericsson. The challenge Ericsson had was that they needed a language that could run on telephone switches, where thousands of calls could be established all of a sudden while a bunch of simulation events were going off.

Three people get the credit: Joe Armstrong, Robert Virding, and Mike Williams, working out of Ericsson's Computer Science Laboratory starting around 1986.

[Show language evolution slide: Prolog interpreter → JAM → TEAM → BEAM]

And the language went through a few names before it settled: it started life as a Prolog interpreter, then got compiled into JAM - "Joe's Abstract Machine" - then briefly into something called TEAM, before finally landing on BEAM. Which, if you're wondering, stands for "Bogdan's" or "Björn's Erlang Abstract Machine," depending on who you ask. Nobody seems fully sure, which I personally find delightful.

Not only did the language have to handle all of these calls happening, but on top of that, they had to deal with a bunch of failure modes that could result in calls being disconnected, routing, billing, and so forth. There were a million small things that are really hard to do when you have constant traffic over the wire, and you can't really let a bug drop all calls, nor prevent people from calling just because you gotta do an update.

Now, forwarding to the early 90s and we have the development of Beam, which has seen development ever since!

But let's go back to why Erlang was bult and what Beam had to support. It needed to support a lot of traffic on fairly conservative hardware. It needed to support upgrades without downtime. It needed to handle a lot of tasks at the same time for every caller. Is this that different than what a lot of us have to deal with?

It turns out that a lot of this "telecom stuff" isn't that different than what the web is now, which makes the Beam a pretty compelling thing to build on top of.

[Show AXD301 "nine nines" slide]

This is also where the famous Erlang war story comes from. Ericsson's AXD301 switch, built on top of all this, became legendary for a claimed 99.9999999% availability - nine nines - which works out to about 31 milliseconds of downtime a year. I want to be upfront that this exact number is contested: it traces back to a single customer's marketing slide covering a limited sample of node-years, and even Joe Armstrong's own PhD thesis admits the methodology behind it was never properly documented. So don't take "nine nines" as gospel if you get an argumentative question about it afterwards. What is defensible is that it really was an unusually reliable system, and the architecture behind it - process isolation, supervision, OTP - is the real, lasting lesson, whether or not the exact number holds up.

### Seeing the cluster live

[Terminal 1 visible on screen - the central node]

That's all history, though - I don't want to just claim any of this. Let's actually show you the cluster thing. And we're going to keep it deliberately silly: distributed fizz-buzz.

One node - I'll call it `central` - owns the entire fizz-buzz logic. Every other node knows nothing about fizz-buzz at all. It just sends `central` a number over the network and prints back whatever answer comes.

[Show slide: "if this were Java..."]

Before I show you this actually working, I want to pause on something, because I think it's easy to let this slide past unremarked: what would it actually take to build this exact thing in Java? Not at some hyperscale company - just me, on my own laptop, three separate JVM processes that need to find each other and exchange a message.

I'd basically have three options, and none of them are free.

Option one: Java RMI. It's actually built into the JDK, so credit where it's due - this is the closest Java equivalent of "just call a function on another process." But to get there I need to define a `Remote` interface, extend `UnicastRemoteObject`, and either run the standalone `rmiregistry` process or stand up an embedded one myself in code - either way, I have to explicitly create that registry and explicitly bind my service into it under a name, myself, as application-level work. And then every argument and return value needs to implement `Serializable`, and the classpath needs to line up across every JVM, or you get a runtime error instead of a compile error. It's also, in practice, mostly abandoned - I doubt many of you have touched RMI in years, and Java itself has been quietly deprecating parts of it.

Option two: roll it myself over plain sockets, or HTTP. Now I'm writing my own wire format, or reaching for JSON, defining request/response shapes by hand, correlating requests to replies myself, and writing my own reconnect-and-retry logic for when a node goes away. That's not an afternoon project, that's a small library.

Option three: something like gRPC, or a REST API behind Spring Boot. Genuinely solid, well-trodden tools. But now I need a schema file - protobuf or an OpenAPI spec - a server, a generated or hand-written client, and, critically, *service discovery*: something that tells every other node the IP and port `central` is actually listening on right now. Locally that might be a hardcoded `localhost:8080`, fine for a demo, but the moment this needs to survive `central` restarting on a different port, or moving to a different machine, I'm reaching for Eureka, or Consul, or Kubernetes DNS and Service objects - another whole system to run and operate, just so processes can find each other.

[Show slide: "on Beam..."]

Now, to be fair to Java for a second, before someone in the front row raises a hand: yes, Beam also has something running in the background to make this work. It's called `epmd` - the Erlang Port Mapper Daemon - and it genuinely is its own separate OS process. So let's be precise about what's actually different here, because "there's a background process" isn't the interesting part - both sides have one.

`epmd`'s entire job is dumb and narrow: given a node name, tell me which port it's listening on. That's it. I never start it myself - it launches automatically, exactly once per machine, the first time any Beam node boots there, and every Beam program I ever run on that machine shares that same one instance. I've never written a line of code for it, configured it, or thought about its lifecycle.

The thing that's actually doing `rmiregistry`'s job - "here's a name, tell me where the real service is" - isn't `epmd` at all. It's a module called `global`, and `global` needs zero separate processes, because it's just part of what every Beam node already is. There's nothing to stand up, and nothing to bind my service into by hand beyond a single function call - `global:register_name` - not "deploy and manage a registry."

```sh
erl -name central@127.0.0.1 -setcookie javazone_demo ...
erl -name node2@127.0.0.1   -setcookie javazone_demo ...
```

And once they can see each other, sending a message to a process on another node uses the *same primitive* as sending to a process on your own node - there's no separate "remote call" API to learn, and no serialization step I had to write: the message is a plain custom type,

```gleam
pub type Message {
  Query(reply_to: Pid, number: Int)
  Reply(number: Int, result: String)
}
```

and because every node is running byte-identical compiled code, that value crosses the network as itself and comes out the other side as the exact same typed value - no DTOs, no JSON, no protobuf schema, nothing to keep in sync by hand. (Don't worry about the exact syntax there yet - we'll get to actual Gleam properly in a minute. For now just notice: no annotations, no interface, just a plain data shape.)

[Terminal 1, 2, 3 visible on screen - central plus two query nodes]

So let's actually run it. `central` starts up and calls `global:register_name` for itself, under a well-known name. Two other nodes, `node2` and `node3`, start up, look that name up the same way, and start asking it numbers, once or twice a second, forever.

[Show terminals: colour-coded output, node2 and node3 printing "asked about N -> ..."]

Every line you're seeing here crossed a real network hop between separate operating system processes. Nothing here is simulated.

[Show :observer attached to central - Nodes tab, then process list]

I've also got Erlang/OTP's built-in `:observer` open here, attached to `central`. It ships with the runtime, no extra install - and it shows you, live, on a real running node: which other nodes are connected, the process list, mailbox sizes, memory. Watch the "Nodes" tab: `central`, `node2`, `node3`, all present.

[Optional: run scripts/run-swarm.sh 20 - a wall of new nodes joining]

And since the whole mechanism here is "any node that knows the name and the cookie can join in," it costs me nothing to stop pretending this only works for two or three nodes. Watch this:

```sh
scripts/run-swarm.sh 20
```

Twenty more nodes, started all at once, each independently finding `central` and starting to query it - no configuration change, no code change, nothing extra to deploy. Look at the "Nodes" tab again: twenty-one nodes now, all connected, all talking.

[Kill central's terminal]

Now, the part I actually want you to watch closely. I'm going to kill `central`. Not `node2`, not one of the twenty swarm nodes - the one node every single other node depends on.

[Show query node terminals: "fizzbuzz server not reachable, retrying..."]

Every querying node notices within a second or two, and every one of them does the same thing: it stops, and it waits. It does *not* silently skip ahead and start counting as if nothing happened - it keeps retrying the exact same question it was asking when `central` disappeared. Nobody wrote a retry-with-backoff library for this; it falls straight out of "if the process I'm registered-named isn't there, I don't have anyone to send to yet."

[Restart central: scripts/run-central.sh]

And now I bring `central` back.

[Show query node terminals resuming from the exact same number]

Watch: every node reconnects and resumes from *exactly* the number it was stuck on - not from 1, not skipping ahead. And I want to be precise about what just happened, because it's easy to wave your hands here: that `central` process is not the same process that died. It's a brand new one, a new pid, with no memory of anything that came before. Nobody migrated state, nobody restored a session. The only thing that made this recovery possible is that every query node keeps re-asking "who is `central` right now?" instead of caching an answer from thirty seconds ago.

Compare that to the Java version from a minute ago: that's the same class of problem as "my service registry entry went stale" or "my client cached a connection to a pod that Kubernetes already replaced" - a real, well-known class of distributed-systems bug, and here it disappears because location was never something we hardcoded in the first place.

(Speaker note: rehearse this end-to-end at least once on conference wifi before the actual talk - live clustering demos are exactly the kind of thing that breaks in front of an audience. Have a screen recording as a fallback in case the network does something weird. Also worth knowing: this demo's own code intentionally drops down to a couple of raw Erlang primitives - `global` and a plain, untyped send/receive - for the cross-node wiring specifically, because Gleam's own typed `Subject`/`Name` abstraction is built for processes already sharing one supervision tree, not for "a completely separately-started node wants to address me by name." Worth saying out loud if asked: this is the same raw, untyped mailbox layer Gleam usually protects you from, used on purpose for this one seam.)

[Show "what you can steal" slide: Beam ideas next to their closest JVM equivalent]

So, stepping back from the demo: what can we actually take from all this without leaving the JVM behind? You obviously can't rip the JVM out from under your application the way we just did on a slide. But you can steal the instinct: reach for what's already running in your own process - an in-memory cache like Caffeine, the structures already in `java.util.concurrent`, an embedded database like SQLite or H2 - before you reach for Redis or Kafka or an MQ for something genuinely small. Same "why do I need to involve three more teams for this" argument applies, Beam or no Beam.

And on concurrency specifically: Java 21's virtual threads are the closest thing the JVM has to Beam's cheap processes for I/O-bound work, so that's a real, concrete piece of this you already have access to today. But I do want to be straight with you about one real gap, because someone in this room definitely knows their Loom internals: Beam's scheduler preempts every process on a fixed budget - "reductions" - so no single process can ever starve the others. Java's virtual threads don't give you that guarantee - a CPU-bound one can still hog its carrier thread. That's a genuine architectural difference, not just Beam being older and more mature.

___

### Let's learn some Gleam

So we have this very cool VM that can do some neat stuff, but we need a language on top. The original language was Erlang, but a lot of people find Erlang to be a little esoteric for those of us that is used to the C-family of languages.

Then we have Elixir. A more modern take that borrows a lot of its ideas from Ruby. I really like Elixir, but I like to work with staticly typed languages. I enjoy using typing to make some conditions impossible. While Elixiri has a pretty good gradual type system, it isn't really as strict as I want.

No, for me, the choice was Gleam. 

[Move to Gleam slide: creator, timeline, compiles to Beam + JavaScript]

Gleam is the language that "felt right" from the beginning, but it's not all about syntax. After all, I'm the kind of person which has part of his website written in Clojure.

For those wondering what we're actually talking about: Gleam was created by Louis Pilfold, starting back in 2016, and it only hit its 1.0 release in March of 2024. So if you haven't heard of it, that's completely fair - it's genuinely young. It's statically typed, and it compiles to both Beam bytecode and to JavaScript, so it's not just "another Erlang-family language" - it can just as easily target your browser or Node as it can a Beam cluster.

And that JavaScript target isn't just a curiosity. It means the exact same Gleam code - your types, your validation logic, your domain model - can run on your backend on the Beam and in the browser, compiled to JS. One language, one type system, both ends of a fullstack app. I won't go deep on that today, but it's worth knowing it's there.

---

### A taste of the syntax

[Show basic Gleam function slide]

Before we go further, let's actually look at some code, because I don't want to just tell you Gleam has "modern syntax" and expect you to take my word for it.

```gleam
pub fn double(x: Int) -> Int {
  x * 2
}
```

Nothing scary. A public function, a typed parameter, a typed return value. If you've touched Kotlin or TypeScript, this reads itself.

Now, remember right at the start I asked: what do you do in a language with no loops? No if-statements? Here's the actual answer.

[Show case-expression slide: pattern matching instead of if]

Gleam doesn't have an `if` statement in the way Java does. It has `case`, which is pattern matching:

```gleam
pub fn describe(n: Int) -> String {
  case n {
    0 -> "zero"
    n if n > 0 -> "positive"
    _ -> "negative"
  }
}
```

You're not writing a chain of conditions and hoping you covered every branch - you're matching against shapes, and as we just saw with custom types, the compiler will tell you if you missed one.

[Show recursion / list.fold slide: no for-loop needed]

And no loops? Two ways this gets solved. You can write a recursive function:

```gleam
pub fn sum(numbers: List(Int)) -> Int {
  case numbers {
    [] -> 0
    [first, ..rest] -> first + sum(rest)
  }
}
```

Or, more commonly in real Gleam code, you reach for the standard library and a pipe:

```gleam
import gleam/list

pub fn total(numbers: List(Int)) -> Int {
  numbers
  |> list.fold(0, fn(acc, n) { acc + n })
}
```

That `|>` is the pipe operator - it just passes the thing on its left into the first argument of the function on its right. Once you get used to reading top-to-bottom data pipelines instead of nested function calls, it's hard to go back. And notice there's no mutable accumulator variable you're updating in place anywhere in that code - everything here is immutable by default. You're not looping and mutating a counter; you're transforming a value into a new value, every step of the way. That's the "functional" part of "statically-typed, functional, immutable" earning its keep, not just a label on a slide.

### Typing

[Show Gleam custom type slide: a closed set of variants]

Let's talk about types for a second, because this is where a lot of Gleam's "aha" moments live for someone coming from Java or Kotlin.

Gleam has what it calls custom types - basically algebraic data types, or what you might know as sum types. You define a type as a closed set of variants, and the compiler knows about every single one of them.

```gleam
pub type PaymentResult {
  Approved(transaction_id: String)
  Declined(reason: String)
  NetworkError
}
```

That's the whole type. Not "an object that might have a transaction ID, or might have a reason, or might be null, depending on what happened" - three explicit, named possibilities, and nothing else is allowed to exist.

[Show exhaustive pattern match example]

The neat part is what happens when you pattern match on one of these:

```gleam
pub fn describe_payment(result: PaymentResult) -> String {
  case result {
    Approved(id) -> "Payment approved: " <> id
    Declined(reason) -> "Payment declined: " <> reason
    NetworkError -> "Could not reach the payment provider"
  }
}
```

If you forget to handle one of the variants - say you delete the `NetworkError` branch - Gleam simply won't compile. Not a warning, not a runtime surprise three months later when that code path finally gets hit in production - a compile error, right there, right now.

If that sounds familiar, it should - Kotlin has sealed classes and sealed interfaces plus exhaustive `when` expressions, and Java has had sealed interfaces plus pattern matching for `switch` since Java 17, with exhaustiveness checking since Java 21. This isn't some exotic Gleam-only trick. The tools are already sitting in your JVM toolbox.

[Show slide: "making illegal states unrepresentable"]

But a closed set of variants is really only half the story, and I want to push this further, because this is the actual thing I want you to walk out of here with. The bigger idea is: you can drive correctness through the type system itself, so that misusing an API isn't just discouraged - it's impossible. Not "please validate this before you call me." You *cannot* call me with a bad value, because a bad value of this type cannot exist in the first place.

Here's the shape of the problem this solves. Say I need an email address somewhere in my code. The lazy version is `String`. But a `String` can be `"lol"`, or empty, or garbage - and now every function that receives it either has to re-validate it, or trust that whoever called it already did. That trust is exactly where bugs live: someone, somewhere, eventually forgets.

[Show Gleam opaque type + smart constructor]

Gleam's answer is the `opaque` modifier on a custom type:

```gleam
pub opaque type Email {
  Email(String)
}

pub fn parse(input: String) -> Result(Email, String) {
  case is_valid_email_format(input) {
    True -> Ok(Email(input))
    False -> Error("not a valid email address")
  }
}
```

"Opaque" means exactly one thing: outside this module, nobody can construct an `Email` directly, and nobody can pattern-match into it to peek at the raw string either. The *only* door in is `parse`, and that's the one place the validation logic lives. Every function elsewhere in the codebase that takes an `Email` is now, by construction, guaranteed to have received something that already passed that check. Not "probably." Guaranteed. There is no other code path that produces an `Email`.

[Show chained validation: Email -> RegisteredEmail -> VerifiedEmail]

And this composes. Say "valid format" alone isn't enough - I also need to know this email belongs to a real registered user, and beyond that, that they've actually verified it. Rather than one type with a growing pile of boolean flags, I chain types, each one only obtainable from the one before it:

```gleam
pub opaque type Email { Email(String) }
pub opaque type RegisteredEmail { RegisteredEmail(Email) }
pub opaque type VerifiedEmail { VerifiedEmail(RegisteredEmail) }

pub fn parse(input: String) -> Result(Email, String) { ... }

pub fn find_registration(email: Email) -> Result(RegisteredEmail, String) { ... }

pub fn require_verified(reg: RegisteredEmail) -> Result(VerifiedEmail, String) { ... }

pub fn send_password_reset(to: VerifiedEmail) -> Nil { ... }
```

`send_password_reset` isn't a web endpoint - it's just an ordinary function, callable from anywhere in the codebase. But by the time anyone can call it, the type of that one argument is already proof - checked by the compiler, not a comment or a unit test - that this string is well-formatted, belongs to an actual registered user, and has been verified. Three separate facts, earned in order, carried in a single value, with no risk of skipping a step. This is what I mean by "internal API" - not a REST endpoint with a validation filter in front of it, just a plain function signature that makes an entire category of bug physically impossible to compile.

[Show phantom type: Order state machine]

Gleam lets you push this one step further with a phantom type - a type parameter that never actually shows up in the data at runtime, it exists purely to carry a compile-time fact:

```gleam
pub opaque type Order(status) {
  Order(id: String, items: List(String))
}

pub type Draft
pub type Paid

pub fn create(items: List(String)) -> Order(Draft) {
  Order(id: new_id(), items: items)
}

pub fn pay(order: Order(Draft), payment: Payment) -> Result(Order(Paid), String) {
  ...
}

pub fn ship(order: Order(Paid)) -> Nil {
  ...
}
```

`Draft` and `Paid` never appear anywhere inside the actual `Order` record - there's no runtime status field, no boolean, nothing to check or forget to check. It's purely a label the compiler tracks on your behalf. And that's enough to make `ship(some_draft_order)` a compile error, full stop. You cannot ship an order that was never paid for, and the proof of payment isn't a database flag someone might query wrong - it's the type of the value sitting in your hand.

[Show slide: "so what about Java?"]

Now here's the actual point I want to land, because I don't want this to sound like "and that's why Gleam is better." Java has classes. And a class with a private constructor plus a static factory method that validates before ever handing you an instance does *exactly* the same job as Gleam's opaque type and smart constructor:

```java
public final class Email {
    private final String value;

    private Email(String value) {
        this.value = value;
    }

    public static Optional<Email> parse(String input) {
        return isValidFormat(input)
            ? Optional.of(new Email(input))
            : Optional.empty();
    }
}
```

Same guarantee. The private constructor is the opaque type. The static factory is the smart constructor. If `sendPasswordReset` takes an `Email` object instead of a `String`, you have exactly the same compile-time proof Gleam gave you - it's just spelled with a class instead of a case expression. Even the chained-validation trick and the phantom-type trick translate: a `RegisteredEmail` class whose only constructor accepts an already-validated `Email`, or a generic type parameter on a builder that never appears in a field, purely tracking a compile-time-only state.

So the bigger habit to steal isn't "use opaque types" or "use sealed classes" - those are just the local dialect. It's this: stop trusting whoever calls your function to have validated their input, and stop re-validating it defensively inside every function either. Push the check to exactly one place - the boundary where the value is created - and let the type system carry that proof everywhere downstream, for free, forever, in whichever paradigm you're standing in.

[Show slide: anemic domain model vs. this]

And this is exactly what goes wrong in what's sometimes called an anemic domain model, or a transaction script architecture - the very common shape where your "domain objects" are just data bags, getters and setters, maybe a record, with zero logic of their own, and all the actual business rules live off to the side in some `EmailService` or `OrderService` that every caller has to remember to invoke, in the right order, every single time. That's not an OOP-versus-functional problem - you can absolutely write Gleam the anemic way too, passing bare strings and ints around with a pile of validation functions nobody's forced to call. The fix is identical in either paradigm: whoever owns the data should own the correctness of that data. Not the caller. Not a service three layers away you're trusting to remember. The type itself.

If you want the longer version of this, with more examples, I wrote it up in more depth on my site - lindbakk.com, look for "Ensuring Correctness Through the Type System." But the one-sentence version is the thing to take home: drive non-trivial correctness through your types, in whichever language you're standing in, so that misuse isn't just discouraged - it's impossible.

### Errors when there are no exceptions

Another thing about Gleam is that it has no exceptions. In Java we throw exceptions all over the place! A field not formatted the way we like? Exception! A number that is negative that shouldn't be negative? Exceptions! The database returning two things instead of one? Exceptions!

In the Java-world we essentially use exceptions as a hidden return type, wich is what they are unless you use checked exceptions... and those annoy most people, so it seems like most just opts out of that.

Therefore we end up in a situation where exceptions becomes this secret thing that might happen that just breaks the flow of the application. I don't like that. Especially not when dependencies use the same pattern and may decide to just blow up your applicatio.

I prefer developers having to decide whether or not to propegate an error. Doing so forces developers to make an active decision, which is healthy.

And to be clear, this isn't some wild idea unique to Gleam or Erlang. Go does it with its `(value, err)` return pattern. Rust does it with `Result<T, E>`. Swift has typed throws now too. Modern language design has largely made this bet already - Java is actually the outlier here for still leaning so hard on unchecked exceptions.

Gleam solves this by having errors as values.

[Slide to Result type]

Gleam uses a `Result` type, which is essentially a typed Tuple or Pair. It has one result in case there's a success, and one if there's a failure. 

To get to the success response we must also make a decision about what to do in case there's an error. In other words, we have to manage failure.

I reckon most seasoned developers have had the scenario where a 500 HTTP response has been thrown, or the application has simply quit because it crashed due to an uncaught exception. This is not rare in the world of Java when all we use is unchecked exceptions. It has been culturaly acceptable to risk the operability of our systems because we don't want to deal with the errors.

Frameworks like Spring also assumes this, so they run the try-catch for us and formats the exception to the best of their ability, which is great, but also kinda unfortunate. Why can't we have control over our own code?

There's a distinction worth being precise about here, because it's easy to lump "errors" and "exceptions" together as the same thing when they're not. An error is something expected - a user typed in a bad phone number, a lookup came back empty, an external API said no. A defect is something unexpected - a null reference, an index out of bounds, a bug. `Result` is built for the first category. It is deliberately not meant to replace the second - Gleam and Erlang still crash on those, hard, on purpose. That's exactly what "let it crash" is for, which is coming up next.

There is a meaningful distinction here though: Errors we can recover from get modelled as values and handled explicitly. Defects we can't meaningfully recover from get left to crash the process, on purpose, and dealt with structurally instead of defensively.

[Show Kotlin equivalent: Result<T> / Arrow Either]

- Show Kotlin

The concrete move for your own code: for that first category - expected, recoverable failures like parsing, validation, or an external call that can legitimately fail - stop throwing for control flow, and return a value instead. Kotlin's stdlib already ships a `Result<T>`. Arrow gives you `Either`. Or just roll your own `sealed interface ApiResult<T>` with a `Success` and a `Failure` case. Combine that with the exhaustive `when` we just talked about, and the compiler forces every caller to handle both branches - you get Gleam's "you must decide" guarantee without leaving the JVM.

### Let it crash

Remember, back when we talked about Beam, I killed a whole node live and every other node just kept going, no null checks, no crash? That was this exact philosophy, one level up. Let's zoom in to the scale of a single process.

"Let it crash" has been the mantra for Erlang since the 80s. The idea behind is that the world is messy, things happen and the unexpected will occur. Therefore, rather than building systems that assumes perfect conditions, we instead build systems where it is expected that things will crash.

So what does that mean in practice?

In the world of Gleam and Beam that means having supervisors watching over smaller worker threads. Like for example you might have worker threads that serves HTTP requests. If one of them dies, the supervisor will create a new one.

Since these are tiny processes, the restart is near instant, and no real downtime impacts the end user.

Remember that we are talking about excetions here: The things we cannot meaningfully recover from, not even with Spring wrapped around it.

In the world of Java we would see a total failure that takes down the entire VM. We'd usually run this in something like Kubernetes which would discover the crash and spin up a new container, but now we're looking at the start of the container itself and a complete fresh start of the JVM and whatever Spring needs to do on startup.

This is mostly fine when running multiple instances and only one of them crashes, but it can have cascading effects as the time it takes for one instance to recover can impact other instances.

[Show AXD301 supervision tree: flat vs. deeply nested]

Now, a fair question: doesn't this same cascading problem exist on Beam too, just with supervised processes instead of containers? Yes, and it's worth being honest about that rather than pretending "let it crash" is magic. Ulf Wiger, the AXD301's chief software architect, found exactly this: restarting a failed process's entire supervision subtree can itself trigger cascading failures. It's actually why the real AXD301 supervision trees ended up deliberately flat, rather than the deeply nested trees you tend to see in textbook diagrams. OTP also has a specific mechanism to cap this: "restart intensity" - a supervisor will give up and escalate the failure upward if a child keeps restarting too many times within a time window, instead of looping forever.

So the honest answer is: the problem doesn't disappear, but Beam gives you first-class, tunable primitives to contain it - restart strategies, intensity limits, flat supervision by design. A Kubernetes pod restart is a much blunter instrument by comparison. "Let it crash" isn't optimism, it's a philosophy backed by specific, tunable mechanisms.

[Show structured concurrency slide: StructuredTaskScope / supervisorScope]

You can't get true per-process isolation on the JVM - everything still shares one heap - but you can borrow the shape of the idea. Java 21's structured concurrency, via `StructuredTaskScope`, and Kotlin's `supervisorScope`, both let you isolate a failing child task so it doesn't drag its siblings or its parent down with it. The concrete change is to design your worker pools and coroutine scopes explicitly around "one bad task fails alone," instead of letting one uncaught exception unwind an entire request. And that restart-intensity idea - give up and escalate after N failures in a time window, instead of retrying forever - is a genuinely missing ingredient in a lot of hand-rolled Java retry loops I've seen. Worth stealing even if you never touch a supervision framework.

### Size matters

[Show size matters slide]

// Do "size matters" joke, call out the audience

[Show language size matters slide]

It is LANGUAGE size that matters! And it genuinly does matter!

This is something I first discovered when learning Clojure. For those who doesn't know, Clojure is a lisp dialect, and Lisp is a language that is as small as it can get, yet allow you to write complex, working and reliable software. It casts a stark contrast to other languages with much more complexity built-in.

Gleam is also a small language. It only has 22 reserved keywords. That is in stark difference to Java which has 68, or Kotlin with over 70. Not to speak about C# that is edging on 80.

[Show keyword count slide, with methodology footnote]

Now, a quick honesty check on that number before it goes on a slide: "keyword count" is a little fuzzy. Java's own language spec lists around 53 true reserved words. It only creeps up toward the high 60s or 70s once you also count reserved literals like `true`, `false`, and `null`, plus contextual keywords like `var`, `yield`, `record`, `sealed`, and `permits` - which are only keywords in specific positions, not everywhere. So to keep this comparison fair: I'm counting JLS reserved words as of Java 21 against Gleam's 22. Same ruler, both languages.

So why does this matter?

One could assume that "more keywords" would mean more flexibility. More room for the developer to express themselves and do things they mean is right. And that is true, but that also opens the door to inconsistencies within the application and ecosystem as a whole.

More importantly, for me, is that a large language often tries to do much and generally lacks opinion on what the "correct" way of coding is. For example, Kotlin is built its reputation by being a "better Java" by simplifying syntax and enabling more functional programming patterns. But is this a good thing?

And here's the thing - we're basically back to where we started tonight. This is the same worry I opened with about "cultural truths": more surface area in a language means more ways to do the same thing, which means less consistency across a codebase and a team. A big, opinionated standard library isn't automatically a bad thing, but it's worth noticing when "more flexibility" quietly turns into "everyone does it differently."

[Show "small language, big discipline" slide]

You obviously can't shrink Java's keyword count. But you can shrink your team's effective language surface - a style guide, an architecture decision record, a linter rule in ktlint or detekt or Checkstyle that bans a specific construct or picks one idiom per problem. That's "small language" discipline, imposed on top of a large language, by choice. Pick one rule like that per review cycle, and consistency stops being a vague aspiration.

### Wrapping up

[Show shared-nothing / immutability slide]

Before we close, two things I've been dancing around all talk that deserve to be said outright.

First: everything we've talked about with processes and message passing only works because data in Erlang and Gleam is immutable by default, and processes share absolutely no memory with each other. That's the actual reason whole categories of concurrency bugs - races, torn reads, some other thread quietly mutating state out from under you - simply can't happen on Beam in the first place. It's also, honestly, the single most directly useful habit you can steal tonight even if you forget everything else: prefer `val` over `var`, reach for data classes and records, use persistent/immutable collections, and treat shared mutable state as the thing you actively design away from, not the default you fall back into.

[Show hot code upgrade slide]

Second: remember right at the start, when I said Ericsson needed a language that supported upgrades without downtime? Beam actually delivers on that, literally - you can swap the code running on a live node without dropping a single connection. It's one of the most distinctive things about this whole ecosystem, and it's the actual reason Erlang exists in the first place: telecom switches couldn't just go down for a deploy. I'll be straight with you though: it's operationally fiddly in practice, and plenty of Elixir and Gleam shops just do blue/green deploys instead, same as you would on the JVM. So take it as a "here's what's possible," not a "here's what everyone actually does."

[Show summary slide: what to steal for Monday]

So, if you walk out of here with nothing else, walk out with this list: model your state with sealed types instead of nulls and flags. Return errors as values for the failures you expect, and save exceptions for the ones you don't. Design your concurrency around "one failure shouldn't take everyone down with it." And treat immutability as the default, not the exception. None of that requires you to touch Gleam, or Beam, or ever leave the JVM. But it's exactly the kind of thing you only notice you're missing once you've looked at a language that doesn't let you get away without it.

Thank you.
