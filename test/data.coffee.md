- gather the rule for the given prefix and environment
- from that rule's gwlist, build a single list of unique gateways we will attempt in order
- place the calls

    pkg = require '../package'

    sleep = (timeout) -> new Promise(resolve) -> setTimeout resolve, timeout
    db_base = "http://#{process.env.COUCHDB_USER}:#{process.env.COUCHDB_PASSWORD}@couchdb:5984/"

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
          codecs:'PCMA'

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

      location:
        'home':
          _id:'location:home'
          type:'location'
          routing_data:'brest'
        'work':
          _id:'location:work'
          type:'location'
          routing_data:'paris'
        'bob':
          _id:'location:bob'
          type:'location'
          routing_data:'paris'
          number: '2351'

      number:
        '2348':
          _id:'number:2348'
          outbound_route: 'default'
        '2349':
          _id:'number:2349'
          outbound_route: 'default'
        '2350':
          _id:'number:2350'
          outbound_route: 'default'
        '3213':
          _id:'number:3213'
          outbound_route: 'registrant'
        '336718':
          _id:'number:336718'
          outbound_route: 'default'

      rules:
        default:
          '33':
            _id:'prefix:33'
            type:'prefix'
            prefix:'33'
            destination:'france'
            attrs:
              cdr: 'foo-bar'

          '336':
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
          '33':
            _id:'prefix:33'
            type:'prefix'
            prefix:'33'
            gwlist:[
              {source_registrant:true}
            ]

    {expect} = chai = require 'chai'
    chai.should()
    CouchDB = require './most-couchdb'
    pkg = require '../package.json'
    GatewayManager = require '../gateway_manager'
    Router = require 'useful-wind/router'
    serialize = require 'useful-wind-serialize'
    CaringBand = require 'caring-band'

    class FreeSwitchError extends Error
      constructor: (res,args) ->
        super()
        @res = res
        @args = args

      toString: ->
        JSON.stringify @args

    describe 'Once the database is loaded', ->
      dataset = dataset_1
      provisioning = null
      rr = notify:->
      gm = null

