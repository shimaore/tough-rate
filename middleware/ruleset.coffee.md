Ruleset Loader
==============

    find_rule_in = require '../find_rule_in'

    class CCNQBaseMiddlewareError extends Error

    @name = 'ruleset'
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
      assert @cfg.ruleset_of?, 'Missing `ruleset_of`.'
    @include = ->
      provisioning = @cfg.prov
      ruleset_of = @cfg.ruleset_of
      default_outbound_route = @cfg.default_outbound_route

We first need to determine which routing table we should use, though.
This is based on the calling number.

      return if @finalized()

Route based on the route selected by the source, or using a default route.

      source = @source

* doc.global_number.outbound_route (number) Route used for Least Cost Routing (LCR).

      provisioning.get "number:#{source}"
      .then (doc) =>
        debug "RuleSet Middleware: number:#{source} :", doc
        route = doc.outbound_route ? default_outbound_route
      .catch (error) =>
        debug "RuleSet Middleware: error retrieving number:#{source}, using #{default_outbound_route} as route :", error.toString()
        route = default_outbound_route
      .then (route) =>
        unless route?
          @respond '485'
          debug 'RuleSet Middleware: No route available', {source}
          cuddly.dev 'missing-route', {source}
          throw new CCNQBaseMiddlewareError "No route available for #{source}"

        route = "#{route}"
        @res.route = route

        debug "RuleSet Middleware: loading ruleset_of", {source,route}
        ruleset_of route
      .then ({ruleset,ruleset_database}) =>
        unless ruleset? and ruleset_database?
          @respond '500'
          debug 'No ruleset available', {source,route:@res.route,ruleset,ruleset_database}
          cuddly.dev 'missing-ruleset', {source,route:@res.route,ruleset,ruleset_database}
          throw new CCNQBaseMiddlewareError "Route `#{@res.route}` for `#{source}` has no ruleset or no database."

        @res.ruleset = ruleset
        @res.ruleset_database = ruleset_database

        find_rule_in @res.destination,ruleset_database
      .then (rule) =>
        unless rule?
          @respond '485'
          debug 'No route available', {source,destination:@res.destination,ruleset:@res.ruleset}
          cuddly.dev 'missing-rule', {source,destination:@res.destination,ruleset:@res.ruleset}
          throw new CCNQBaseMiddlewareError "No rule available towards #{@res.destination}"

* doc.rule.gwlist (array) List of gateways/carriers for this destination.

        if rule.gwlist?
          @res.gateways = rule.gwlist
          delete rule.gwlist
        else
          debug 'Missing gwlist', rule
          cuddly.dev 'missing-gwlist', {rule}

        @res.rule = rule

* doc.rule.attrs (object) Extra attributes for this rule.

        @attr rule.attrs

      .catch (error) =>
        debug "Ruleset middleware failed: #{error}"
        cuddly.ops "ruleset-middleware: #{error}"

    assert = require 'assert'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:ruleset"
    cuddly = (require 'cuddly') "#{pkg.name}:ruleset"
