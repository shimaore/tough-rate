The steps to placing outbound call(s) are:
- gather the rule for the given prefix and environment
- from that rule's gwlist, build a single list of unique gateways we will attempt in order
- place the calls

    dataset_1 =
      gateways:
        gw1:
          _id:'gateway:phone.local:gw1'
          type:'gateway'
          sip_domain_name:'phone.local'
          gwid:'gw1'
          address:'127.0.0.1:5066'
          carrierid:'the_phone_company'
          attrs:
            gateway_name:'gw1'
        gw2:
          _id:'gateway:phone.local:gw2'
          type:'gateway'
          sip_domain_name:'phone.local'
          gwid:'gw2'
          address:'127.0.0.1:5067'
          carrierid:'the_phone_company'
          attrs:
            gateway_name:'gw2'
        gw3:
          _id:'gateway:phone.local:gw3'
          type:'gateway'
          sip_domain_name:'phone.local'
          gwid:'gw3'
          address:'127.0.0.1:5068'
          carrierid:'the_other_company'
          attrs:
            gateway_name:'gw3'
        gw4:
          _id:'gateway:phone.local:gw4'
          type:'gateway'
          sip_domain_name:'phone.local'
          gwid:'gw4'
          address:'127.0.0.1:5069'
          carrierid:'the_other_company'
          attrs:
            gateway_name:'gw4'
        backup:
          _id:'gateway:phone.local:backup'
          type:'gateway'
          gwid:'backup'
          address:'127.0.0.1:5070'
          sip_domain_name:'phone.local'
          gwid:'backup'

      carriers:
        the_phone_company:
          _id:'carrier:phone.local:the_phone_company'
          type:'carrier'
          sip_domain_name:'phone.local'
          carrierid:'the_phone_company'
          progress_timeout: 20

      destinations:
        france:
          _id:'destination:france'
          type:'destination'
          destination:'france'

      rulesets:
        default:
          _id:'ruleset:phone.local:default'
          type:'ruleset'
          sip_domain_name:'phone.local'
          groupid:'default'
          title:'The default ruleset'
          database: 'the_default_ruleset'
        registrant:
          _id:'ruleset:phone.local:registrant'
          type:'ruleset'
          sip_domain_name:'phone.local'
          groupid:'registrant'
          title:'The registrant ruleset'
          database: 'the_registrant_ruleset'


      emergency:
        '330112#brest':
          _id:'emergency:330112#brest'
          type:'emergency'
          destination:'33156'

      rules:
        default:
          33:
            _id:'rule:33'
            type:'rule'
            prefix:'33'
            destination:'france'
            gwlist:[
              {carrierid:'the_other_company'}
              {gwid:'backup'}
            ]

          336:
            _id:'rule:336'
            type:'rule'
            prefix:'336'
            destination:'france_mobile'
            gwlist: [
              {carrierid:'the_other_company'}
              {carrierid:'the_phone_company'}
            ]

          330112:
            _id:'rule:330112'
            type:'rule'
            prefix:'330112'
            destination:'france_emergency'
            emergency:true

        registrant:
          33:
            _id:'rule:33'
            type:'rule'
            prefix:'33'
            destination:'france'
            gwlist:[
              {source_registrant:true}
            ]

    should = require 'should'
    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    pkg = require '../package.json'
    GatewayManager = require '../gateway_manager'
    ToughRateRouter = require '../router'
    logger = require 'winston'
    logger.transports.Console.level = 'error'
    Promise = require 'bluebird'

    class FreeSwitchError extends Error
      constructor:(@res,@args) ->

      toString: ->
        JSON.stringify @args

    describe 'Once the database is loaded', ->
      dataset = dataset_1
      provisioning = null
      gm = null

