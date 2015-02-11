    @Router = require './router'
    @GatewayManager = require './gateway_manager'
    @CallServer = require './call_server'

    {p_fun} = require 'coffeescript-helpers'

The design document that must be installed on the master databases in order for tough-rate hosts to replicate the proper data.

    @couch =
      _id: "_design/tough-rate-source"
      language: "javascript"

      filters:
        replication: p_fun (doc,req) ->

Do not attempt to replicate CouchDB-special documents (especially `_design` documents).

            if doc._id[0] is '_'
              return false

Since (for now) we do not enforce changes to respect replication filters, use the `_id` to guess the doc type.

            replicate_types = ['config','number','gateway','carrier','ruleset','destination','emergency','host']

            type_from_id = doc._id.split(':')[0]

            if doc._deleted? and doc._deleted and type_from_id in replicate_types
              return true

Make sure we're replicating a somewhat-consistent document though.

            if not doc.type? or doc.type isnt type_from_id or not doc[doc.type]?
              return false

We only replicate some documents types, not all of them.

            if doc.type not in replicate_types
              return false

If a `sip_domain_name` was provided in the query and the document contains a `sip_domain_name`, only replicate if they match.

            if req.query.sip_domain_name? and doc.sip_domain_name? and req.query.sip_domain_name isnt doc.sip_domain_name
              return false

            return true
