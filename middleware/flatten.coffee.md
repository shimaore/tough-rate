Flatten the gateways
====================

    module.exports = ->
      middleware = ->

        @logger.info "Gateways before ops", JSON.stringify @res.gateways

We must flatten the list so that CallHandler can use it.

        @res.gateways = @res.gateways.map (gateway) =>
          if isArray gateway
            console.log "Array: #{JSON.stringify gateway}"
            gateway.map (gateway) =>
              field_merger {
                default: {destination:@res.destination}
                gateway
                ruleset:@res.ruleset
                rule:@res.rule
              }
          else
            console.log "NOT Array: #{JSON.stringify gateway}"
            field_merger {
              default: {destination:@res.destination}
              gateway
              ruleset:@res.ruleset
              rule:@res.rule
            }

        @logger.info "Gateways after ops", JSON.stringify @res.gateways
        @res.gateways = flatten @res.gateways
        @logger.info "Gateways after flatten", JSON.stringify @res.gateways

Toolbox
-------

    flatten = (lists) ->
      result = []
      result = result.concat list for list in lists
      result

    field_merger = require '../field_merger'
    Promise = require 'bluebird'
    {isArray} = require 'util'
