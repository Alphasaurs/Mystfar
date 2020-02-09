# orc

It is customary in computer programming to take a collection of statements that
might be difficult to understand and place them behind a name, within a
function, so that they may be more easily understood and reused. In a language
like JavaScript if any of these statements are separated by an event then
putting the statements all in one function is very difficult. Orc makes this
trivial.

This problem with asynchrony in JavaScript/CoffeeScript is well-known and best
illustrated with an example. The following programs both do the same thing: 1) 
load some content, and then 2) render that content. The first is written
without orc:

```coffeescript
loadData = ->
    console.log 'load the data and wait'
    http = require 'http'
    options =
        host: 'google.com'
        port: 80
        path: ''

    handleHTTPGet = (response) ->
        response.setEncoding 'utf8'

        handleData = (chunk) ->
            console.log "data loaded #{chunk}"

        response.on 'data', handleData

        # here we wait as well
        response.on 'end', renderContent

    # here we wait
    http.get options, handleHTTPGet

renderContent = ->
    console.log 'now render the page'


# this is where we initiate the sequence
loadData()
```

The overall flow here is:

1. loadData()
2. renderContent()

Understanding this flow requires reading through the program. It would be
better if you could put loadData and renderContent next to eachother:

```coffeescript
orc = require('./src/orc').orc

loadData = ->
    console.log 'load the data and wait'
    http = require 'http'
    options =
        host: 'google.com'
        port: 80
        path: ''

    handleHTTPGet = (response) ->
        response.setEncoding 'utf8'

        handleData = (chunk) ->
            console.log "data loaded #{chunk}"

        response.on 'data', handleData

        # here we wait as well
        response.on 'end', orc.waitFor()

    # here we wait
    http.get options, orc.waitFor(handleHTTPGet)

renderContent = ->
    console.log 'now render the page'


# this is where we initiate the sequence
orc.sequence loadData, renderContent
```

The important differences are obviously the orc.sequence and two orc.waitFor
calls. Both of these programs have the same output:

```bash
$ coffee example.coffee
load the data and wait
data loaded <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>

now render the page
```

You can see that first the content is loaded and only after that is the content
rendered.

## Getting Started

**1)** Get orc from npm or bower

```bash
# if you're using with node install with npm
npm install orc

# if you're using in the browser install with bower
bower install orc
```

**2)** Require or script tag orc

```coffeescript
orc = require('orc').orc
```

```html
<script src="orc.js"></script>
```

**3)** Sequence some functions

```coffeescript
loadContent = ->
renderContent = ->

orc.sequence loadContent, renderContent
```

**4)** Wait for some stuff

```coffeescript
loadContent = ->
  request = loader.get someDataUrl
  request.on 'data', orc.waitFor(parseData)

renderContent = ->
  animator.do animationOptions orc.waitFor()

orc.sequence loadContent, renderContent
```

**5)** Tell orc how to error

```coffeescript
loadContent = ->
  request = loader.get someDataUrl
  request.on 'data', orc.waitFor(parseData)
  request.on 'error', orc.errorOn()

renderContent = ->
  animator.do animationOptions orc.waitFor()

orc.sequence loadContent, renderContent
```

**6)** Handle sequence error instead of erroring

```coffeescript
loadContent = ->
  request = loader.get someDataUrl
  request.on 'data', orc.waitFor(parseData)
  request.on 'error', orc.errorOn()

renderContent = ->
  animator.do animationOptions orc.waitFor()

context = orc.sequence loadContent, renderContent
context.handleError = (error, context) -> console.log "#{error} for #{context}"
```

That's it.

## How does it work?

Orc does as much of the bookkeeping as it can. You should almost never need
anything more than the sequence, waitFor, and errorOn functions. Like anything
else the more you know about orc the easier it is to work with.

### sequence

Everything begins with you telling orc to sequence some functions. Orc places
these condemned functions into an ExecutionContext. The context lets orc keep
the details of each execution separated. These details are things like the
functions being executed and whether or not the execution is on hold for
anything. At this point orc will begin executing, if it's not already.

Orc can execute both dependent and independent sequences. A sequence is dependent
when it requires another sequence to complete before it completes. Dependent
sequences are called inside of other sequences kinda like this:

```coffeescript
orc.sequence ->
  orc.sequence ...
```

Independent sequences on the other hand look kinda like this:

```coffeescript
orc.sequence ...
orc.sequence ...
```

Whether or not one sequence depends on another sequence determines where orc
puts the execution context. If the sequence is independent orc will add it
alongside whatever other contexts exist. If the sequence is dependent orc
will stack the context on top of whichever context depends on it. Orc then
manages these dependencies by only executing from the context at the top of of
each stack.

### waitFor

The waitFor decorator is simple. First it saves the current context so that
later on it can determine which context the decorated function belongs to. Then
it returns a function that wraps the callback it was provided.

The decorated function that waitFor returns will set the current context to the
context that was saved earlier. This ensures that any waitFor calls made during
the callback will be routed to the correct context. At the very end, once it
has executed the callback, the waitFor function will call done on the correct
context.
