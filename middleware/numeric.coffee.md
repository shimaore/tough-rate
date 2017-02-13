    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:numeric"
    @include = ->

      return unless @session.direction is 'lcr'

Source
======

Source must be all numeric.

      unless @source? and @source.match /^\d+$/
        @debug 'Missing or invalid source', @data
        @res.respond '484'
        return

Destination
===========

Destination is numeric most of the time, but might also contain `#` or `*`.
The underscore `_` is used to indicate special numbers with national significance only. The format is country-code + `_` + special number, where country-code indicates the national dialplan.

      unless @destination? and @destination.match /^[\d#*_]+$/
        @debug 'Missing or invalid destination', @data
        @res.respond '484'
        return
