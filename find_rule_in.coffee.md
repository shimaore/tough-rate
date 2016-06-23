Longest-match rule lookup
=========================

    seem = require 'seem'
    pkg = require './package'
    @name = "#{pkg.name}:find_rule_in"
    debug = (require 'debug') @name

    module.exports = find_rule_in = seem (destination,database) =>
      debug 'find', destination

      ids = ("rule:#{destination[0...l]}" for l in [0..destination.length]).reverse()

      {rows} = yield database.allDocs keys:ids, include_docs: true
      rule = (row.doc for row in rows when row.doc? and not row.doc.disabled)[0]

Lookup the `destination` if any (and no `gwlist` is provided).

* doc.rule.destination (string) doc.destination identifier for the rule. Used only if not `gwlist` is present.
* doc.destination Destination for a doc.rule.
* doc.destination._id "destination:{destination}"
* doc.destination.gwlist (array) List of gateways/carriers for this destination.

      if not rule.gwlist? and rule.destination?
        debug 'destination', rule.destination
        rule = yield database
          .get "destination:#{rule.destination}"
          .catch (error) ->
            debug 'destination', rule.destination, error.stack ? error.toString()
            {}

      debug 'rule', rule
      rule
