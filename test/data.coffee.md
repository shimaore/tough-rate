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
            destination:'france'
            gwlist:[
              {carrierid:'the_other_company'}
              {gwid:'backup'}
            ]

          336:
            _id:'rule:336'
            type:'rule'
            destination:'france_mobile'
            gwlist: [
              {carrierid:'the_other_company'}
              {carrierid:'the_phone_company'}
            ]

          330112:
            _id:'rule:330112'
            type:'rule'
            destination:'france_emergency'
            emergency:true

    should = require 'should'
    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    pkg = require '../package.json'
    GatewayManager = require '../gateway_manager'
    CallRouter = require '../router'
    CallHandler = require '../call_handler'
    statistics = require 'winston'
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
          throw "Unknown ruleset #{x}"
        ruleset: dataset.rulesets[x]
        database: new PouchDB dataset.rulesets[x].database

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
        gm.init()

      one_call = (ctx,outbound_route) ->
        ready.then ->
          router = new CallRouter {provisioning, gateway_manager:gm, ruleset_of, statistics, respond:true, outbound_route}
          ch = CallHandler router,
            profile: 'something-egress'
            statistics: statistics
          ch.apply ctx
        .catch (exception) ->
          throw exception

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
        it 'should route local numbers directly', (done) ->
          ready.then ->
            provisioning.put _id:'number:1234',inbound_uri:'sip:foo@bar'
            .catch done
            .then ->
              router = new CallRouter {provisioning, gateway_manager:gm, ruleset_of, statistics, respond:done}
              router.route '3213', '1234'
              .then (gws) ->
                gws.should.be.an.instanceOf Array
                gws.should.have.length 1
                gws.should.have.property 0
                gws[0].should.have.property 'uri', 'sip:foo@bar'
                done()
            .catch done

        it 'should route numbers using routes', (done) ->
          ready.then ->
            router = new CallRouter {provisioning, gateway_manager:gm, ruleset_of, statistics, respond:done, outbound_route:'default'}
            router.route '336718', '331234'
            .then (gws) ->
              gws.should.be.an.instanceOf Array
              gws.should.have.length 2
              gws.should.have.property 0
              gws[0].should.have.property 'gwid', 'gw3'
              gws.should.have.property 1
              gws[1].should.have.property 'gwid', 'backup'
              done()
            .catch done

        it 'should report an error when no route is found', (done) ->
          ready.then ->
            respond = (v) ->
              v.should.equal '485'

            router = new CallRouter {provisioning, gateway_manager:gm, ruleset_of, statistics, respond, outbound_route:'default'}
            router.route '336718', '347766'
            .catch (exception)->
              console.dir exception
              done()
            null

        it.only 'should route emergency numbers', (done) ->
          ready.then ->
            router = new CallRouter {provisioning, gateway_manager:gm, ruleset_of, statistics, respond:done, outbound_route:'default'}
            router.route '336718', '330112', 'brest'
            .then (gws) ->
              gws.should.be.an.instanceOf Array
              gws.should.have.length 2
              gws.should.have.property 0
              gws[0].should.have.property 'final_destination', '33156'
              gws[0].should.have.property 'gwid', 'gw3'
              gws.should.have.property 1
              gws[1].should.have.property 'final_destination', '33156'
              gws[1].should.have.property 'gwid', 'backup'
              done()
            .catch done

      describe 'The call handler', ->

        it 'should reject invalid destination numbers', (done) ->
          one_call
            data:
              'Channel-Destination-Number': 'abcd'
              'Channel-Caller-ID-Number': '2344'
            command: (c,v) ->
              c.should.equal 'respond'
              v.should.equal '484'
              done()
              Promise.resolve()

        it 'should reject invalid source umbers', (done) ->
          one_call
            data:
              'Channel-Destination-Number': '1235'
              'Channel-Caller-ID-Number': 'abcd'
            command: (c,v) ->
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
              c.should.equal 'respond'
              v.should.equal '485'
              done()
              Promise.resolve()

        it 'should route known destinations', (done) ->
          ready.then ->
            provisioning.put _id:'number:1236',inbound_uri:'sip:bar@foo'
            .catch done
            .then ->
              one_call
                data:
                  'Channel-Destination-Number': '1236'
                  'Channel-Caller-ID-Number': '2346'
                command: (c,v) ->
                  v.should.equal '[]sofia/something-egress/sip:bar@foo'
                  c.should.equal 'bridge'
                  done()
                  Promise.resolve()

        it 'should route known destinations for specific sources', (done) ->
          ready.then ->
            provisioning.put _id:'number:2347',outbound_route:'default'
            .catch done
            .then ->
              one_call
                data:
                  'Channel-Destination-Number': '336727'
                  'Channel-Caller-ID-Number': '2347'
                command: (c,v) ->
                  v.should.equal '[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800]sofia/something-egress/sip:336727@127.0.0.1:5068'
                  c.should.equal 'bridge'
                  done()
                  Promise.resolve()

        it 'should route known routes', (done) ->
          ctx =
            data:
              'Channel-Destination-Number': '3368267'
              'Channel-Caller-ID-Number': '2348'
            command: (c,v) ->
              v.should.equal '[leg_progress_timeout=4,leg_timeout=90,sofia_session_timeout=28800]sofia/something-egress/sip:3368267@127.0.0.1:5068'
              c.should.equal 'bridge'
              done()
              Promise.resolve()
          one_call ctx, 'default'

        it 'should report failed destinations', (done) ->
          ready.then ->
            ctx =
              data:
                'Channel-Destination-Number': '336927'
                'Channel-Caller-ID-Number': '2349'
              command: (c,v) ->
                if c is 'bridge'
                  Promise.reject new FreeSwitchError {}, reply: '-ERR I_TOLD_YOU_SO'
                else
                  v.should.equal '604'
                  c.should.equal 'respond'
                  done()
                  Promise.resolve()
            one_call ctx, 'default'
