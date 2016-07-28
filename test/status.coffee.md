Status tests
============

    Status = require '../status'
    chai = require 'chai'
    chai.should()

    describe 'Status', ->

      status = new Status()

      it 'should be active by default', ->
        status.should.have.property 'state'
        status.state.should.equal 'active'

      it 'should move to faulty', ->
        status.mark_as_faulty()
        status.should.have.property 'state'
        status.state.should.equal 'faulty'

      it 'should stay as faulty', ->
        status.mark_as_suspicious()
        status.should.have.property 'state'
        status.state.should.equal 'faulty'

    describe 'Status expires', ->

      status = new Status()

      it 'should be suspicious', ->
        status.mark_as_suspicious()
        status.should.have.property 'state'
        status.state.should.equal 'suspicious'

      it 'should move to faulty', ->
        status.mark_as_suspicious()
        status.mark_as_suspicious()
        status.mark_as_suspicious()
        status.mark_as_suspicious()
        status.mark_as_suspicious()
        status.should.have.property 'state'
        status.state.should.equal 'faulty'

      @timeout Status.faulty_timeout+2000
      it 'should move back to suspicious', (done) ->
        setTimeout (->
          status.should.have.property 'state'
          status.state.should.equal 'suspicious'
          done()
        ), status.faulty_timeout+500

      @timeout 2*Status.faulty_timeout+2000
      it 'should move back to active', (done) ->
        setTimeout (->
          status.should.have.property 'state'
          status.state.should.equal 'active'
          done()
        ), 2*status.suspicious_timeout+500