Note: normally `ruleset_of` would query provisioning to find the ruleset and then map it to its database.

      ruleset_of = (x) ->
        if not dataset.rulesets[x]?
          throw "Unknown ruleset #{x}"
        response =
          ruleset: dataset.rulesets[x]
          ruleset_database: new CouchDB db_base + dataset.rulesets[x].database
        Promise.resolve response

      before ->
        @timeout 4000
        provisioning = new CouchDB db_base + 'provisioning'
        await provisioning.destroy().catch -> yes
        await provisioning.create()
        records = []
        (records.push v) for k,v of dataset.gateways
        (records.push v) for k,v of dataset.carriers
        (records.push v) for k,v of dataset.emergency
        (records.push v) for k,v of dataset.location
        (records.push v) for k,v of dataset.number
        console.log await provisioning.bulkDocs records

        default_ruleset = new CouchDB db_base + dataset.rulesets.default.database
        await default_ruleset.destroy().catch -> yes
        await default_ruleset.create()
        records = []
        (records.push v) for k,v of dataset.rules.default
        (records.push v) for k,v of dataset.destinations
        await default_ruleset.bulkDocs records

        the_ruleset = new CouchDB db_base + dataset.rulesets.registrant.database
        await the_ruleset.destroy().catch -> yes
        await the_ruleset.create()
        rules = []
        (rules.push v) for k,v of dataset.rules.registrant
        await the_ruleset.bulkDocs rules

        GatewayManager.should.have.property 'couch'
        GatewayManager.couch.should.have.property 'views'
        GatewayManager.couch.views.should.have.property 'gateways'
        GatewayManager.couch.views.gateways.should.have.property 'map'
        await provisioning.put GatewayManager.couch
        doc = await provisioning.get "_design/#{pkg.name}-gateway-manager"
        doc.should.have.property 'views'
        doc.views.should.have.property 'gateways'
        gm = new GatewayManager provisioning, 'phone.local'
        await gm.set 'progress_timeout', 4
        await gm.init()

      call_ = (source,destination,location,ccnq_to_e164) ->
        call =
          data:
            'Channel-Caller-ID-Number': source
            'Channel-Destination-Number': destination
            'variable_ccnq_to_e164': ccnq_to_e164
            'variable_location': location
          on: ->
          emit: ->
          command: ->

      one_call = (ctx,outbound_route,sip_domain_name) ->
        ctx.once ?= ->
          then: ->
        ctx.emit ?= ->
        ctx.on ?= ->
        router = new Router cfg = {
          gateway_manager: gm
          prov: provisioning
          ruleset_of
          sip_domain_name
          default_outbound_route: outbound_route
          profile: 'something-egress'
        }
        use = [
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
        cfg.dev_logger = true
        cfg.use = use
        cfg.rr = rr
        cfg.prefix_admin = db_base.replace /\/$/, ''
        await serialize cfg, 'init'
        await router.route ctx

      describe 'Gateways', ->
        it 'should have progress_timeout from their carrier: gw1', ->
          doc = await gm.resolve_gateway 'gw1'
          doc.should.have.length 1
          doc.should.be.an.instanceOf Array
          doc.should.have.property 0
          doc[0].should.have.property 'progress_timeout'
          doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
          doc[0].should.have.property 'timezone', 'US/Eastern'
          doc[0].should.have.property 'ratings'
          doc[0].should.have.property 'codecs', 'PCMA'

        it 'should have progress_timeout from their carrier: gw2', ->
          doc = await  gm.resolve_gateway 'gw2'
          doc.should.have.length 1
          doc.should.be.an.instanceOf Array
          doc.should.have.property 0
          doc[0].should.have.property 'gwid', 'gw2'
          doc[0].should.have.property 'progress_timeout'
          doc[0].progress_timeout.should.equal dataset.carriers.the_phone_company.progress_timeout
          doc[0].should.have.property 'timezone', 'US/Central'

      describe 'the_phone_company', ->
        it 'should return its gateways', ->
          info = await gm.resolve_carrier 'the_phone_company'
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
          await provisioning.put _id:'number:1234',inbound_uri:'sip:foo@bar'
          cfg = {prov:provisioning,ruleset_of,sip_domain_name}
          router = new Router cfg
          cfg.rr = rr
          cfg.prefix_admin = db_base.replace /\/$/, ''
          cfg.use = [
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/local-number'
            '../middleware/ruleset'
            '../middleware/flatten'
          ].map (m) -> require m
          router.use m for m in cfg.use
          await serialize cfg, 'init'
          ctx = await router.route call_ '3213', '1234'
          ctx.should.have.property 'res'
          ctx.res.should.have.property 'gateways'
          ctx.session.should.not.have.property 'destination_onnet'
          gws = ctx.res.gateways
          gws.should.be.an.instanceOf Array
          gws.should.have.length 0

        it 'should route ccnq_to_e164', ->
          await provisioning.put _id:'number:1244',inbound_uri:'sip:foo@bar', account:'boo'
          router = new Router cfg = {prov:provisioning,ruleset_of,sip_domain_name}
          use = [
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
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '3213', 'abcd', null, '1244'
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
          await provisioning.put _id:'number:1432',inbound_uri:'sip:foo@bar',account:'foo_bar'
          router = new Router cfg = {prov:provisioning,ruleset_of,sip_domain_name}
          use = [
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/local-number'
            '../middleware/ruleset'
            '../middleware/flatten'
          ].map (m) -> require m
          router.use m for m in use
          cfg.use = use
          cfg.prefix_admin = db_base
          cfg.rr = rr
          await serialize cfg, 'init'
          ctx = await router.route call_ '3216', '1432'
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
          await provisioning.merge 'number:3213', registrant_host:'foo',registrant_password:'badabing'
          router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name}
          use = [
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/ruleset'
            '../middleware/routes-registrant'
            '../middleware/flatten'
          ].map (m) -> require m
          router.use m for m in use
          cfg.use = use
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '3213', '331234'
          gws = ctx.res.gateways
          gws.should.be.an.instanceOf Array
          gws.should.have.length 1
          gws.should.have.property 0
          gws[0].should.have.property 'address', 'foo:5070'
          gws[0].should.have.property 'headers'
          gws[0].headers.should.have.property 'X-RP', 'badabing'

        it 'should route registrant_host directly (using provided port)', ->
          await provisioning.put _id:'number:3243',registrant_host:'foo:5080'
          router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name}
          use = [
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/ruleset'
            '../middleware/routes-registrant'
            '../middleware/flatten'
          ].map (m) -> require m
          router.use m for m in use
          cfg.use = use
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '3243', '331234'
          gws = ctx.res.gateways
          gws.should.be.an.instanceOf Array
          gws.should.have.length 1
          gws.should.have.property 0
          gws[0].should.have.property 'address', 'foo:5080'

        it 'should route registrant_host directly (using array)', ->
          await provisioning.put _id:'number:3253',registrant_host:['foo:5080']
          router = new Router cfg = {prov:provisioning,ruleset_of,default_outbound_route:'registrant',sip_domain_name}
          use = [
            'huge-play/middleware/setup'
            './standalone'
            '../middleware/setup'
            '../middleware/ruleset'
            '../middleware/routes-registrant'
            '../middleware/flatten'
          ].map (m) -> require m
          router.use m for m in use
          cfg.use = use
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '3253', '331234'
          gws = ctx.res.gateways
          gws.should.be.an.instanceOf Array
          gws.should.have.length 1
          gws.should.have.property 0
          gws[0].should.have.property 'address', 'foo:5080'

        it 'should route numbers using routes', ->
          router = new Router cfg = {
            gateway_manager: gm
            prov:provisioning
            ruleset_of
            default_outbound_route:'default'
          }
          use = [
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
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '336718', '331234'
          gws = ctx.res.gateways
          gws.should.be.an.instanceOf Array
          gws.should.have.length 2
          gws.should.have.property 0
          gws[0].should.have.property 'gwid'
          gws[0].gwid.should.be.oneOf ['gw3','gw4'] # randomized
          gws.should.have.property 1
          gws[1].should.have.property 'gwid', 'backup'

        it 'should report an error when no route is found', ->
          router = new Router cfg = {
            gateway_manager: gm
            prov:provisioning
            ruleset_of
            default_outbound_route:'default'
          }
          use = [
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
          cfg.prefix_admin = db_base
          cfg.rr = rr
          await serialize cfg, 'init'
          ctx = await router.route call_ '336718', '347766'
          ctx.session.first_response_was.should.equal '485'

        it 'should route emergency numbers', ->
          router = new Router cfg = {
            gateway_manager: gm
            prov:provisioning
            ruleset_of
            default_outbound_route:'default'
          }
          use = [
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
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '336718', '33_112', 'home'
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
          router = new Router cfg = {
            gateway_manager: gm
            prov:provisioning
            ruleset_of
            default_outbound_route:'default'
          }
          use = [
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
          cfg.rr = rr
          cfg.prefix_admin = db_base
          await serialize cfg, 'init'
          ctx = await router.route call_ '336718', '33_112', 'work'
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
                return Promise.resolve()
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
                return Promise.resolve()
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
                return Promise.resolve()
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
                return Promise.resolve()
              v.should.equal '{}[sip_h_P-Charge-Info=sip:barf@pooh,origination_caller_id_number=2346,effective_caller_id_number=2346]sofia/something-egress/sip:bar@foo'
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          (do ->
            await provisioning.put _id:'number:1236',inbound_uri:'sip:bar@foo', account:'barf'
            await one_call ctx, null, 'pooh'
          ).catch done
          null

        it 'should route known destinations for specific sources', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336727'
              'Channel-Caller-ID-Number': '2347'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2347,effective_caller_id_number=2347\]sofia/something-egress/sip:336727@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          (do ->
            await provisioning.put _id:'number:2347',outbound_route:'default'
            await one_call ctx
          ).catch done
          null

        it 'should route known routes', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '3368267'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2348,effective_caller_id_number=2348\]sofia/something-egress/sip:3368267@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          (do -> await one_call ctx, 'default').catch done
          null

        it 'should insert CDR data', (done) ->
          success = false
          ctx =
            data:
              'Channel-Destination-Number': '331234'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c is 'set' and m = v.match /^sip_h_X-At=(.*)$/
                m[1].should.equal '{"cdr":"foo-bar"}'
                success = true
              if c in ['set','export']
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2348,effective_caller_id_number=2348\]sofia/something-egress/sip:331234@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              if success
                done()
              else
                done new Error 'X-At was invalid or not set'
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'

          (do -> await one_call ctx, 'default').catch done
          null

        it 'should insert winner data', ->
          @timeout 6*1000
          ctx =
            data:
              'Channel-Destination-Number': '331234'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2348,effective_caller_id_number=2348\]sofia/something-egress/sip:331234@127.0.0.1:506[89] /// # randomized
              c.should.equal 'bridge'
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
            once: (msg) ->
              if msg is 'CHANNEL_HANGUP_COMPLETE'
                await 5*1000
                body:
                  billmsec: 2000

          {session} = await one_call ctx, 'default'
          session.should.have.property 'winner'
          session.winner.should.have.property 'carrierid', 'the_other_company'
          null

        it 'should report errors', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336927'
              'Channel-Caller-ID-Number': '2349'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve()
              if c is 'bridge'
                Promise.reject new FreeSwitchError {}, reply: '-ERR I_TOLD_YOU_SO'
              else
                c.should.equal 'respond'
                v.should.equal '604'
                done()
                Promise.resolve()
            emit: ->

          (do -> await one_call ctx, 'default').catch done
          null

        it 'should report failed destinations', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '336927'
              'Channel-Caller-ID-Number': '2349'
            command: (c,v) ->
              if c in ['set','export']
                return Promise.resolve()
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

          (do -> await one_call ctx, 'default').catch done
          null

        it 'should route emergency', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '33_112'
              'Channel-Caller-ID-Number': '2348'
              'variable_location':'home'
            command: (c,v) ->
              if c is 'set' or c is 'export'
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2348,effective_caller_id_number=2348\]sofia/something-egress/sip:33156@127.0.0.1:506[89] ///
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
          (do -> await one_call ctx, 'default').catch done
          null

        it 'should route emergency (with location number)', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '33_112'
              'Channel-Caller-ID-Number': '2350'
              'variable_location':'bob'
            command: (c,v) ->
              if c is 'set' or c is 'export'
                return Promise.resolve()
              v.should.match /// \[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800,origination_caller_id_number=2351,effective_caller_id_number=2351\]sofia/something-egress/sip:33158@127.0.0.1:506[89] ///
              c.should.equal 'bridge'
              done()
              Promise.resolve
                body:
                  variable_last_bridge_hangup_cause: 'NORMAL_CALL_CLEARING'
          (do -> await one_call ctx, 'default').catch done
          null


    describe.skip 'The Call Handler', ->
      it 'should handle additional headers', ->
