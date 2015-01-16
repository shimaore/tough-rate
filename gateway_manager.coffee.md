Gateway (and carriers) manager
==============================

The gateway manager provides services to the call handler.

    default_parameters =
      disabled: false
      progress_timeout: 12
      answer_timeout: 90
      dialog_timeout: 28800
      attrs: {}
      local_gateway_first: true
      weight: 1
      try: 1

    module.exports = class GatewayManager

      constructor: (@provisioning,@sip_domain_name,@logger = require 'winston') ->
        @carriers = {}
        @gateways = {}
        @gateway_status = {}
        assert @provisioning, "GatewayManager: provisioning DB is required"
        assert @sip_domain_name, "GatewayManager: sip_domain_name is required"
        @default_parameters = {}
        for own k,v of default_parameters
          @default_parameters[k] ?= v
        @logger.info "GatewayManager #{pkg.name} #{pkg.version} for #{@sip_domain_name}: waiting for init()"

`set` accepts either `set(name,value)` or `set({name:value,name2:value,...})`.

      set: (name,value) ->
        if typeof name is 'string'
          @default_parameters[name] = value
        else
          for own k,v of name
            @default_parameters[k] = v

      init: ->
        Promise.resolve()
        .then =>
          @provisioning
          .allDocs startkey:"carrier:#{@sip_domain_name}:", endkey:"carrier:#{@sip_domain_name};", include_docs:yes
        .catch (error) =>
          @logger.error error
          @logger.info "GatewayManager allDocs failed"
          throw error
        .then ({rows}) =>
          for row in rows
            do (row) => @_merge_carrier_row row
          return
        .catch (error) =>
          @logger.error error
          @logger.info "GatewayManager merge-carrier-row failed"
          throw error
        .then =>
          @provisioning
          .query "#{pkg.name}-gateway-manager/gateways", startkey:[@sip_domain_name], endkey:[@sip_domain_name,{}]
        .catch (error) =>
          @logger.error error
          @logger.info "GatewayManager query failed"
          throw error
        .then ({rows}) =>
          for row in rows when row.value?.address?
            do (row) => @_merge_gateway_row row
          return
        .catch (error) =>
          @logger.error error
          @logger.info "GatewayManager merge-gateway-row failed"
          throw error
        .then =>
          @logger.info "GatewayManager for #{@sip_domain_name}: gateways = #{JSON.stringify @gateways}"
          @logger.info "GatewayManager for #{@sip_domain_name}: carriers = #{JSON.stringify @carriers}"
          return

        # TODO Add monitoring of `_changes` on the view to update carriers and gateways

      _merge_gateway_row: (row) ->
        @logger.info "GatewayManager merge-gateway-row #{JSON.stringify row}"
        {gwid,carrierid} = row.value
        assert gwid?

        if row.deleted or row.doc?._deleted
          if carrierid?
            delete @carriers[carrierid]?._gateways[gwid]
          delete @gateways[gwid]
          return

        if carrierid?
          @gateways[gwid] = field_merger
            default: @default_parameters
            carrier: @carriers[carrierid]
            gateway: row.value

          @carriers[carrierid] ?= _gateways: {}
          @carriers[carrierid]._gateways[gwid] = true
        else
          @gateways[gwid] = field_merger
            default: @default_parameters
            gateway: row.value

      _reevaluate_gateways: (gateways) ->
        @provisioning
        .query "#{pkg.name}-gateway-manager/gateways", keys:gateways.map (x) => [@sip_domain_name,x]
        .then ({rows}) =>
          for row in rows when row.value?.address?
            do (row) => @_merge_gateway_row row
        .catch (error) ->
          @logger.error "GatewayManager reevaluate_gateways: #{error}"

      _merge_carrier_row: (row) ->
        @logger.info "GatewayManager merge-carrier-row #{JSON.stringify row}"
        carrierid = row.doc.carrierid
        assert carrierid?

        if row.deleted or row.doc?._deleted
          gateways = @carriers[carrierid]._gateways
          delete @carriers[carrierid]
          @_reevaluate_gateways gateways
          return

        @carriers[carrierid] ?= _gateways: {}
        for own k,v of row.doc
          @carriers[carrierid][k] = v

        return

      _retrieve_gateway: (name) ->
        # TODO update with dynamic parameters (temporarily_disabled, ...)
        info = {}
        info[k] = v for own k,v of @gateways[name]
        info.temporarily_disabled = @gateway_status[name]?.state in ['faulty']
        Promise.resolve info

      _retrieve_carrier: (name) ->
        Promise.resolve @carriers[name]


Gateway and carrier properties mapping
--------------------------------------

Return gateway data (inside a list) as long as that gateway is available.

      resolve_gateway: (name) ->
        @_retrieve_gateway name
        .then (info) ->
          if not info?
            return []
          if info.disabled or info.temporarily_disabled
            return []
          [info]

Return gateway data (inside a list) for a given carrier.

      resolve_carrier:  (name) ->
        carrier = {}
        @_retrieve_carrier name
        .then (carrier) =>
          if not carrier?
            return []
          if not carrier._gateways?
            return []
          gateways = Object.getOwnPropertyNames carrier._gateways

Note: we could do `@resolve gateways` instead here and allow carrier-within-carrier, but I'm concerned about recursion issues so let's skip that for now.

          Promise.map gateways, (gw) =>
            @resolve_gateway gw
        .map ([x]) -> x

Gateway ping
------------

Pings a gateway to confirm it is still alive.

Gateway temporary disable
-------------------------

Disable a gateway temporarily, for example because it is rejecting too many calls.

      mark_gateway_as_faulty: (name) ->
        @logger.error "GatewayManager mark-gateway-as-faulty: #{name}."
        status = @gateway_status[name] ?= new Status()
        status.mark_as_faulty()

Mark a gateway as suspicious.

      mark_gateway_as_suspicious: (name) ->
        @logger.error "GatewayManager mark-gateway-as-suspicious: #{name}."
        status = @gateway_status[name] ?= new Status()
        status.mark_as_suspicious()


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
    {p_fun} = require 'coffeescript-helpers'

    GatewayManager.couch =
      _id: "_design/#{design}"
      language: "javascript"

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
            return unless doc.type?

            if doc.type is 'gateway'
              return emit [doc.sip_domain_name, doc.carrierid], doc

            if doc.type is 'host' and doc.sip_profiles?
              for name, rec of doc.sip_profiles
                do (rec) ->
                  # for now we only generate for egress gateways
                  ip = rec.egress_sip_ip ? rec.ingress_sip_ip
                  port = rec.egress_sip_port ? rec.ingress_sip_port+10000

                  egress = {}
                  egress[k] = v for own k,v of rec.egress
                  egress.gwid ?= rec.egress_gwid
                  egress.address ?= [ip,port].join ':'
                  egress.host ?= doc.host
                  if egress.gwid?
                    emit [doc.sip_domain_name, egress.carrierid], egress
                  return

            return

    field_merger = require './field_merger'
    assert = require 'assert'
    Promise = require 'bluebird'
    Status = require './status'
