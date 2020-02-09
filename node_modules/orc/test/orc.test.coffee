orc = require 'orc'

describe 'orc', ->
  it 'should have an instance of orc ready to use', ->
    expect(orc.orc).to.be.an.instanceof orc.Orc

describe 'ExecutionContext', ->
  beforeEach ->
    @context = new orc.ExecutionContext()
    sinon.stub @context, 'readyCallback'

  it 'should not be waiting initially', ->
    expect(@context.waiting()).to.be.false

  describe '#waiting', ->
    it 'should be false when there are no holds', ->
      @context.holds = 0

      expect(@context.waiting()).to.be.false

    it 'should be true when there are holds', ->
      @context.holds = 1

      expect(@context.waiting()).to.be.true

  describe '#wait', ->
    it 'should cause context to be waiting', ->
      @context.wait()

      expect(@context.waiting()).to.be.true

    it 'should return the context', ->
      context = @context.wait()

      expect(context).to.equal @context

  describe '#done', ->
    context 'when not waiting', ->
      it 'should not do anything', ->
        @context.done()

        expect(@context.waiting()).to.be.false

      it 'should not call readyCallback', ->
        @context.done()

        expect(@context.readyCallback).to.not.have.been.called

    context 'when waiting', ->
      beforeEach ->
        @context.wait()

      it 'should cause context to no longer be waiting', ->
        @context.done()

        expect(@context.waiting()).to.be.false

      it 'should call readyCallback', ->
        @context.done()

        expect(@context.readyCallback).to.have.been.called

      context 'for many things', ->
        beforeEach ->
          @context.wait()
          
        it 'should require multiple dones', ->
          @context.done()
          expect(@context.waiting()).to.be.true

          @context.done()
          expect(@context.waiting()).to.be.false

        it 'should not call readyCallback', ->
          @context.done()
          expect(@context.readyCallback).to.not.have.been.called

  describe '#canExecute', ->
    it 'should be false when empty', ->
      sinon.stub(@context.functions, 'isEmpty').returns true

      expect(@context.canExecute()).to.be.false

    it 'should be true when not empty', ->
      sinon.stub(@context.functions, 'isEmpty').returns false

      expect(@context.canExecute()).to.be.true

  describe '#executeNext', ->
    beforeEach ->
      @step = sinon.stub()
      @context.functions = [@step]

    it 'should execute the next function', ->
      @context.executeNext()

      expect(@step).to.have.been.called

    it 'should execute functions sequentially', ->
      step2 = sinon.stub()
      @context.functions.push step2

      @context.executeNext()
      expect(@step).to.have.been.called
      expect(step2).to.not.have.been.called

      @context.executeNext()
      expect(step2).to.have.been.called

    context 'when not waiting', ->
      it 'should not set the readyCallback', ->
        sinon.stub(@context, 'waiting').returns false

        @context.executeNext @step

        expect(@context.readyCallback).to.not.equal @step

    context 'when waiting', ->
      it 'should set the readyCallback', ->
        sinon.stub(@context, 'waiting').returns true

        @context.executeNext @step

        expect(@context.readyCallback).to.equal @step

  describe '#fail', ->
    it 'should throw an OrcError', ->
      expect(@context.fail).to.throw orc.OrcError

  describe '#handleError', ->
    it 'should call fail', ->
      sinon.stub @context, 'fail'

      @context.handleError()

      expect(@context.fail).to.have.been.called

