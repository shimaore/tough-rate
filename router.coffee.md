Least Cost Router
=================

Options:
- `provisioning`: PouchDB instance of the provisioning database [required]
- `gateway_manager`: GatewayManager instance for our sip_domain_name [required]
- function `ruleset_of(route)`: returns {ruleset,database}, where database is a new PouchDB instance for the routing database (ruleset) `route`, and ruleset is the ruleset document.
- `host`: local host name
- `outbound_route`: default outbound route if none is specified for the calling number [optional]

    class CallRouterError extends Error

    module.exports = class CallRouter

      constructor: (@options) ->
        {@provisioning,@gateway_manager} = @options
        assert @provisioning, 'Missing `provisioning` database'
        assert @gateway_manager, 'Missing `gateway_manager`'
        assert @options.ruleset_of, 'Missing `ruleset_of`'
        assert @options.statistics, 'Missing `statistics`'
        assert @options.respond, 'Missing `respond`'
        # assert @options.host
        # assert @options.outbound_route

      route: (source,destination) ->

First, see whether the destination number is one of our numbers, and route it.

        @provisioning.get "number:#{destination}"
        .then (doc) =>
          Promise.resolve [{uri: doc.inbound_uri}]
        .catch =>
          @_route_remote source, destination

We first need to determine which routing table we should use, though.
This is based on the calling number.

      _route_remote: (source,destination) ->

Route based on the route selected by the source, or using a default route.

        ruleset = null
        rule = null

        @provisioning.get "number:#{source}"
        .then (doc) =>
          route = doc.outbound_route ? @options.outbound_route
        .catch =>
          route = @options.outbound_route
        .then (route) =>
          unless route?
            @options.respond '485'
            @options.statistics.warn 'No route available', {source}
            throw new CallRouterError "No route available for #{source}"

          route = "#{route}"

          @options.ruleset_of route
        .then ({ruleset,database}) =>
          unless ruleset?
            @options.respond '500'
            @options.statistics.warn 'Invalid route', {source}
            throw new CallRouterError "Invalid route for #{source}"

          ids = ("rule:#{destination[0...l]}" for l in [0..destination.length]).reverse()

          database.allDocs keys:ids, include_docs: true
        .then ({rows}) =>
          rule = (row.doc for row in rows when row.doc? and not row.doc.disabled)[0]

          unless rule?
            @options.respond '485'
            @options.statistics.warn 'No route available', {source,rows}
            throw new CallRouterError "No rule available towards #{destination}"

          gwlist = rule.gwlist
          unless gwlist?
            @options.respond '500'
            @options.statistics.warn 'Missing gwlist', rule
            throw new CallRouterError "Missing gwlist in rule #{rule._id}"

          Promise.map gwlist, (entry) =>

The list returned contains one entry (one array) for each original destination.

            result = if entry.gwid?
              @gateway_manager.resolve_gateway entry.gwid
            else if entry.carrierid?
              @gateway_manager.resolve_carrier entry.carrierid
              .then (gateways) =>
                gateways.forEach (gateway) =>
                  gateway.priority = 1

First we must sort the carrier entries using the local hostname preference.

                  if gateway.local_gateway_first and @options.host? and gateway.host is @options.host
                    gateway.priority += 0.5

                gateways.sort (a,b) -> a.priority - b.priority

And select only `try` entries where specified.

                count = gateways[0]?.try
                if count? and count > 0
                  gateways = gateways[0...count]

                gateways

            else
              @options.statistics.warn "Missing gwid or carrierid", rule
              throw new CallRouterError "Neither gwid nor carrierid in gwlist of #{rule._id}"

            result.then (gateways) ->
              gateways.map (gateway) ->
                field_merger {gateway, ruleset, rule, entry}

Then we must flatten the list so that CallHandler can use it.

        .then flatten


Toolbox
=======

    flatten = (lists) ->
      result = []
      result = result.concat list for list in lists
      result

    Promise = require 'bluebird'
    assert = require 'assert'
    field_merger = require './field_merger'
