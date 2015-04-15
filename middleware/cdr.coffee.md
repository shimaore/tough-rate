    module.exports = ->
      cdr_base = @cfg.options.cdr_base

      middleware = ->

        @call.once 'CHANNEL_HANGUP_COMPLETE'
        .then (res) =>
          @logger.info "CDR: Channel Hangup Complete"
          data = res.body

          @logger.info "CDR: Channel Hangup Complete", billmsec: data.variable_billmsec
          @statistics.add 'duration', data.variable_mduration
          @statistics.add 'billable', data.variable_billmsec
          @statistics.add 'progresss', data.variable_progressmsec
          @statistics.add 'answer', data.variable_answermsec
          @statistics.add 'wait', data.variable_waitmsec
          @statistics.add 'progress_media', data.variable_progress_mediamsec
          @statistics.add 'flow_bill', data.variable_flow_billmsec

Compatibility layer for CCNQ3 -- remove once the LCR generates its own CDRs.

        attrs = {}
        for own k,v of @res.attrs when v?
          attrs[k] = v
        @set 'sip_h_X-CCNQ3-Attrs', JSON.stringify attrs

        null

      middleware.info = "#{pkg.name} #{pkg.version} #{module.filename}"
      middleware.call this

    pkg = require '../package.json'

variable_mduration: # total duration
variable_billmsec: # billable (connected)
variable_progressmsec: # progress
variable_answermsec: # answer
variable_waitmsec: # wait = answer?
variable_progress_mediamsec: # 0
variable_flow_billmsec: # total duration
