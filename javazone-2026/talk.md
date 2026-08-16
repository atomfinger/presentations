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

Let's come up with our own VM. Let's call it Cool-VM™.

The first decision we make is that it is functional and immutable. Why? Because those things are neat.

We also know that we have pretty beefy processors these days, so we should utilizw that. So let's optimise Cool-VM™ for tiny virtual threads, kinda like Kotlin Coroutines or green threads we got in Java 21.

We do want to keep things tidy. We don't want threads to crash each other, so to keep things safe, we won't allow state to be shared. Instead, we'll only allow them to communicate through passing messages back and forth, not unlike MQ. And we'll make message passing a first-class citizen of the language we're putting on top.

And since we have full control over these processes, we can build supervisors around them to ensure reliability, so they can scale as traffic comes in and handle process failures gracefully. That means that if an "instance" of our code blows up, then a new one will be spun up automatically.

We also know that we live in a world where we have multiple systems wanting to communicate, so why not just allow different instances of our Cool-VM™ join together into a cluster?

Given that we also have a working cluster, let's make things a little easier to use. Let's add some common things we know that we will need, like service discovery, maybe a cache... and heck, let's throw in a database for good measure.

Our Cool-VM™ is starting to look mighty powerful, and given its utility, we can now look at how this impacts our abstraction stack:

[Show slide with abstraction stack again]

Previously, we managed to eliminate the language VM by compiling directly to machine code, but now there's a third way to think about this. Assuming the language VM is sophisticated enough, it might also replace things like the container or Kubernetes:

[Show slide with abstraction stack with VM-instead-of-container]

Now we've created something pretty different from the JVM. Now we have a VM that is also aware of other instances, allowing processes to communicate. And the thing we created is Beam, the VM that Erlang, Elixir, and Gleam use.

Just to be clear: You can still run BEAM and Gleam within a container, just as you can with the JVM. A lot of people do this, and it works equally well.

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

___

### Let's learn some Gleam

Alright, for the thing we've all been waiting for: Gleam. Let's look at it.

We have our cool VM, but we need a language on top. The original language was Erlang, but a lot of people find Erlang to be a little esoteric for those of us that is used to the C-family of languages.

Then we have Elixir. A more modern take that borrows a lot of its ideas from Ruby. I really like Elixir, but I like to work with staticly typed languages. I enjoy using typing to make some conditions impossible. While Elixiri has a pretty good gradual type system, it isn't really as strict as I want.

No, for me, the choice was Gleam. 

[Move to Gleam slide: creator, timeline, compiles to Beam + JavaScript]

Gleam is the language that "felt right" from the beginning, but it's not all about syntax. After all, I'm the kind of person which has part of his website written in Clojure.

For those wondering what we're actually talking about: Gleam was created by Louis Pilfold, starting back in 2016, and it only hit its 1.0 release in March of 2024. So if you haven't heard of it, that's completely fair - it's genuinely young. It's statically typed, and it compiles to both Beam bytecode and to JavaScript, so it's not just "another Erlang-family language" - it can just as easily target your browser or Node as it can a Beam cluster.

And that JavaScript target isn't just a curiosity. It means the exact same Gleam code - your types, your validation logic, your domain model - can run on your backend on the Beam and in the browser, compiled to JS. One language, one type system, both ends of a fullstack app. I won't go deep on that today, but it's worth knowing it's there.

---

### A taste of the syntax

[Show demo snippet on screen - walk through live with arrows: main, greet, describe_age]

Before we get into the bigger ideas, let's actually look at real code, because I don't want to just tell you Gleam has "modern syntax" and expect you to take my word for it.

```gleam
import gleam/io

pub fn main() {
  let message = greet("Alice")
  let category = describe_age(27)

  io.println(message)
  io.println("Category: " <> category)
}

fn greet(name: String) -> String {
  "Hello, " <> name
}

fn describe_age(age: Int) -> String {
  case age >= 18 {
    True -> "adult"
    False -> "minor"
  }
}
```

