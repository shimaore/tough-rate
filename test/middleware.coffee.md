    chai = require 'chai'
    chai.should()
    {EventEmitter} = require 'events'

    describe 'call-handler', ->

      module = require '../middleware/call-handler'
      mw = module.call options: profile:'default'

      it 'should call respond', (done) ->
        mw.call
          res:
            response:'604'
          logger:
            info: ->
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
          mark_gateway_as_faulty: (gateway) ->
            gateway.should.eql gw
            done()

        ev = new EventEmitter()

        mw.call
          on: (msg,callback) ->
            ev.on msg, -> callback
