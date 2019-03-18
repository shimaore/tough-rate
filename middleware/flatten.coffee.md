Flatten the gateways
====================

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:flatten"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      debug "Gateways before merge", @res.gateways

      unless @res.gateways?
        debug 'No gateways'
        return

We must flatten the list so that CallHandler can use it.

      merge = (gateway) =>
        field_merger [
          @res.extra
          gateway
          @res.ruleset
          @res.rule
        ]

      @res.gateways = @res.gateways.map (gateway) =>
        if isArray gateway
          gateway.map merge
        else
          merge gateway

      debug "Gateways after merge", @res.gateways
      @res.gateways = flatten @res.gateways
      debug "Gateways after flatten", @res.gateways

Release (leaking) fields

      delete @res.ruleset
      delete @res.ruleset_database
      delete @res.rule
      return

Toolbox
-------

    flatten = (lists) ->
      result = []
      result = result.concat list for list in lists
      result

    field_merger = require '../field_merger'
    {isArray} = require 'util'