describe 'Orc', ->
  beforeEach ->
    @orc = new orc.Orc()

  describe '#sequence', ->
    it 'should return an ExecutionContext', ->
      context = @orc.sequence()

      expect(context).to.be.instanceof orc.ExecutionContext

    it 'should give the functions to the context', ->
      step = ->
      # this causes orc to not execute the sequence so that we
      # can write assertions against context.functions
      @orc.currentStack = []

      context = @orc.sequence step

      expect(context.functions).to.have.members [step]

    context 'when currently executing', ->
      it 'should add context to currentStack', ->
        @orc.currentStack = []
        sinon.stub @orc.currentStack, 'push'

        @orc.sequence()

        expect(@orc.currentStack.push).to.have.been.called

    context 'when not currently executing', ->
      it 'should add a new stack containing context', ->
        sinon.stub @orc.stacks, 'push'

        @orc.sequence()

        expect(@orc.stacks.push).to.have.been.called

      it 'should begin executing', ->
        sinon.stub @orc, 'execute'

        @orc.sequence ->

        expect(@orc.execute).to.have.been.called

  describe '#waitFor', ->
    beforeEach ->
      @orc.currentStack = []
      @context = {wait: (->), done: (->), handleError: (->)}
      sinon.stub(@context, 'wait').returns @context
      sinon.stub(@orc.currentStack, 'last').returns @context

    it 'should tell the current context to wait', ->
      @orc.waitFor()

      expect(@context.wait).to.have.been.called

    it 'should return a callback', ->
      callback = @orc.waitFor()

      expect(callback).to.be.a 'function'

    context 'the returned callback', ->
      it 'should call context.done', ->
        sinon.stub @context, 'done'
        callback = @orc.waitFor()

        callback()

        expect(@context.done).to.have.been.called

      context 'with user defined callback', ->
        beforeEach ->
          @userCallback = sinon.stub()
          @callback = @orc.waitFor @userCallback

        it 'should call the user defined callback', ->
          @callback()

          expect(@userCallback).to.have.been.called

        it 'should pass on the arguments to the user defined callback', ->
          @callback 'an argument to test'

          expect(@userCallback).to.have.been.calledWith 'an argument to test'

        it 'should leave currentStack null when it is done', ->
          @callback()

          expect(@orc.currentStack).to.be.null

        context 'when the user defined callback throws an error', ->
          it 'should call handleError on the original context', ->
            sinon.stub @context, 'handleError'

            anError = new Error()
            @userCallback.throws anError

            callback = @orc.waitFor @userCallback
            callback()

            expect(@context.handleError).to.have.been.calledWith(
              anError,
              @context
            )

  describe '#errorOn', ->
    it 'should return a callback', ->
      callback = @orc.errorOn()

      expect(callback).to.be.a 'function'

    context 'with the returned callback', ->
      beforeEach ->
        sinon.stub @orc, 'fail'

      it 'should call fail', ->
        callback = @orc.errorOn()
        callback()

        expect(@orc.fail).to.have.been.called

      context 'with a user defined callback', ->
        beforeEach ->
          @userDefinedCallback = sinon.stub()
          @callback = @orc.errorOn @userDefinedCallback

        it 'should call the user defined callback before failing', ->
          @callback()

          expect(@userDefinedCallback).to.have.been.called

        it 'should pass all arguments to the user defined callback', ->
          @callback 'foo', 'bar'

          expect(@userDefinedCallback).to.have.been.calledWith 'foo', 'bar'

  describe '#fail', ->
    it 'should throw an OrcError', ->
      expect(@orc.fail).to.throw orc.OrcError

  describe '#canExecute', ->
    context 'when empty', ->
      it 'should return false when there is nothing', ->
        @orc.stacks = []

        expect(@orc.canExecute()).to.be.false

    context 'when not empty', ->
      beforeEach ->
        @context = {waiting: (-> false)}
        @stack = {isEmpty: (-> true), last: (=> @context)}

        @orc.stacks = [@stack]

      it 'should return false when there is nothing to execute', ->
        expect(@orc.canExecute()).to.be.false

      it 'should return false when all contexts are waiting', ->
        sinon.stub(@stack, 'isEmpty').returns false
        sinon.stub(@context, 'waiting').returns true

        expect(@orc.canExecute()).to.be.false

      it 'should return true when there is a context not waiting', ->
        sinon.stub(@stack, 'isEmpty').returns false
        sinon.stub(@context, 'waiting').returns false

        expect(@orc.canExecute()).to.be.true

  describe '#executeNext', ->
    beforeEach ->
      @context = {waiting: (->), canExecute: (->), executeNext: (->)}
      @orc.currentStack = [@context]

    it 'should call executeNext on the current context', ->
      sinon.stub(@context, 'waiting').returns false
      sinon.stub(@context, 'canExecute').returns true

      sinon.stub @context, 'executeNext'
      @orc.executeNext()

      expect(@context.executeNext).to.have.been.called

    context 'when there is more to execute', ->
      context 'and waiting', ->
        it 'should not remove the context', ->
          sinon.stub(@context, 'waiting').returns true
          sinon.stub(@context, 'canExecute').returns false

          sinon.stub @orc.currentStack, 'pop'
          @orc.executeNext()

          expect(@orc.currentStack.pop).to.not.have.been.called

      context 'and not waiting', ->
        it 'should not remove the context', ->
          sinon.stub(@context, 'waiting').returns false
          sinon.stub(@context, 'canExecute').returns true

          sinon.stub @orc.currentStack, 'pop'
          @orc.executeNext()

          expect(@orc.currentStack.pop).to.not.have.been.called

    context 'when there is nothing more to execute', ->
      it 'should remove the context', ->
        sinon.stub(@context, 'waiting').returns false
        sinon.stub(@context, 'canExecute').returns false

        sinon.stub @orc.currentStack, 'pop'
        @orc.executeNext()

        expect(@orc.currentStack.pop).to.have.been.called

  describe '#execute', ->
    context 'when there is more to execute', ->
      beforeEach ->
        canExecute = false
        sinon.stub @orc, 'canExecute', -> canExecute = !canExecute

      it 'should call executeNext', ->
        @orc.stacks = [{isEmpty: -> true}]
        sinon.stub @orc, 'executeNext'

        @orc.execute()

        expect(@orc.executeNext).to.have.been.called

      context 'when empty', ->
        it 'should remove the stack', ->
          @orc.stacks = [{isEmpty: -> true}]
          sinon.stub @orc, 'executeNext'
          sinon.stub @orc.stacks, 'remove'

          @orc.execute()

          expect(@orc.stacks.remove).to.have.been.called

    context 'when there is nothing more to execute', ->
      beforeEach ->
        sinon.stub(@orc, 'canExecute').returns false

      it 'should not call executeNext', ->
        sinon.stub @orc, 'executeNext'

        @orc.execute()

        expect(@orc.executeNext).to.not.have.been.called

      it 'should not remove anything', ->
        sinon.stub @orc.stacks, 'remove'

        @orc.execute()

        expect(@orc.stacks.remove).to.not.have.been.called
