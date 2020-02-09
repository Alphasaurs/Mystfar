exports = exports ? @

exports.Orc = class Orc
  constructor: ->
    @stacks = []
    @currentStack = null

  sequence: (functions...) ->
    # each sequence needs an execution context so that orc can keep the
    # information about each sequence isolated from the rest
    context = new ExecutionContext functions
    # orc either adds this context to the current stack or creates a new
    # stack, @currentStack is only set when orc is already in the process
    # of executing a sequence
    if @currentStack?
      @currentStack.push context
    else
      @stacks.push [context]
      @execute()
    # return the context just in case it is needed for anything
    context

  waitFor: (callback) =>
    # first wait, then save the context and contextStack in this scope so
    # that they can be used to execute the decorated callback later
    context = @currentStack.last().wait()
    contextStack = @currentStack
    =>
      if callback?
        # set the current contextStack so that calls to orc.waitFor made by
        # the callback will be routed to the correct context
        @currentStack = contextStack
        try
          callback arguments...
        catch error
          @currentStack.last().handleError error, context
        # we don't need @currentStack for the time being
        @currentStack = null
      # this done is required because of the @wait line at the beginning
      # of the decorator function
      context.done()

  errorOn: (callback) =>
    =>
      if callback?
        callback arguments...
      @fail()

  fail: ->
    throw new OrcError()

  execute: =>
    while @canExecute()
      for @currentStack in @stacks
        @executeNext()
        if @currentStack.isEmpty()
          @stacks.remove @currentStack
          break

    @currentStack = null

  executeNext: ->
    context = @currentStack.last()
    context.executeNext @execute if context.canExecute()
    @currentStack.pop() unless context.waiting() or context.canExecute()

  canExecute: ->
    for contextStack in @stacks
      return true unless contextStack.isEmpty() or contextStack.last().waiting()
    false

exports.ExecutionContext = class ExecutionContext
  constructor: (@functions=[]) ->
    @holds = 0

  waiting: ->
    @holds > 0

  wait: ->
    @holds++
    @

  done: ->
    return unless @waiting()
    @holds--
    @readyCallback() unless @waiting()

  canExecute: ->
    not @functions.isEmpty()

  executeNext: (readyCallback) ->
    @functions.shift()()
    @readyCallback = readyCallback if @waiting()

  handleError: ->
    @fail()

  fail: ->
    throw new OrcError()

  readyCallback: ->

class OrcError extends Error

# indexOf polyfill
unless Array::indexOf
  Array::indexOf = (item) ->
    for prop, i in @
      return i if item is prop
    return -1

Array::isEmpty = ->
  @length == 0

Array::last = ->
  @[@length-1]

Array::remove = (object) ->
  @splice @indexOf(object), 1

exports.orc = new Orc
