    chai = require 'chai'
    chai.should()
    {EventEmitter} = require 'events'

    describe 'respond', ->

      module = require '../middleware/respond'
      mw = module()

      it 'should call respond', (done) ->
        mw.call
          response:'604'
          logger: ->
          call:
            command: (command,arg) ->
              command.should.eql 'respond'
              arg.should.eql '604'
              done()

    describe 'response-handlers', ->

      module = require '../middleware/response-handlers'
      GatewayManager = require '../gateway_manager'

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

