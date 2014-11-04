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
        @plugins = []
        assert @provisioning, 'Missing `provisioning` database'
        assert @gateway_manager, 'Missing `gateway_manager`'
        assert @options.ruleset_of, 'Missing `ruleset_of`'
        assert @options.statistics, 'Missing `statistics`'
        assert @options.respond, 'Missing `respond`'
        # assert @options.host
        # assert @options.outbound_route

Handle `gwid` field if present.

        @plugin require './plugin-gwid'

Handle `carrierid` field if present.

        @plugin require './plugin-carrierid'

Plugins
=======

Plugins will be called as `(entry,params)` where `params` is an object containing:
* `source` -- the source number
* `source_doc` -- the source (CouchDB) document
* `destination` -- the original called number
* `final_destination` -- optionnally, the modified called number
* `rule` -- the rule (CouchDB) document

If the plugin is handling the `entry`, it must return `null`.
Otherwise it must return a Promise which when resolved returns an array of gateways.
Gateways are defined using objects containing:
* `uri`: a full SIP URI indicating where to send the call to (be careful to take `final_destination` into account in this case)
* `address`: a SIP domain part (will be used to build a full URI using the `destination` or `final_destination`)

      plugin: (plugin) ->
        @plugins.push plugin

      route: (source,destination,emergency_ref) ->

First, see whether the destination number is one of our numbers, and route it.

        @provisioning.get "number:#{destination}"
        .then (doc) =>
          Promise.resolve [{uri: doc.inbound_uri}]
        .catch =>
          @_route_remote source, destination, emergency_ref

We first need to determine which routing table we should use, though.
This is based on the calling number.

      _route_remote: (source,destination,emergency_ref) ->

Route based on the route selected by the source, or using a default route.

        ruleset = null
        final_destination = null
        source_doc = null

        find_rule_in = (destination,database) =>
          ids = ("rule:#{destination[0...l]}" for l in [0..destination.length]).reverse()

          database.allDocs keys:ids, include_docs: true
          .then ({rows}) =>
            rule = (row.doc for row in rows when row.doc? and not row.doc.disabled)[0]

            unless rule?
              @options.respond '485'
              @options.statistics.warn 'No route available', {source,rows}
              throw new CallRouterError "No rule available towards #{destination}"

            {rule,database}

        the_route = null

        @provisioning.get "number:#{source}"
        .then (doc) =>
          source_doc = doc
          route = doc.outbound_route ? @options.outbound_route
        .catch =>
          route = @options.outbound_route
        .then (route) =>
          unless route?
            @options.respond '485'
            @options.statistics.warn 'No route available', {source}
            throw new CallRouterError "No route available for #{source}"

          route = "#{route}"
          the_route = route

          @options.ruleset_of route
        .then ({ruleset,database}) =>
          unless ruleset? and database?
            @options.respond '500'
            @options.statistics.warn 'No ruleset available', {source,the_route}
            throw new CallRouterError "Route #{the_route} for #{source} has no ruleset or no database."

          find_rule_in destination,database
        .then ({rule,database}) =>

          if not rule.emergency
            return {rule,database}

          if emergency_ref?
            emergency_key = [destination,emergency_ref].join '#'
          else
            emergency_key = destination

          @provisioning.get "emergency:#{emergency_key}"
          .then (doc) =>
            final_destination = doc.destination ? null
            find_rule_in final_destination,database

        .then ({rule}) =>
          gwlist = rule.gwlist
          unless gwlist?
            @options.respond '500'
            @options.statistics.warn 'Missing gwlist', rule
            throw new CallRouterError "Missing gwlist in rule #{rule._id}"

          Promise.map gwlist, (entry) =>

The list returned contains one entry (one array) for each original destination.

            result = null
            for plugin in @plugins
              result = plugin.call this, entry, {source,source_doc,destination,final_destination,rule}
              break if result?

            if not result?
              @options.statistics.warn "Missing gwid, carrierid, ...; active plugins = #{(@plugins.map (x) -> x.title).join ','}", rule
              throw new CallRouterError "Invalid entry #{JSON.stringify entry} in gwlist of #{rule._id}"

            result.then (gateways) ->
              gateways.map (gateway) ->
                field_merger {default:{final_destination}, gateway, ruleset, rule, entry}

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
