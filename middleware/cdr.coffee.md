    @name = 'cdr'
    @include = ->

      @call.once 'CHANNEL_HANGUP_COMPLETE'
      .then (res) =>
        debug "CDR: Channel Hangup Complete"
        data = res.body

        debug "CDR: Channel Hangup Complete", billmsec: data.variable_billmsec
        data =
          duration:       data.variable_mduration
          billable:       data.variable_billmsec
          progress:       data.variable_progressmsec
          answer:         data.variable_answermsec
          wait:           data.variable_waitmsec
          progress_media: data.variable_progress_mediamsec
          flow_bill:      data.variable_flow_billmsec

        for own k,v of data
          @statistics.add k, v
          @statistics.add ["#{k}-gw",@session.gateway?.gwid], v
          @statistics.add ["#{k}-gw",@session.gateway?.gwid,@rule?.prefix], v
          @statistics.add ["#{k}-carrier",@session.gateway?.carrierid], v
          @statistics.add ["#{k}-carrier",@session.gateway?.carrierid,@rule?.prefix], v

        @statistics.emit 'call',
          state: 'end'
          call: @call.uuid
          source: @source
          destination: @destination
          data: data

Compatibility layer for CCNQ3 -- remove once the LCR generates its own CDRs.

      attrs = {}
      for own k,v of @res.attrs when v?
        attrs[k] = v
      @set 'sip_h_X-CCNQ3-Attrs', JSON.stringify attrs

      null

    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:cdr"

variable_mduration: # total duration
variable_billmsec: # billable (connected)
variable_progressmsec: # progress
variable_answermsec: # answer
variable_waitmsec: # wait = answer?
variable_progress_mediamsec: # 0
variable_flow_billmsec: # total duration
