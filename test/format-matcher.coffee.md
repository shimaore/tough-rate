    {expect} = chai = require 'chai'
    chai.should()
    describe 'format matcher', ->
      {is_correct} = require '../middleware/format-matcher'
      it 'should accept non-geo FR numbers', ->
        a = is_correct '33972342713'
        a.should.have.property 'fixed', true
        a.should.have.property 'geographic', false

      it 'should accept fixed geo FR numbers', ->
        a = is_correct '33467891202'
        a.should.have.property 'fixed', true
        a.should.have.property 'geographic', true

      it 'should reject invalid FR numbers', ->
        is_correct '3397234713'
          .should.be.false

      it 'should accept US numbers', ->
        is_correct '12123141212'
          .should.have.property 'name', 'NY'

      it 'should reject unwanted US numbers', ->
        is_correct '12125551212'
          .should.be.false
        is_correct '11005551212'
          .should.be.false

      it 'should ignore numbers it does not know about', ->
        expect is_correct '4372617278'
          .to.be.null
