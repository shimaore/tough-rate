Tests
=====

    {deepEqual,strictEqual} = require 'assert'

    resolver = require '../field_merger'

    describe 'The field merger', ->
      it 'should work with empty sets', ->
        deepEqual {}, resolver [
          {}
        ]
        deepEqual {}, resolver [
          {}
          {}
        ]
        deepEqual {}, resolver [
          {}
          {}
          {}
        ]

      it 'should ignore fields starting with underscore', ->
        deepEqual {ok:false}, resolver [
          {ok:false, _id:1}
          {ok:false, _id:2}
          {ok:false, _id:3}
        ]

      it 'should merge disabled using OR', ->
        deepEqual {disabled:false}, resolver [
          {disabled:false}
          {disabled:false}
          {disabled:false}
        ]
        deepEqual {disabled:false}, resolver [
          {disabled:false}
        ]
        deepEqual {disabled:true}, resolver [
          {disabled:false}
          {disabled:true }
        ]
        deepEqual {disabled:true}, resolver [
          {disabled:false}
          {disabled:true }
          {disabled:false}
        ]

      it 'should merge numbers by choosing the most specific one', ->
        deepEqual {a:1}, resolver [
          {a:1}
        ]
        deepEqual {a:2}, resolver [
          {a:1}
          {a:2}
        ]
        deepEqual {a:3}, resolver [
          {a:1}
          {a:2}
          {a:3}
        ]
      it 'should merge strings by choosing the most specific one', ->
        deepEqual {a:'a'}, resolver [
          {a:'a'}
        ]
        deepEqual {a:'b'}, resolver [
          {a:'a'}
          {a:'b'}
        ]
        deepEqual {a:'c'}, resolver [
          {a:'a'}
          {a:'b'}
          {a:'c'}
        ]
        deepEqual {a:'c'}, resolver [
          {a:[1]}
          {a:[2]}
          {a:'c'}
        ]


      it 'should process complex datasets', ->
        data_in = [
          {ok:false, a:3, b:"yes",   c:[1],       d:{w:1},     attrs:{ok:false, a:3, b:"yes", c:[1], d:{w:1}},     disabled:false }
          {               b:null                                                                                                  }
          {          a:4,            c:[2],       d:{y:2},     attrs:{          a:4,          c:[2], d:{y:2}}                     }
          {ok:true,       b:"maybe", c:'invalid', d:{w:4},     attrs:{ok:true,       b:"maybe",      d:{w:4}}                     }
          {ok:false,                                           attrs:{ok:false},                                   disabled:true  }
        ]
        data_out =
          {ok:false, a:4, b:"maybe", c:'invalid', d:{w:4},     attrs:{ok:false, a:4, b:"maybe",c:[2],d:{w:4}},     disabled:true  }

        deepEqual data_out, resolver data_in
