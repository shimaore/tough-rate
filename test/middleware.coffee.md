    chai = require 'chai'
    chai.should()
    {EventEmitter} = require 'events'

    describe 'call-handler', ->

      module = require '../middleware/call-handler'
      mw = module.include

      it 'should call respond', (done) ->
        mw.call
          cfg:
            options: profile:'default'
          res:
            response:'604'
          statistics:
            add: ->
            emit: ->
          call:
            command: (command,arg) ->
              command.should.eql 'respond'
              arg.should.eql '604'
              done()

    describe.skip 'response-handlers', ->

      module = require '../middleware/response-handlers'

      it 'should mark gateway faulty on CALL_REJECTED', (done) ->
        gw = {}
        mw = module
        ev = new EventEmitter()

        mw.call
          cfg:
            mark_gateway_as_faulty: (gateway) ->
              gateway.should.eql gw
              done()

          on: (msg,callback) ->
            ev.on msg, -> callback
