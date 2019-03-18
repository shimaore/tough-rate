Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    registrant_fields =
      registrant_password:    'X-RP'
      registrant_username:    'X-RU'
      registrant_realm:       'X-RR'
      registrant_remote_ipv4: 'X-RT'
      registrant_socket:      'X-RH'

* doc.global_number.registrant_password (string) password for registrant; it is used to authenticate with a remote registrar.
* doc.global_number.registrant_username (string) username for registrant; it is used to authenticate with a remote registrar.
* doc.global_number.registrant_realm (string) authentication realm for registrant
* doc.global_number.registrant_remote_ipv4 (string) registrar name or IP address, for registrant
* doc.global_number.registrant_socket (string) local bind socket for registrant, as `{ip}:{port}`

    default_port = 5070

    update = (entry,source_doc) ->
      unless entry.source_registrant? and entry.source_registrant is true
        debug "Routes Registrant: entry is not source_registrant, skipping", entry
        return entry

      return if source_doc.disabled

* doc.global_number.address (string, internal) If specified, the registrant routing address (i.e. the host and port to send the call to). The field might also be created by a custom session.ref_builder function, for example to translate a doc.global_number.registrant_host to the matching carrier-side SBC. Default: doc.global_number.registrant_host is used.
* doc.global_number.registrant_host (string) If specified, the host (default port: 5070) or the `{host}:{port}` used as the registrant routing address (i.e. the host and port for our registrant OpenSIPS server). Should match the value of doc.global_number.registrant_socket (except it might use a host-name instead of an IP address).

      gateways = []

      if source_doc.address?
        address = source_doc.address
      else
        address = source_doc.registrant_host
        unless address?
          debug 'No registrant_host for source in a route that requires registrant.', source_doc
          return gateways

        debug "Routes Registrant: mapping registrant", source_doc

Deprecated: doc.global_number.registrant_host (array)

        if 'string' isnt typeof address
          address = address[0]

        address = "#{address}:#{default_port}" unless address.match /:/

      gateway = {address}

* doc.global_number.rating (object) typically injected by session.ref_builder, contains an `entertaining-crib` `rating` object.
* doc.global_number.timezone (string) typically injected by session.ref_builder, contains an `entertaining-crib` `timezone` string.

      gateway.rating = source_doc.rating if source_doc.rating?
      gateway.timezone = source_doc.timezone if source_doc.timezone?
      gateway.codecs = source_doc.codecs if source_doc.codecs?

      gateway.headers ?= {}
      for field, header of registrant_fields
        gateway.headers[header] = source_doc[field] if source_doc[field]?

      gateways.push gateway
      {destination_number} = entry
      gateways.map (gw) -> Object.assign gw, {destination_number}

* session.ref_builder (function) Computes a data record for registrant routing; the first parameter is the provisioning database, the second parameter is the source (calling) number. Default: returns the doc.global_number provisioning record for `number:{source}`.

    build_ref = (provisioning,source) ->
      debug "Routes Registrant build_ref locating #{source}."
      provisioning.get "number:#{source}"

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:routes-registrant"
    {debug} = (require 'tangible') @name
    @include = ->

      return unless @session?.direction is 'lcr'

      if @res.finalized()
        debug 'Routes Registrant: already finalized.'
        return

      ref_builder = @session.ref_builder ? build_ref
      delete @session.ref_builder

      provisioning = new CouchDB (Nimble @cfg).provisioning

      source_doc = await ref_builder
        .call this, provisioning, @session.asserted_number ? @source
        .catch -> null

      return unless source_doc?

      @res.gateways = await promise_all @res.gateways, (x) => update x, source_doc

      debug 'Gateways', @res.gateways
      return

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb'
