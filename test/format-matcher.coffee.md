    {expect} = chai = require 'chai'
    chai.should()
    describe 'format matcher', ->
      {include} = require '../middleware/format-matcher'
      it 'should accept non-geo FR numbers', ->
        ctx =
          session:
            direction: 'lcr'
          destination: '33972342713'
          set: ->
        include.call ctx
        .then ->
          ctx.session.should.have.property 'destination_information'
          a = ctx.session.destination_information
          a.should.have.property 'fixed', true
          a.should.have.property 'geographic', false

      it 'should accept fixed geo FR numbers', ->
        ctx =
          session:
            direction: 'lcr'
          destination: '33467891202'
          set: ->
        include.call ctx
        .then ->
          ctx.session.should.have.property 'destination_information'
          a = ctx.session.destination_information
          a.should.have.property 'fixed', true
          a.should.have.property 'geographic', true

      it 'should reject invalid FR numbers', (done) ->
        ctx =
          session:
            direction: 'lcr'
          destination: '3397234713'
          respond: (value) ->
            done() if value is '484'
        include.call ctx
        null

      it 'should accept US numbers', ->
        ctx =
          session:
            direction: 'lcr'
          destination: '12123141212'
          set: ->
        include.call ctx
        .then ->
          ctx.session.should.have.property 'destination_information'
          a = ctx.session.destination_information
          a.should.have.property 'name', 'NY'

      it 'should reject unwanted US numbers', (done) ->
        ctx =
          session:
            direction: 'lcr'
          destination: '12125551212'
          respond: (value) ->
            done() if value is '484'
        include.call ctx
        null

      it 'should reject unwanted US numbers', (done) ->
        ctx =
          session:
            direction: 'lcr'
          destination: '11005551212'
          respond: (value) ->
            done() if value is '484'
        include.call ctx
        null

      it 'should ignore numbers it does not know about', ->
        ctx =
          session:
            direction: 'lcr'
          destination: '9372617278'
        include.call ctx
        .then ->
          ctx.session.should.not.have.property 'destination_information'
