Ruleset Loader
==============

    find_rule_in = require '../find_rule_in'
    seem = require 'seem'

    class CCNQBaseMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:ruleset"
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
      assert @cfg.ruleset_of?, 'Missing `ruleset_of`.'

    @include = seem ->

      return unless @session.direction is 'lcr'

      provisioning = @cfg.prov
      ruleset_of = @cfg.ruleset_of
      default_outbound_route = @cfg.default_outbound_route

Routing table selection
=======================

We first need to determine which routing table we should use, though.
This is based on the calling number.

      return if @res.finalized()

Route based on the route selected by the source, or using a default route.

      source = @source

* doc.global_number.outbound_route (number) Route used for Least Cost Routing (LCR).

      doc = yield provisioning
        .get "number:#{source}"
        .catch (error) =>
          debug "RuleSet Middleware: error retrieving number:#{source}", error.stack ? error.toString()
          {}

      debug "RuleSet Middleware: number:#{source} :", doc
      route = doc.outbound_route ? default_outbound_route

Provisioning error

      unless route?
          debug 'RuleSet Middleware: No route available', {source}
          cuddly.dev 'missing-route', {source}
          yield @res.respond '485'
          return

      route = "#{route}"
      @res.route = route

Ruleset selection
=================

      debug "RuleSet Middleware: loading ruleset_of", {source,route}
      {ruleset,ruleset_database} = yield ruleset_of route

Management error

      unless ruleset? and ruleset_database?
          debug 'No ruleset available', {source,route:@res.route,ruleset,ruleset_database}
          cuddly.dev 'missing-ruleset', {source,route:@res.route,ruleset,ruleset_database}
          yield @res.respond '500'
          return

      @res.ruleset = ruleset
      @res.ruleset_database = ruleset_database

Rule lookup
===========

      rule = yield find_rule_in @res.destination,ruleset_database
        .catch (error) ->
          null

Provisioning error or user error

      unless rule?
          debug 'No route available', {source,destination:@res.destination,ruleset:@res.ruleset}
          cuddly.dev 'missing-rule', {source,destination:@res.destination,ruleset:@res.ruleset}
          yield @res.respond '485'
          return

* doc.rule.gwlist (array) List of gateways/carriers for this rule. Has priority over the `destination` field.

      if rule.gwlist?
        @res.gateways = rule.gwlist
        delete rule.gwlist

      else

Missing gateway list is normal for e.g. emergency call routing.

          debug 'Missing gwlist (ignored)', rule
          cuddly.dev 'missing-gwlist', {rule}

      @res.rule = rule

* doc.rule.attrs (object) Extra attributes for this rule.

      @res.attr rule.attrs
      return

    assert = require 'assert'
    debug = (require 'debug') @name
    cuddly = (require 'cuddly') @name
