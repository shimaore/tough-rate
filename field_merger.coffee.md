Field Merger
============

From README.md:

Different attribute values might be present. They are always resolved in the following order: default, carrier, gateway, ruleset, destination, rule, gwlist entry.

    resolution_order = 'default carrier gateway ruleset destination rule entry'.split ' '
    hash_fields = 'attrs'.split ' '

    resolver = (records) ->

      result = {}

For all attributes except `attrs`, the most specific value is selected.

      for name in resolution_order when records[name]?
        record = records[name]

        for field, value of record when field not in hash_fields and field[0] isnt '_'
          result[field] = value

        return unless record.attrs?

For `attrs`, each top value is either:

        for h in hash_fields
          for field, value of record[h]
            result.attrs ?= {}
            previous_value = result[h][field]
            if not previous_value?
              result[h][field] = value
            else
              type = type_of value

Values of inconsistent datatypes are ignored.

              if type is type_of previous_value
                result[h][field] = switch type_of previous_value

- OR'ed (for booleans).

                  when 'boolean'
                    previous_value or value

- concatenated (for strings and lists); the most specific value is listed last.

                  when 'string'
                    "" + previous_value + value
                  when 'array'
                    previous_value.concat value

- merged (for objects); for conflicting fields inside an object, the most specific value is selected.

                  when 'object'
                    previous_value[k] = v for own k,v of value
                    previous_value
                  else
                    value

      result

Toolbox
=======

    {isArray} = require 'util'
    type_of = (x) ->
      if isArray x then 'array' else typeof x


Tests
=====

    {deepEqual,strictEqual} = require 'assert'

    strictEqual 'array', type_of []
    strictEqual 'object', type_of {}
    strictEqual 'number', type_of 3
    strictEqual 'number', type_of 3.5
    strictEqual 'string', type_of ""

    test_1_in =
      default:      ok:false, a:3, b:"yes",   c:[1],       d:{w:1},     attrs:{ok:false, a:3, b:"yes", c:[1],       d:{w:1}}
      ruleset:                a:4,            c:[2],       d:{y:2},     attrs:{          a:4,          c:[2],       d:{y:2}}
      destination:  ok:'invalid',  b:3,       c:'invalid', d:'invalid', attrs:{ok:'invalid',  b:3,     c:'invalid', d:'invalid'}
      rule:         ok:true,       b:"maybe",              d:{w:4},     attrs:{ok:true,       b:"maybe",            d:{w:4}}
      entry:        ok:false,                                           attrs:{ok:false}
    test_1_out =
                    ok:false, a:4, b:"maybe", c:'invalid', d:{w:4},     attrs:{ok:true,a:4,b:"yesmaybe",c:[1,2],d:{w:4,y:2}}

    deepEqual test_1_out, resolver test_1_in

    module.exports = resolver