(Walk through this live with arrows: `main` calling two small functions, `<>` for string concatenation, typed parameters and typed return values on every function. If you've touched Kotlin or TypeScript, most of this already reads itself.)

### If statements? Not quite.

Remember right at the start, I asked: what do you do in a language with no `if` statement? `describe_age` is the answer. Gleam doesn't have `if` the way Java or Kotlin does - it has `case`, which is pattern matching:

```gleam
case age >= 18 {
  True -> "adult"
  False -> "minor"
}
```

Here it's just matching on `True`/`False`, so it looks almost like an `if`. But it's the exact same mechanism we're about to see doing a lot more work - matching against shapes, not chaining conditions you have to trust yourself to get right, with the compiler checking you covered every case instead of you just hoping you did.

[Show fizzbuzz slide]

Let's push it a little further with something everyone already knows the rules to: fizzbuzz.

```gleam
import gleam/int

pub fn compute(n: Int) -> String {
  case n % 15, n % 3, n % 5 {
    0, _, _ -> "FizzBuzz"
    _, 0, _ -> "Fizz"
    _, _, 0 -> "Buzz"
    _, _, _ -> int.to_string(n)
  }
}
```

`case` isn't limited to matching one value at a time - here it's matching on three at once: `n % 15`, `n % 3`, and `n % 5`, all in the same expression. The underscore `_` means "I don't care what this one is." Read it top to bottom: divisible by 15, and the other two columns don't matter - "FizzBuzz". Otherwise check 3, then check 5. Otherwise, fall through to the plain number. Four branches, no nested if-else, and no "divisible by 3 and divisible by 5" duplicated by hand to fake the fizzbuzz case - the compiler still won't let you leave one of those branches out, same exhaustiveness guarantee as before, just with more moving parts.

[Show fizzbuzz-with-guards slide]

And `case` has one more trick worth showing, because it's easy to assume pattern matching only means "match this exact shape." It also does conditions, via a guard:

```gleam
pub fn compute(n: Int) -> String {
  case n {
    n if n % 15 == 0 -> "FizzBuzz"
    n if n % 3 == 0 -> "Fizz"
    n if n % 5 == 0 -> "Buzz"
    _ -> int.to_string(n)
  }
}
```

Same fizzbuzz, same result, different shape: instead of matching on a tuple of three remainders, this matches on `n` itself, and each branch adds an `if` after the pattern - "bind this to `n`, but only take this branch if the condition holds." It reads almost like a normal `if`/`else if`/`else` chain again, except it's still one exhaustive `case`, the compiler still enforces that final catch-all `_`, and you're not nesting anything. Which style you reach for is mostly taste - the point is that `case` covers both "what shape is this" and "what's true about this," in the same construct, instead of needing a separate `if` for one and a `switch` for the other.

And loops? Same story - no `for`, no `while` either. Two ways to fill that gap. Write the recursion yourself:

```gleam
pub fn sum_recursive(numbers: List(Int)) -> Int {
  sum_loop(numbers, 0)
}

fn sum_loop(numbers: List(Int), acc: Int) -> Int {
  case numbers {
    [] -> acc
    [first, ..rest] -> sum_loop(rest, acc + first)
  }
}
```

Written this way on purpose: `sum_loop` calling itself is the very last thing that happens in that branch, nothing left to do once it returns. That's a genuine tail call, and the BEAM compiles a tail call into a jump, not a new stack frame - this runs in constant stack space no matter how long the list is. Or reach for the standard library, which already did the recursion for you:

```gleam
import gleam/list

pub fn sum_builtin(numbers: List(Int)) -> Int {
  list.fold(numbers, 0, fn(total, n) { total + n })
}
```

Same signature, same result, either way. In practice you almost always reach for the second one - `list.fold`, `list.map`, `list.filter` cover most of what a `for` loop would've done - and keep the hand-written recursion for the cases the library doesn't already have a name for.

### Typing

[Show Gleam custom type slide: a closed set of variants]

We have types in Java, so this is noything new to us, but I rarely see types being used to truly enforce correctness. Typing is much more than just checking if a paramtere is an int or a string, or type of class A. It is a tool we can use in our architecture to build reliable systems. In short: We can use types to make undesirable states impossible.

Gleam has what it calls custom types - basically algebraic data types, or what you might know as sum types. You define a type as a closed set of variants, and the compiler knows about every single one of them.

```gleam
pub type PaymentResult {
  Approved(transaction_id: String)
  Declined(reason: String)
  NetworkError
}
```

Here we should differentiate what a type is vs an object. There are no methods attached to these types. `Approved` is more or less a what we would call a struct or a named map.

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

If you forget to handle one of the variants - say you delete the `NetworkError` branch - Gleam simply won't compile. You won't get any further unless you cover all of the possible cases.

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

Gleam has no exceptions. No `throw`, no `try`/`catch`. Errors are just values - `Ok` or `Error`, the same closed, two-variant custom type shape we just saw, built straight into the language. Not a new idea either: Go does the same thing with `(value, err)`, Rust with `Result<T, E>`.

This is basically Java's checked exceptions, and I mean that as more of a compliment than most people intend it. Checked exceptions had the right instinct - force the caller to deal with this - it just got a bad reputation because Java lets you cheat: wrap it, slap `throws Exception` on it, catch-and-swallow. Gleam's version keeps the same annoying-up-front honesty, minus the escape hatches. There's no `throws` clause to widen your way out of.

[Show parse_age slide]

```gleam
import gleam/int

pub fn parse_age(input: String) -> Result(Int, String) {
  case int.parse(input) {
    Ok(age) if age < 0 -> Error("Cannot have negative age")
    Ok(age) -> Ok(age)
    Error(Nil) -> Error("\"" <> input <> "\" is not a number")
  }
}
```

One `case`, three branches, each one a different reason the input could be bad - a guard clause (`if age < 0`) attached right to the pattern, same trick from the fizzbuzz slide earlier. And to get anything out of this at all - the number, or the reason it failed - the caller has to handle every branch. That's not a style guide rule someone can skip under deadline pressure; the compiler won't let you touch the value without going through all three sides first.

[Show `use` slide: chaining several steps]

That's one function with one thing that can fail. What about several, chained together? That's where a bit of syntax called `use` earns its keep - here's the Email → RegisteredEmail → VerifiedEmail chain from earlier, actually wired together (every step's still a stub - I'm not faking a real email regex on a slide):

```gleam
import gleam/result

pub fn reset_password(input: String) -> Result(Nil, String) {
  use email <- result.try(parse(input))
  use registered <- result.try(find_registration(email))
  use verified <- result.try(require_verified(registered))
  Ok(send_password_reset(verified))
}
```

One line per step, reading top to bottom like a script: run this, and if it fails, stop right here and hand back that error - otherwise unwrap the value and keep going with everything below it. No nesting, no `case` inside a `case`. If `parse` fails, `find_registration` never runs at all.

[Show Kotlin equivalent]

```kotlin
sealed interface ParseResult
data class Parsed(val age: Int) : ParseResult
data class ParseFailed(val reason: String) : ParseResult

fun parseAge(input: String): ParseResult {
    val age = input.toIntOrNull() ?: return ParseFailed("\"$input\" is not a number")
    return if (age < 0) ParseFailed("Cannot have negative age") else Parsed(age)
}
```

Same shape, same guarantee, just spelled with a `sealed interface` and an early return instead of a `case`. Kotlin's stdlib also ships a plain `Result<T>` if you don't want to declare your own type for this.

[Show Java equivalent]

And in case you're thinking this is a Kotlin-only trick - it isn't, plain Java gets you there too, since Java 21:

```java
sealed interface ParseResult permits Parsed, ParseFailed {}
record Parsed(int age) implements ParseResult {}
record ParseFailed(String reason) implements ParseResult {}

static ParseResult parseAge(String input) {
    try {
        int age = Integer.parseInt(input);
        return age < 0 ? new ParseFailed("Cannot have negative age") : new Parsed(age);
    } catch (NumberFormatException e) {
        return new ParseFailed("\"" + input + "\" is not a number");
    }
}
```

`sealed interface` plus a couple of `record`s is Java's version of the same closed, two-shape type - and if you match on a `ParseResult` with a `switch` over `Parsed`/`ParseFailed`, the compiler demands both branches, same exhaustiveness guarantee as everywhere else today. One honest wrinkle worth naming out loud: `Integer.parseInt` still throws, because the standard library predates all of this - so the `try`/`catch` at the very boundary is genuinely still the cleanest option Java gives you. The point isn't that the exception never happens; it's that it gets caught immediately, right here, and converted into a value before it ever gets a chance to propagate anywhere - nothing downstream of `parseAge` ever sees a `NumberFormatException`, only a `ParseResult` it's forced to handle. Both mainstream JVM languages already have everything they need for this - today, not eventually.

[Show the stack-unwinding slide - Main / Method / Fragile Method]

Here's the actual reason any of this matters. Exceptions don't return, they unwind: a failure three frames down skips straight past everything in between and lands wherever the nearest `catch` happens to be. None of the skipped frames get a say, or even necessarily know it happened.

A `Result` never skips anything. It goes up exactly the way every other return value does - one frame at a time - and every function in between stays in control: it looks at what came back and decides, explicitly, what to do next. Nothing invisible, nothing jumping over your code. You can understand what a function does by reading that function, not by knowing every `catch` block sitting above it in the call stack.

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

[Show Takeaways slide]

So, if you walk out of here with nothing else, walk out with this list:

- Consider local tools before expensive adoptions. Check what's already sitting in your own process - a cache, a queue, an embedded database - before you reach for Kafka, Redis, or a new team to run something for you.
- Use the type system to enforce correctness. Opaque types and phantom types in Gleam, a private constructor and a sealed interface on the JVM - same trick, push the check to where the value is created, not to every caller downstream.
- Avoid using exceptions for things that are not exceptional. Model the failures you expect as values. Save exceptions for the ones you genuinely can't recover from.
- Have a clear vision for what language features you actually need, and stick to them. Drive simplicity through restriction - a style guide and a linter rule buy you the same discipline on the JVM that a small language gives you by default.
- And, obviously: give Gleam a try.

None of the first four require you to touch Gleam, or Beam, or ever leave the JVM. But it's exactly the kind of thing you only notice you're missing once you've looked at a language that doesn't let you get away without it.

[Show Thank You slide]

Thank you! Slides are up on lindbakk.com. And if you do give Gleam a try and end up liking it - it's built and maintained by a small team, so consider supporting it directly.
