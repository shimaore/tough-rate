The steps to placing outbound call(s) are:
- gather the rule for the given prefix and environment
- from that rule's gwlist, build a single list of unique gateways we will attempt in order
- place the calls

    pkg = require '../package'
    debug = (require 'debug') "#{pkg.name}:test:data"
    seem = require 'seem'

    sip_domain_name = 'phone.local'
    dataset_1 =
      gateways:
        gw1:
          _id:'gateway:phone.local:gw1'
          type:'gateway'
          sip_domain_name: sip_domain_name
          gwid:'gw1'
          address:'127.0.0.1:5066'
          carrierid:'the_phone_company'
          attrs:
            gateway_name:'gw1'
        gw2:
          _id:'gateway:phone.local:gw2'
          type:'gateway'
          sip_domain_name: sip_domain_name
          gwid:'gw2'
          address:'127.0.0.1:5067'
          carrierid:'the_phone_company'
          attrs:
            gateway_name:'gw2'
          timezone: 'US/Central'
        gw3:
          _id:'gateway:phone.local:gw3'
          type:'gateway'
          sip_domain_name: sip_domain_name
          gwid:'gw3'
          address:'127.0.0.1:5068'
          carrierid:'the_other_company'
          attrs:
            gateway_name:'gw3'
        gw4:
          _id:'gateway:phone.local:gw4'
          type:'gateway'
          sip_domain_name: sip_domain_name
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
          sip_domain_name: sip_domain_name
          gwid:'backup'

      carriers:
        the_phone_company:
          _id:'carrier:phone.local:the_phone_company'
          type:'carrier'
          sip_domain_name: sip_domain_name
          carrierid:'the_phone_company'
          progress_timeout: 20
          timezone: 'US/Eastern'
          ratings:
            '2016-07-28':
              table: 'cheap'

      destinations:
        france:
          _id:'destination:france'
          type:'destination'
          destination:'france'
          gwlist:[
            {carrierid:'the_other_company'}
            {gwid:'backup'}
          ]

      rulesets:
        default:
          _id:'ruleset:phone.local:default'
          type:'ruleset'
          sip_domain_name: sip_domain_name
          groupid:'default'
          title:'The default ruleset'
          database: 'the_default_ruleset'
        registrant:
          _id:'ruleset:phone.local:registrant'
          type:'ruleset'
          sip_domain_name: sip_domain_name
          groupid:'registrant'
          title:'The registrant ruleset'
          database: 'the_registrant_ruleset'


      emergency:
        '33_112#brest':
          _id:'emergency:33_112#brest'
          type:'emergency'
          destination:'33156'

        '33_112#paris':
          _id:'emergency:33_112#paris'
          type:'emergency'
          destination:['33157','33158']

      rules:
        default:
          33:
            _id:'prefix:33'
            type:'prefix'
            prefix:'33'
            destination:'france'
            attrs:
              cdr: 'foo-bar'

          336:
            _id:'prefix:336'
            type:'prefix'
            prefix:'336'
            gwlist: [
              {carrierid:'the_other_company'}
              {carrierid:'the_phone_company'}
            ]

          '33_112':
            _id:'prefix:33_112'
            type:'prefix'
            prefix:'33_112'
            emergency:true

        registrant:
          33:
            _id:'prefix:33'
            type:'prefix'
            prefix:'33'
            gwlist:[
              {source_registrant:true}
            ]

    {expect} = chai = require 'chai'
    chai.should()
    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    pkg = require '../package.json'
    GatewayManager = require '../gateway_manager'
    Router = require 'useful-wind/router'
    Promise = require 'bluebird'
    serialize = require 'useful-wind-serialize'
    CaringBand = require 'caring-band'
    statistics = new CaringBand()

    class FreeSwitchError extends Error
      constructor:(@res,@args) ->

      toString: ->
        JSON.stringify @args

    describe 'Once the database is loaded', ->
      dataset = dataset_1
      provisioning = null
      gm = null