Note: normally ruleset_of would be async, and would query provisioning to find the ruleset and then map it to its database.

      ruleset_of = (x) ->
        if not dataset.rulesets[x]?
          logger "Unknown ruleset #{x}."
          throw "Unknown ruleset #{x}"
        response =
          ruleset: dataset.rulesets[x]
          ruleset_database: new PouchDB dataset.rulesets[x].database

      ready = PouchDB.destroy 'provisioning'
      .then ->
        provisioning = new PouchDB 'provisioning'
        records = []
        (records.push v) for k,v of dataset.gateways
        (records.push v) for k,v of dataset.carriers
        (records.push v) for k,v of dataset.destinations
        (records.push v) for k,v of dataset.emergency
        provisioning.bulkDocs records

      ready = ready.then ->
        PouchDB.destroy dataset.rulesets.default.database
      .then ->
        default_ruleset = new PouchDB dataset.rulesets.default.database
        rules = []
        (rules.push v) for k,v of dataset.rules.default
        default_ruleset.bulkDocs rules

      ready = ready.then ->
        PouchDB.destroy dataset.rulesets.registrant.database
      .then ->
        the_ruleset = new PouchDB dataset.rulesets.registrant.database
        rules = []
        (rules.push v) for k,v of dataset.rules.registrant
        the_ruleset.bulkDocs rules

      ready = ready.then ->
        GatewayManager.should.have.property 'couch'
        GatewayManager.couch.should.have.property 'views'
        GatewayManager.couch.views.should.have.property 'gateways'
        GatewayManager.couch.views.gateways.should.have.property 'map'
        provisioning.put GatewayManager.couch
      .then ->
        provisioning.get "_design/#{pkg.name}-gateway-manager"
      .then (doc) ->
          doc.should.have.property 'views'
          doc.views.should.have.property 'gateways'
      .then ->
        gm = new GatewayManager provisioning, 'phone.local', logger
        gm.set 'progress_timeout', 4
        gm.init()

      call_ = (source,destination,emergency_ref) ->
        call =
          data:
            'Channel-Caller-ID-Number': source
            'Channel-Destination-Number': destination
            'variable_sip_h_X-CCNQ3-Routing': emergency_ref

      one_call = (ctx,outbound_route) ->
        ctx.once ?= ->
          then: ->
        ready.then ->
          logger.info "Building router."
          router = new ToughRateRouter logger
          us =
            gateway_manager: gm
            options: {
              provisioning
              ruleset_of
              default_outbound_route: outbound_route
              profile: 'something-egress'
            }
          router.use (require '../middleware/numeric').call us, router
          router.use (require '../middleware/response-handlers').call us, router
          router.use (require '../middleware/local-number').call us, router
          router.use (require '../middleware/ruleset').call us, router
          router.use (require '../middleware/emergency').call us, router
          router.use (require '../middleware/routes-gwid').call us, router
          router.use (require '../middleware/routes-carrierid').call us, router
          router.use (require '../middleware/routes-registrant').call us, router
          router.use (require '../middleware/flatten').call us, router
          router.use (require '../middleware/cdr').call us, router
          router.use (require '../middleware/call-handler').call us, router
          logger.info "Sending one_call to router."
          router.route ctx
        .catch (exception) ->
          logger "Exception setting up one_call", exception
          throw exception
        null

      describe 'Gateways', ->
        it 'should have progress_timeout from their carrier: gw1', (done) ->
          ready.then ->
            gm.resolve_gateway 'gw1'
            .then (doc) ->
              doc.should.have.length 1
              doc.should.be.an.instanceOf Array
              doc.should.have.property 0
              doc[0].should.have.property 'progress_timeout'
              doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
              done()

        it 'should have progress_timeout from their carrier: gw2', (done) ->
          ready.then ->
            gm.resolve_gateway 'gw2'
            .then (doc) ->
              doc.should.have.length 1
              doc.should.be.an.instanceOf Array
              doc.should.have.property 0
              doc[0].should.have.property 'gwid', 'gw2'
              doc[0].should.have.property 'progress_timeout'
              doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
              done()

      describe 'the_phone_company', ->
        it 'should return its gateways', (done) ->
          ready.then ->
            gm.resolve_carrier 'the_phone_company'
            .then (info) ->
              should(info).be.an.instanceOf Array
              info.should.have.length 2
              info.should.have.property 0
              info[0].should.have.property 'gwid', 'gw1'
              info.should.have.property 1
              info[1].should.have.property 'gwid', 'gw2'
              done()

      describe 'The call router', ->
        it 'should route local numbers directly', ->
          ready.then ->
            provisioning.put _id:'number:1234',inbound_uri:'sip:foo@bar'
          .then ->
            router = new ToughRateRouter logger
            us = options: {provisioning,ruleset_of}
            router.use (require '../middleware/local-number').call us, router
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '3213', '1234'
          .then (ctx) ->
            ctx.should.have.property 'res'
            ctx.res.should.have.property 'gateways'
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'uri', 'sip:foo@bar'

        it 'should route registrant_host directly (adding default port)', ->
          ready.then ->
            provisioning.put _id:'number:3213',registrant_host:'foo',registrant_password:'badabing'
          .then ->
            router = new ToughRateRouter logger
            us = options: {provisioning,ruleset_of,default_outbound_route:'registrant'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/routes-registrant').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '3213', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'address', 'foo:5070'
            gws[0].should.have.property 'headers'
            gws[0].headers.should.have.property 'X-CCNQ3-Registrant-Password', 'badabing'

        it 'should route registrant_host directly (using provided port)', ->
          ready.then ->
            provisioning.put _id:'number:3243',registrant_host:'foo:5080'
          .then ->
            router = new ToughRateRouter logger
            us = options: {provisioning,ruleset_of,default_outbound_route:'registrant'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/routes-registrant').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '3243', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'address', 'foo:5080'

        it 'should route registrant_host directly (using array)', ->
          ready.then ->
            provisioning.put _id:'number:3253',registrant_host:['foo:5080']
          .then ->
            router = new ToughRateRouter logger
            us = options: {provisioning,ruleset_of,default_outbound_route:'registrant'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/routes-registrant').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '3253', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'address', 'foo:5080'

        it 'should route numbers using routes', ->
          ready.then ->
            router = new ToughRateRouter logger
            us =
              gateway_manager: gm
              options: {provisioning,ruleset_of,default_outbound_route:'default'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/routes-gwid').call us, router
            router.use (require '../middleware/routes-carrierid').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '336718', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 2
            gws.should.have.property 0
            gws[0].should.have.property 'gwid', 'gw3'
            gws.should.have.property 1
            gws[1].should.have.property 'gwid', 'backup'

        it 'should report an error when no route is found', (done) ->
          ready.then ->

            router = new ToughRateRouter logger
            us =
              gateway_manager: gm
              options: {provisioning,ruleset_of,default_outbound_route:'default'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/routes-gwid').call us, router
            router.use (require '../middleware/routes-carrierid').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '336718', '347766'
          .then (ctx) ->
            ctx.res.response.should.equal '485'
            done()
          null

        it 'should route emergency numbers', ->
          ready.then ->
            router = new ToughRateRouter logger
            us =
              gateway_manager: gm
              options: {provisioning,ruleset_of,default_outbound_route:'default'}
            router.use (require '../middleware/ruleset').call us, router
            router.use (require '../middleware/emergency').call us, router
            router.use (require '../middleware/routes-gwid').call us, router
            router.use (require '../middleware/routes-carrierid').call us, router
            router.use (require '../middleware/flatten').call us, router
            router.route call_ '336718', '330112', 'brest'
          .then (ctx) ->
            ctx.res.should.have.property 'destination', '33156'
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 2
            gws.should.have.property 0
            gws[0].should.have.property 'gwid', 'gw3'
            gws.should.have.property 1
            gws[1].should.have.property 'gwid', 'backup'

      describe 'The call handler', ->

        it 'should reject invalid destination numbers', (done) ->
          one_call
            data:
              'Channel-Destination-Number': 'abcd'
              'Channel-Caller-ID-Number': '2344'
            command: (c,v) ->
              console.dir {c,v}
              if c in ['set','export']
                return Promise.resolve().bind this
              c.should.equal 'respond'
              v.should.equal '484'
              done()
              Promise.resolve()

        it 'should reject invalid source numbers', (done) ->
          one_call
            data:
              'Channel-Destination-Number': '1235'
              'Channel-Caller-ID-Number': 'abcd'
            command: (c,v) ->
              if c is 'set'
                return Promise.resolve().bind this
              c.should.equal 'respond'
              v.should.equal '484'
              done()
              Promise.resolve()

        it 'should reject unknown destinations', (done) ->
          one_call
            data:
              'Channel-Destination-Number': '1235'
              'Channel-Caller-ID-Number': '2345'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              c.should.equal 'respond'
              v.should.equal '485'
              done()
              Promise.resolve()

        it 'should route known destinations', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '1236'
              'Channel-Caller-ID-Number': '2346'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.equal '[]sofia/something-egress/sip:bar@foo'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          ready.then ->
            provisioning.put _id:'number:1236',inbound_uri:'sip:bar@foo'
          .catch done
          .then ->
            one_call ctx
          .catch done
          null

        it 'should route known destinations for specific sources', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336727'
              'Channel-Caller-ID-Number': '2347'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.equal '[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800]sofia/something-egress/sip:336727@127.0.0.1:5068'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          ready.then ->
            provisioning.put _id:'number:2347',outbound_route:'default'
          .catch done
          .then ->
            one_call ctx
          .catch done
          null

        it 'should route known routes', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '3368267'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.equal '[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800]sofia/something-egress/sip:3368267@127.0.0.1:5068'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          one_call ctx, 'default'
          null

        it 'should report errors', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336927'
              'Channel-Caller-ID-Number': '2349'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              if c is 'bridge'
                Promise.reject new FreeSwitchError {}, reply: '-ERR I_TOLD_YOU_SO'
              else
                c.should.equal 'respond'
                v.should.equal '604'
                done()
                Promise.resolve()

          ready.then ->
            one_call ctx, 'default'
          .catch done
          null

        it 'should report failed destinations', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336927'
              'Channel-Caller-ID-Number': '2349'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              if c is 'bridge'
                Promise.resolve
                  body:
                    variable_last_bridge_hangup_cause: 'SOMETHING_HAPPENED'
              else
                c.should.equal 'respond'
                v.should.equal '604'
                done()
                Promise.resolve()

          ready.then ->
            one_call ctx, 'default'
          .catch done
          null

        it 'should route emergency', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '330112'
              'Channel-Caller-ID-Number': '2348'
              'variable_sip_h_X-CCNQ3-Routing': 'brest'
            command: (c,v) ->
              if c is 'set'
                return Promise.resolve().bind this
              v.should.equal '[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800]sofia/something-egress/sip:33156@127.0.0.1:5068'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
          one_call ctx, 'default'

    describe.skip 'The Call Handler', ->
      it 'should handle additional headers', ->
