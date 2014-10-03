Gateway (and carriers) manager
==============================

The gateway manager provides services to the call handler.

    default_parameters =
      disabled: false
      progress_timeout: 4
      answer_timeout: 90
      dialog_timeout: 28800
      attrs: {}
      local_gateway_extra_priority: 0.5
      weight: 1

    module.exports = class GatewayManager

      constructor: (@provisioning,@sip_domain_name) ->
        @carriers = {}
        @gateways = {}

      init: ->
        @provisioning
        .bulkDocs startkey:"carrier:", endkey:"carrier;"
        .then ({rows}) =>
          for row in rows
            do (row) => @_merge_carrier_row row

        @provisioning
        .query "#{pkg.name}-gateway-manager/gateways", startkey:[@sip_domain_name], endkey:[@sip_domain_name,{}]
        .then ({rows}) =>
          for row in rows when row.value?.address?
            do (row) => @_merge_gateway_row row

        # TODO Add monitoring of `_changes` on the view to update carriers and gateways

      _merge_gateway_row: (row) ->
        # TODO Add handling of `deleted` rows.
        {gwid,carrierid} = row.value
        assert gwid?
        @gateways[gwid] = field_merger
          default: default_parameters
          # options: options
          carrier: @carriers[carrierid]
          gateway: row.value

        if carrierid?
          @carriers[carrierid] ?= _gateways: {}
          @carriers[carrierid]._gateways[gwid] = @gateways[gwid]

      _merge_carrier_row: (row) ->
        # TODO Add handling of `deleted` rows.
        carrierid = row.value.carrierid
        assert carrierid
        if row.deleted or row.value?._deleted
          delete @carriers[carrierid]
        else
          @carriers[carrierid] ?= _gateways: {}
          for own k,v of row.value
            @carriers[carrierid][k] = v

      retrieve_gateway: (name) ->
        new Promise (resolve,reject) =>
          if @gateways[name]?
            resolve @gateways[name]
          else
            reject "No gateway named #{name}"

      retrieve_carrier: (name) ->
        new Promise (resolve,reject) =>
          if @carriers[name]?
            resolve @carriers[name]
          else
            reject "No carrier named #{name}"


Gateway and carrier properties mapping
--------------------------------------

      resolve: (gws) ->
        Promise.map (x) ->
          if name[0] is '#'
            resolve_carrier name[1..]
          else
            resolve_gateway name
        .then (list) ->
          gws = []
          gws.concat array for array in list

Return gateway data as long as that gateway is available.

      resolve_gateway: (name) ->
        @retrieve_gateway name
        .then (info) ->
          if info.disabled or info.temporarily_disabled
            []
          else
            [info]

      ###
      resolve_carrier:  (name) ->
        retrieve_carrier name
        .then (names) ->
          Promise.map names, resolve_gateway
        .filter (x) -> x?

      ###


Gateway ping
------------

Pings a gateway to confirm it is still alive.

Gateway temporary disable
-------------------------

Disable a gateway temporarily, for example because it is rejecting too many calls.

Carrier temporary disable
-------------------------

Disable a carrier temporarily, for example because it is rejecting too many calls.

Provisioning monitoring
-----------------------

Monitors `_changes` on the provisioning views to automatically update the internal status of gateways, carriers, etc.

Toolbox
=======

    pkg = require './package.json'
    design = "#{pkg.name}-gateway-manager"
    p_fun = (f) -> "(#{f})"

    GatewayManager.couch =
      _id: "_design/#{design}"
      language: "application/javascript"

For an individual gateway we expect the following fields must be present in the view:

- `sip_domain_name`
- `gwid`
- `address`

The following fields are optional:

- `carrierid`
- `disabled`
- `progress_timeout`
- `answer_timeout`
- `dialog_timeout`
- `attrs`


      views:
        gateways:
          map: p_fun (doc) ->
            if doc.type? and doc.type is 'gateway'
              emit [doc.sip_domain_name, doc.carrierid], doc

            if doc.type? and doc.type is 'host' and doc.sip_profiles?
              for name, rec of doc.sip_profiles
                do (rec) ->
                  # for now we only generate for egress gateways
                  ip = rec.egress_sip_ip ? rec.ingress_sip_ip
                  port = rec.egress_sip_port ? rec.ingress_sip_port+10000

                  rec.egress ?= {}
                  rec.egress.gwid ?= rec.egress_gwid
                  rec.egress.address ?= [ip,port].join ':'
                  if rec.egress.gwid?
                    emit [doc.sip_domain_name, rec.carrierid], rec.egress

            return

    field_merger = require './field_merger'
    assert = require 'assert'
    Promise = require 'bluebird'