Note: normally `ruleset_of` would be async, and would query provisioning to find the ruleset and then map it to its database.

      ruleset_of = (x) ->
        if not dataset.rulesets[x]?
          throw "Unknown ruleset #{x}"
        response =
          ruleset: dataset.rulesets[x]
          ruleset_database: new PouchDB dataset.rulesets[x].database

      ready = Promise.resolve true
      .then ->
        new PouchDB 'provisioning'
        .destroy()
      .then ->
        provisioning = new PouchDB 'provisioning'
        records = []
        (records.push v) for k,v of dataset.gateways
        (records.push v) for k,v of dataset.carriers
        (records.push v) for k,v of dataset.emergency
        provisioning.bulkDocs records

      ready = ready.then ->
        new PouchDB dataset.rulesets.default.database
        .destroy()
      .then ->
        default_ruleset = new PouchDB dataset.rulesets.default.database
        records = []
        (records.push v) for k,v of dataset.rules.default
        (records.push v) for k,v of dataset.destinations
        default_ruleset.bulkDocs records

      ready = ready.then ->
        new PouchDB dataset.rulesets.registrant.database
        .destroy()
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
        gm = new GatewayManager provisioning, 'phone.local'
        gm.set 'progress_timeout', 4
        gm.init()

      call_ = (source,destination,emergency_ref,ccnq_to_e164) ->
        call =
          data:
            'Channel-Caller-ID-Number': source
            'Channel-Destination-Number': destination
            'variable_sip_h_X-CCNQ3-Routing': emergency_ref
            'variable_ccnq_to_e164': ccnq_to_e164
          emit: ->

      one_call = (ctx,outbound_route,sip_domain_name) ->
        ctx.once ?= ->
          then: ->
        ctx.emit ?= ->
        ready.then ->
          router = new Router cfg = {
            gateway_manager: gm
            prov: provisioning
            ruleset_of
            sip_domain_name
            default_outbound_route: outbound_route
            profile: 'something-egress'
            statistics
          }
          use = [
            'huge-play/middleware/logger'
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/numeric'
            '../middleware/response-handlers'
            '../middleware/local-number'
            '../middleware/ruleset'
            '../middleware/emergency'
            '../middleware/routes-gwid'
            '../middleware/routes-carrierid'
            '../middleware/routes-registrant'
            '../middleware/flatten'
            '../middleware/cdr'
            '../middleware/call-handler'
          ].map (m) -> require m
          router.use m for m in use
          cfg.use = use
          serialize cfg, 'init'
          .then ->
            router.route ctx

      describe 'Gateways', ->
        it 'should have progress_timeout from their carrier: gw1', ->
          ready.then ->
            gm.resolve_gateway 'gw1'
          .then (doc) ->
            doc.should.have.length 1
            doc.should.be.an.instanceOf Array
            doc.should.have.property 0
            doc[0].should.have.property 'progress_timeout'
            doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
            doc[0].should.have.property 'timezone', 'US/Eastern'
            doc[0].should.have.property 'ratings'

        it 'should have progress_timeout from their carrier: gw2', ->
          ready.then ->
            gm.resolve_gateway 'gw2'
          .then (doc) ->
            doc.should.have.length 1
            doc.should.be.an.instanceOf Array
            doc.should.have.property 0
            doc[0].should.have.property 'gwid', 'gw2'
            doc[0].should.have.property 'progress_timeout'
            doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
            doc[0].should.have.property 'timezone', 'US/Central'

      describe 'the_phone_company', ->
        it 'should return its gateways', ->
          ready.then ->
            gm.resolve_carrier 'the_phone_company'
          .then (info) ->
            expect(info).be.an.instanceOf Array
            info.should.have.length 2
            info.should.have.property 0
            info[0].should.have.property 'gwid', 'gw1'
            info[0].should.have.property 'timezone', 'US/Eastern'
            info.should.have.property 1
            info[1].should.have.property 'gwid', 'gw2'
            info[1].should.have.property 'timezone', 'US/Central'

      describe 'The call router', ->
        it 'should NOT route invalid local numbers', ->
          ready.then ->
            provisioning.put _id:'number:1234',inbound_uri:'sip:foo@bar'
          .then ->
            cfg = {prov:provisioning,ruleset_of,sip_domain_name,statistics}
            router = new Router cfg
            cfg.use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/local-number'
              '../middleware/ruleset'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in cfg.use
            serialize cfg, 'init'
            .then ->
              router.route call_ '3213', '1234'
          .then (ctx) ->
            ctx.should.have.property 'res'
            ctx.res.should.have.property 'gateways'
            ctx.session.should.not.have.property 'destination_onnet'
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 0

        it 'should route ccnq_to_e164', ->
          ready.then ->
            provisioning.put _id:'number:1244',inbound_uri:'sip:foo@bar', account:'boo'
          .then ->
            router = new Router cfg = {prov:provisioning,ruleset_of,sip_domain_name,statistics}
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/use-ccnq-to-e164'
              '../middleware/local-number'
              '../middleware/ruleset'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '3213', 'abcd', null, '1244'
          .then (ctx) ->
            ctx.should.have.property 'res'
            ctx.res.should.have.property 'gateways'
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'uri', 'sip:foo@bar'
            gws[0].should.have.property 'headers'
            gws[0].headers.should.have.property 'P-Charge-Info', 'sip:boo@phone.local'
            gws[0].should.have.property 'carrier', 'LOCAL'

        it 'should route local numbers with account', ->
          ready.then ->
            provisioning.put _id:'number:1432',inbound_uri:'sip:foo@bar',account:'foo_bar'
          .then ->
            router = new Router cfg = {prov:provisioning,ruleset_of,sip_domain_name,statistics}
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/local-number'
              '../middleware/ruleset'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '3216', '1432'
          .then (ctx) ->
            ctx.should.have.property 'res'
            ctx.res.should.have.property 'gateways'
            ctx.session.should.have.property 'destination_onnet', true
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'uri', 'sip:foo@bar'
            gws[0].should.have.property 'headers'
            gws[0].headers.should.be.an.instanceOf Object
            gws[0].headers.should.have.property 'P-Charge-Info', 'sip:foo_bar@phone.local'

        it 'should route registrant_host directly (adding default port)', ->
          ready.then ->
            provisioning.put _id:'number:3213',registrant_host:'foo',registrant_password:'badabing'
          .then ->
            router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name,statistics}
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/routes-registrant'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
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
            router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name,statistics}
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/routes-registrant'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
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
            router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name,statistics}
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/routes-registrant'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '3253', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 1
            gws.should.have.property 0
            gws[0].should.have.property 'address', 'foo:5080'

        it 'should route numbers using routes', ->
          ready.then ->
            router = new Router cfg = {
              gateway_manager: gm
              prov:provisioning
              ruleset_of
              default_outbound_route:'default'
              statistics
            }
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/routes-gwid'
              '../middleware/routes-carrierid'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '336718', '331234'
          .then (ctx) ->
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 2
            gws.should.have.property 0
            gws[0].should.have.property 'gwid'
            gws[0].gwid.should.be.oneOf ['gw3','gw4'] # randomized
            gws.should.have.property 1
            gws[1].should.have.property 'gwid', 'backup'

        it 'should report an error when no route is found', (done) ->
          ready.then ->

            router = new Router cfg = {
              gateway_manager: gm
              prov:provisioning
              ruleset_of
              default_outbound_route:'default'
              statistics
            }
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/routes-gwid'
              '../middleware/routes-carrierid'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '336718', '347766'
          .then (ctx) ->
            ctx.session.first_response_was.should.equal '485'
            done()
          .catch (error) ->
            console.error error
          null

        it 'should route emergency numbers', ->
          ready.then ->
            router = new Router cfg = {
              gateway_manager: gm
              prov:provisioning
              ruleset_of
              default_outbound_route:'default'
              statistics
            }
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/emergency'
              '../middleware/routes-gwid'
              '../middleware/routes-carrierid'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '336718', '33_112', 'brest'
          .then (ctx) ->
            ctx.res.should.have.property 'destination', '33156'
            ctx.session.should.have.property 'destination_emergency', true
            gws = ctx.res.gateways
            gws.should.be.an.instanceOf Array
            gws.should.have.length 2
            gws.should.have.property 0
            gws[0].should.have.property 'gwid'
            gws[0].gwid.should.be.oneOf ['gw3','gw4'] # randomized
            gws.should.have.property 1
            gws[1].should.have.property 'gwid', 'backup'

        it 'should route emergency numbers with multiple destinations', ->
          ready.then ->
            router = new Router cfg = {
              gateway_manager: gm
              prov:provisioning
              ruleset_of
              default_outbound_route:'default'
              statistics
            }
            use = [
              'huge-play/middleware/logger'
              'huge-play/middleware/setup'
              './standalone'
              '../middleware/setup'
              '../middleware/ruleset'
              '../middleware/emergency'
              '../middleware/routes-gwid'
              '../middleware/routes-carrierid'
              '../middleware/flatten'
            ].map (m) -> require m
            router.use m for m in use
            cfg.use = use
            serialize cfg, 'init'
            .then ->
              router.route call_ '336718', '33_112', 'paris'
          .then (ctx) ->
            ctx.should.have.property 'res'
            ctx.res.should.have.property 'destination', '33_112'
            ctx.res.should.have.property 'gateways'
            ctx.session.should.have.property 'destination_emergency', true
            gws = ctx.res.gateways
            expect(gws).to.not.be.null
            gws.should.be.an.instanceOf Array
            gws.should.have.length 2
            gws.should.have.property 0
            gws[0].should.have.property 'destination_number', '33157'
            gws.should.have.property 1
            gws[1].should.have.property 'destination_number', '33158'

