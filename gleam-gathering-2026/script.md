Hi evereyone!

//TODO: Introduce what this talk is about

It is an honour to be attending the first Gleam Gathering ever, and I am excited to see how this evolves in the years to come.

Let's do a quick introduction first: I'm John Lindbakk. I have been working as
a developer, architect and tech lead for over a decade at this point. Any my
job has primarily been within big enterprise codebases. You know the ones:
- Banking
- Insurance
- Healthcare
Often working with systems with so many integrations that we barely know what
does owned by a team in a different country, belonging to a completely different
department which we don't know what does. And often there's a very strict "architectre board"
which decides the exact technologies we should be using, while there are ivory tower architects
that defines everything (and then blame everyone else when things go wrong).

In other words, I've lived in a world which is very formal, rigid and top-down.
And I think that is an interesting perspective to have when talking about Gleam.

Another thing about me is that I grew up here, called Lunde in Telemark, in Norway:
[Show picture of Telemark (Map)]
Telemark is said to be "Norway within Norway" due to its nature and history.
[Show pictures from Telemark: Mountains, fjords, private images? etc]

This is where I have my family, and now that I have 3 kids I really want
them to have a good relationship with my family. The thing is, I got this
bad boy:
[Show image of a Renault Zoe]
and my mum has this beast:
[Show image of VW I3]

Neither really having the capacity to easily let one visit each other.
No worries though, because as one of the richest countries in the world,
we have public transportation! We got train! See this randy line
right here:
[Show map of Norway with Sørlandsbanen mapped out]

It goes exactly where I need it to go! Isn't that great?

So, why am I telling you this? Well, the reason is that this is just theory.
In practice the train is often so delayed that it is not worth taking it. Often
I'd spend less time taking my Renault Zoe without fast charging. As a result
it has reduced how much my children get to spend with their extended family.

It was this summer I sat on the train from a visit, and as it tends to be
I was 3 hours delayed. So I grabbed my laptop and started rage-coding, which became
Surtoget.
[Show screenshot of the website]

//TODO: Explain Surtoget?

Surtoget is a cheeky little website which aim to highlight the inadiquies of the
Sørlandsbanen. This is, however bigger than me: Students risk not getting grades
due to their absenc due to delays on the train. Adults are consistently late
in their commute.

Don't worry, I'll get to Gleam.

//TODO: ALL ABOUT SURTOGET

Alright, so finally, Gleam. Let's talk about it!

When I made Surtoget I landet on Gleam. There were multiple reasons for that.

In the last few years I've become very aware of the synthatical bloat a lot of
languages have. For example, for fun I wanted to see how many pages the
C# language reference is, and the PDF is 2100 pages! I did the same with Java,
wich is 1300 ish.

What about Gleam though? Gleam rocks a nice 69 pages!

C# has, according to its language specification, 125 keywords while Gleam has about 22 that is reserved.

None of the above says that one is better than the other, but it does say something about
the complexity of the language itself. Louis himself has stated that he wants to keep
the core language small and focused. And this is what I wanted for when making my silly
little website.

Why does language complextiy matter? Well, it matters because the more options a language
provides, the more bullets you have to shoot youself with. It hurts readability as more
semantics and synthatical variety can exist. It adds to the mental burden both while
reading and writing code.

But the goal was not just to make a silly little website, but also to look at the language
and its ability to do more than just silly websites. The thing is: I've started to grow
vary of the bloat I see at a daily.