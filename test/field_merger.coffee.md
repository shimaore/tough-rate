Tests
=====

    {deepEqual,strictEqual} = require 'assert'

    resolver = require '../field_merger'

    describe 'The field merger', ->
      it 'should work with empty sets', ->
        deepEqual {}, resolver {}
        deepEqual {}, resolver
          default: {}
        deepEqual {}, resolver
          default: {}
          prefix:  {}
        deepEqual {}, resolver
          default: {}
          prefix:  {}
          entry:   {}

      it 'should ignore fields starting with underscore', ->
        deepEqual {ok:false}, resolver
          default: ok:false, _id:1
          prefix:    ok:false, _id:2
          entry:   ok:false, _id:3

      it 'should merge disabled using OR', ->
        deepEqual {disabled:false}, resolver
          default: disabled:false
          prefix:  disabled:false
          entry:   disabled:false
        deepEqual {disabled:false}, resolver
          default: disabled:false
        deepEqual {disabled:true}, resolver
          default: disabled:false
          prefix:  disabled:true
        deepEqual {disabled:true}, resolver
          default: disabled:false
          prefix:  disabled:true
          entry:   disabled:false

      it 'should merge numbers by choosing the most specific one', ->
        deepEqual {a:1}, resolver
          default: a:1
        deepEqual {a:2}, resolver
          default: a:1
          prefix:  a:2
        deepEqual {a:3}, resolver
          default: a:1
          prefix:  a:2
          entry:   a:3

      it 'should process complex datasets', ->
        data_in =
          default:      ok:false, a:3, b:"yes",   c:[1],       d:{w:1},     attrs:{ok:false, a:3, b:"yes", c:[1],       d:{w:1}},     disabled:false
          carrier:                     b:null
          ruleset:                a:4,            c:[2],       d:{y:2},     attrs:{          a:4,          c:[2],       d:{y:2}}
          destination:  ok:'invalid',  b:3,       c:'invalid', d:'invalid', attrs:{ok:'invalid',  b:3,     c:'invalid', d:'invalid'}, disabled:true
          prefix:       ok:true,       b:"maybe",              d:{w:4},     attrs:{ok:true,       b:"maybe",            d:{w:4}}
          entry:        ok:false,                                           attrs:{ok:false}
        data_out =
                        ok:false, a:4, b:"maybe", c:'invalid', d:{w:4},     attrs:{ok:false, a:4, b:"maybe",c:'invalid',d:{w:4}},     disabled:true

        deepEqual data_out, resolver data_in
