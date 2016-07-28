    describe 'The modules', ->
      for m in [
        'field_merger'
        'find_rule_in'
        'gateway_manager'
        'index'
        'promise-all'
        'status'
        'middleware/alternate-response'
        'middleware/call-handler'
        'middleware/cdr'
        'middleware/emergency'
        'middleware/flatten'
        'middleware/format-matcher'
        'middleware/local-number'
        'middleware/numeric'
        'middleware/override-route-from-endpoint'
        'middleware/post-send'
        'middleware/response-handlers'
        'middleware/routes-carrierid'
        'middleware/routes-gwid'
        'middleware/routes-registrant'
        'middleware/ruleset'
        'middleware/setup'
        'middleware/use-ccnq-to-e164'
        'middleware/use-session-gateways'

        'middleware/config'
        'middleware/server'
      ]
       do (m) ->
         it "should load #{m}", ->
           M = require "../#{m}"
           if m.match /^middleware/
             ctx =
               session: {}
             M.include.call ctx, ctx
