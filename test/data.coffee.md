The steps to placing outbound call(s) are:
- gather the rule for the given prefix and environment
- from that rule's gwlist, build a single list of unique gateways we will attempt in order
- place the calls

    gateways =
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
        type:'backup'
        sip_domain_name:'phone.local'
        gwid:'backup'

    carriers =
      the_phone_company:
        _id:'carrier:phone.local:the_phone_company'
        type:'carrier'
        sip_domain_name:'phone.local'
        carrierid:'the_phone_company'
        progress_timeout: 20

    destinations =
      france:
        _id:'destination:france'
        type:'destination'
        destination:'france'

    rulesets =
      default:
        _id:'ruleset:phone.local:default'
        type:'ruleset'
        sip_domain_name:'phone.local'
        groupid:'default'
        title:'The default ruleset'
        database: 'the_default_ruleset'

    rules =
      default:
        33:
          _id:'rule:33'
          type:'rule'
          destination:'france'
          gwlist:[
            {carrier:'the_other_company'}
            {gwid:'backup'}
          ]

        336:
          _id:'rule:336'
          type:'rule'
          destination:'france_mobile'
          gwlist: [
            {carrier:'the_other_company'}
            {carrier:'the_phone_company'}
          ]

    should = require 'should'
    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    pkg = require '../package.json'
    GatewayManager = require '../gateway_manager'

    describe 'Once the database is loaded', ->
      provisioning = null
      gm = null

      ready = PouchDB.destroy 'provisioning'
      .then ->
        provisioning = new PouchDB 'provisioning'
        records = []
        (records.push v) for k,v of gateways
        (records.push v) for k,v of carriers
        (records.push v) for k,v of destinations
        (records.push v) for k,v of destinations
        provisioning.bulkDocs records

      ready = ready.then ->
        PouchDB.destroy rulesets.default.database
      .then ->
        default_ruleset = new PouchDB rulesets.default.database
        rules = []
        (rules.push v) for k,v of rules.default
        default_ruleset.bulkDocs rules

      ready = ready.then ->
        GatewayManager.should.have.property 'couch'
        GatewayManager.couch.should.have.property 'views'
        GatewayManager.couch.views.should.have.property 'gateways'
        GatewayManager.couch.views.gateways.should.have.property 'map'
        provisioning.put GatewayManager.couch
      .then ->
        provisioning.get '_design/tough-rate-gateway-manager'
      .then (doc) ->
          doc.should.have.property 'views'
          doc.views.should.have.property 'gateways'
      .then ->
        gm = new GatewayManager provisioning, 'phone.local'
        gm.init()

      describe 'gw1', ->
        it 'should have progress_timeout from its carrier', ->
          ready.then ->
            gm.resolve_gateway 'gw1'
            .then (doc) ->
              doc.should.have.property 'progress_timeout'
              doc.progress_timeout.should.be carriers.the_phone_company.progress_timeout
              done()