Gateways are randomized within carriers.

            gws[0].should.have.property 'gwid'
            gws[0].gwid.should.be.oneOf ['gw3','gw4']
            gws[1].should.have.property 'gwid'
            gws[1].gwid.should.be.oneOf ['gw3','gw4']

      describe 'The call handler', ->

        it 'should reject invalid destination numbers', (done) ->
          one_call
            data:
              'Channel-Destination-Number': 'abcd'
              'Channel-Caller-ID-Number': '2344'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              c.should.equal 'respond'
              v.should.equal '484'
              done()
              Promise.resolve()
            emit: ->
          null

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
            emit: ->
          null

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
            emit: ->
          null

        it 'should route known (local) destinations', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '1236'
              'Channel-Caller-ID-Number': '2346'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.equal '[sip_h_P-Charge-Info=sip:barf@pooh]sofia/something-egress/sip:bar@foo'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          ready.then ->
            provisioning.put _id:'number:1236',inbound_uri:'sip:bar@foo', account:'barf'
          .catch done
          .then ->
            one_call ctx, null, 'pooh'
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
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800\]sofia/something-egress/sip:336727@127.0.0.1:506[89] /// # randomized
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
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800\]sofia/something-egress/sip:3368267@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          one_call ctx, 'default'
          null

        it 'should insert CDR data', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '331234'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c is 'set' and m = v.match /^sip_h_X-CCNQ3-Attrs=(.*)$/
                m[1].should.equal '{"cdr":"foo-bar"}'
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800\]sofia/something-egress/sip:331234@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          one_call ctx, 'default'
          null

        it 'should insert winner data', seem (done) ->
          @timeout 6*1000
          ctx =
            data:
              'Channel-Destination-Number': '331234'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800\]sofia/something-egress/sip:331234@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
            once: (msg) ->
              if msg is 'CHANNEL_HANGUP_COMPLETE'
                Promise
                  .delay 5*1000
                  .then ->
                    body:
                      billmsec: 2000

          {session} = yield one_call ctx, 'default'
          session.should.have.property 'winner'
          session.winner.should.have.property 'carrierid', 'the_other_company'
          null

        it 'should emit call events', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '331244'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve().bind this
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          statistics.on 'report', (data) ->
            if data.state is 'call-attempt' and data.source is '2348' and data.destination is '331244'
              done()

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
            emit: ->

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
            emit: ->

          ready.then ->
            one_call ctx, 'default'
          .catch done
          null

        it 'should route emergency', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '33_112'
              'Channel-Caller-ID-Number': '2348'
              'variable_sip_h_X-CCNQ3-Routing': 'brest'
            command: (c,v) ->
              if c is 'set' or c is 'export'
                return Promise.resolve().bind this
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800\]sofia/something-egress/sip:33156@127.0.0.1:506[89] ///
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
          one_call ctx, 'default'
          null

    describe.skip 'The Call Handler', ->
      it 'should handle additional headers', ->
