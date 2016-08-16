Field Merger
============

    combiners =
      disabled: (a,b) -> a or b
      temporarily_disabled: (a,b) -> a or b
      attrs: (a,b) ->
        a ?= {}
        for own k,v of b
          a[k] = v
        a

    resolver = (records) ->

      result = {}

      for record in records

        for own field, value of record when field[0] isnt '_'

For all attributes except `attrs`, the most specific value is selected.

          if combiners[field]
            result[field] = combiners[field] result[field], value
          else
            result[field] = value

      result

Toolbox
=======

    {isArray} = require 'util'
    type_of = (x) ->
      if isArray x then 'array' else typeof x


Tests
=====

    {strictEqual} = require 'assert'

    strictEqual 'array', type_of []
    strictEqual 'object', type_of {}
    strictEqual 'number', type_of 3
    strictEqual 'number', type_of 3.5
    strictEqual 'string', type_of ""

    module.exports = resolver
