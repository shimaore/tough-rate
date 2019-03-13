Ruleset Loader
==============

    find_rule_in = require '../find_rule_in'

    class CCNQBaseMiddlewareError extends Error

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:ruleset"
    {debug} = (require 'tangible') @name
    @init = ->
      assert @cfg.ruleset_of?, 'Missing `ruleset_of`.'

    @include = ->

      return unless @session?.direction is 'lcr'

      prov = new CouchDB (Nimble @cfg).provisioning
      ruleset_of = @cfg.ruleset_of
      default_outbound_route = @cfg.default_outbound_route

Routing table selection
=======================

We first need to determine which routing table we should use, though.
This is based on the calling number.

      return if @res.finalized()

Route based on the route selected by the source, or using a default route.

      source = @res.source

* doc.global_number.outbound_route (number) Route used for Least Cost Routing (LCR).

      route = null
      try
        debug "RuleSet Middleware: number:#{source}"
        doc = await prov.get "number:#{source}"
        route = doc.outbound_route ? default_outbound_route

Provisioning error

      unless route?
        debug.dev 'missing-route: No route available', {source}
        await @res.respond '485'
        return

      route = "#{route}"
      @res.route = route

Ruleset selection
=================

      debug "RuleSet Middleware: loading ruleset_of", {source,route}
      {ruleset,ruleset_database} = await ruleset_of route

Management error

      unless ruleset? and ruleset_database?
        debug.dev 'missing-ruleset: No ruleset available', {source,route:@res.route,ruleset,db:ruleset_database.name}
        await @res.respond '500'
        return

      @res.ruleset = ruleset
      @res.ruleset_database = ruleset_database

      debug 'Using ruleset', {source,route:@res.route,ruleset,db:ruleset_database.name}

Rule lookup
===========

* doc.ruleset.key (string) The type used for routing rules in the ruleset database. Default: "prefix".

      rule = null
      try
        rule = await find_rule_in @res.destination, ruleset_database, @res.ruleset.key

Provisioning error or user error

      unless rule?
        debug.dev 'missing-rule: No route available', {source,destination:@res.destination,ruleset:@res.ruleset}
        await @res.respond '485'
        return

* doc.prefix.gwlist (array) List of gateways/carriers for this rule.
* doc.destination.gwlist (array) List of gateways/carriers for this rule.

      if rule.gwlist?
        @res.gateways = rule.gwlist
        delete rule.gwlist

      else

Missing gateway list is normal for e.g. emergency call routing.

        debug.dev 'missing-gwlist: Missing gwlist (ignored)', rule

      @res.rule = rule

      debug 'Using rule', rule

* doc.prefix.attrs (object) Extra attributes for this rule.
* doc.destination.attrs (object) Extra attributes for this rule.

      @res.attr rule.attrs
      return

    assert = require 'assert'
    CouchDB = require 'most-couchdb'
    Nimble = require 'nimble-direction'
