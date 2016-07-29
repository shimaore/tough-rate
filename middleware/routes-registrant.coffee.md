Registrant plugin
=================

This plugin provides `registrant_host` as a gateway.

    registrant_fields =
      registrant_password:    'X-CCNQ3-Registrant-Password'
      registrant_username:    'X-CCNQ3-Registrant-Username'
      registrant_realm:       'X-CCNQ3-Registrant-Realm'
      registrant_remote_ipv4: 'X-CCNQ3-Registrant-Target'
      registrant_socket:      'X-CCNQ3-Registrant-HostPort'

* doc.global_number.registrant_password (string) password for registrant; it is used to authenticate with a remote registrar.
* doc.global_number.registrant_username (string) username for registrant; it is used to authenticate with a remote registrar.
* doc.global_number.registrant_realm (string) authentication realm for registrant
* doc.global_number.registrant_remote_ipv4 (string) registrar name or IP address, for registrant
* doc.global_number.registrant_socket (string) local bind socket for registrant, as `{ip}:{port}`

    default_port = 5070

    update = (entry,ref) ->
      unless entry.source_registrant? and entry.source_registrant is true
        debug "Routes Registrant: entry is not source_registrant, skipping", entry
        return entry

      ref
      .then (source_doc) =>
        return if source_doc.disabled

* doc.global_number.address (string, internal) If specified, the registrant routing address (i.e. the host and port to send the call to). The field might also be created by a custom session.ref_builder function, for example to translate a doc.global_number.registrant_host to the matching carrier-side SBC. Default: doc.global_number.registrant_host is used.
* doc.global_number.registrant_host (string) If specified, the host (default port: 5070) or the `{host}:{port}` used as the registrant routing address (i.e. the host and port for our registrant OpenSIPS server). Should match the value of doc.global_number.registrant_socket (except it might use a host-name instead of an IP address).

        result = []

        if source_doc.address?
          address = source_doc.address
        else
          address = source_doc.registrant_host
          unless address?
            debug 'No registrant_host for source in a route that requires registrant.', source_doc
            return result

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

        gateway.headers ?= {}
        for field, header of registrant_fields
          gateway.headers[header] = source_doc[field] if source_doc[field]?

        result.push gateway
        result

* session.ref_builder (function) Computes a data record for registrant routing; the first and only parameter is the provisioning database. Default: returns the doc.global_number provisioning record for `number:{@source}`.

    build_ref = (provisioning) ->
      debug "Routes Registrant build_ref locating #{@source}."
      provisioning.get "number:#{@source}"

    pkg = require '../package.json'
    @name = "#{pkg.name}:middleware:routes-registrant"
    @init = ->
      assert @cfg.prov?, 'Missing `prov`.'
    @include = ->

      return unless @session.direction is 'lcr'

      ref_builder = @session.ref_builder ? build_ref
      provisioning = @cfg.prov

      if @res.finalized()
        debug 'Routes Registrant: already finalized.'
        return
      ref = ref_builder.call this, provisioning
      promise_all @res.gateways, (x) => update.call this, x, ref
      .then (gws) =>
        @res.gateways = gws
      .catch (error) =>
        debug "Routes Registrant: #{error}"

Toolbox
-------

    assert = require 'assert'
    promise_all = require '../promise-all'
    debug = (require 'debug') @name
