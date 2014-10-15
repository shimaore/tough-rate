Test Submitter
==============

    chai = require 'chai'
    chai.use require 'chai-as-promised'
    should = chai.should()

    Promise = require 'bluebird'
    real_exec = Promise.promisify (require 'child_process').exec
    pkg = require '../package.json'

    process.chdir (require 'path').dirname __filename

    IMG = "#{pkg.name}-test"
    t = 'live'
    p = "#{IMG}-#{t}"
    DNS = null
    domain_name = "#{p}.local.localhost.docker-local"
    domain = "#{domain_name}:5062"
    exec = (cmd) ->
      console.log cmd
      real_exec cmd

    server = null

Setup
=====

    ready = Promise.resolve()
    .then -> exec "docker build -t #{p} #{t}/"
    .then -> exec "docker kill #{p}"
    .catch -> true
    .then -> exec "docker rm #{p}"
    .catch -> true
    .then -> exec "dig +short docker-dns.local.localhost.docker-local @172.17.42.1 | egrep '^[0-9.]+$'"
    .then (dns) ->
      # console.dir dns
      DNS = dns[0].toString().replace '\n', ''
      console.log "Docker DNS is at #{DNS}"
      exec "docker run -p 127.0.0.1:8022:8022 --dns=#{DNS} -d --name #{p} #{p}"
    .catch (error) ->
      console.log "Docker run failed"
      throw error
    .then -> start_server()
    .catch (error) ->
      console.log "Start server failed"
      throw error
    .then (s) -> server = s
    .catch (error) ->
      console.log "Preflight failed"
      throw error
    .delay 17000

Cleanup
=======

    cleanup = Promise.resolve()
    .then -> server?.stop()
    .then -> exec "docker logs #{p} > #{p}.log"
    .then -> exec "docker kill #{p}"
    .then -> exec "docker rm #{p}"
    .then -> exec "docker rmi #{p}"
    .catch -> true

Server (Unit Under Test)
========================

    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    FS = require 'esl'
    GatewayManager = null
    options = null

    start_server = ->
      provisioning = null
      sip_domain_name = 'phone.local'
      Promise.resolve()
      .then -> PouchDB.destroy 'live-provisioning'
      .catch -> true
      .then -> PouchDB.destroy 'the_default_live_ruleset'
      .catch -> true
      .then ->
        provisioning = new PouchDB 'live-provisioning'
        provisioning.bulkDocs [
          {
            _id:'gateway:phone.local:gw1'
            type:'gateway'
            sip_domain_name:'phone.local'
            gwid:'gw1'
            address:"#{domain_name}:5064"
          }
          {
            _id:'ruleset:phone.local:default'
            type:'ruleset'
            sip_domain_name:'phone.local'
            groupid:'default'
            database:'the_default_live_ruleset'
          }
          {
            _id:'emergency:330112#brest'
            destination:'33156'
          }
          {
            _id:'number:1234'
            outbound_route:'default'
          }
          {
            _id:'number:1235'
            outbound_route:'default'
          }
        ]
      .then ->
        ruleset = new PouchDB 'the_default_live_ruleset'
        ruleset.bulkDocs [
          {
            _id:'rule:331'
            gwlist: [
              {gwid:'gw1'}
            ]
          }
          {
            _id:'rule:330112'
            emergency:true
          }
        ]
      .catch (error) ->
        console.log "bulkDocs failed"
        throw error
      .then ->
        GatewayManager = require '../gateway_manager'
        provisioning.put GatewayManager.couch
      .then ->

        ruleset_of = (x) ->
          provisioning.get "ruleset:#{sip_domain_name}:#{x}"
          .then (doc) ->
            ruleset: doc
            database: new PouchDB doc.database

        options =
          provisioning: provisioning
          profile: 'test-sender'
          ruleset_of: ruleset_of
          statistics: require 'winston'

        options.gateway_manager = new GatewayManager provisioning, sip_domain_name
        options.gateway_manager.init()
      .catch (error) ->
        console.log "Gateway Manager init() failed"
        throw error
      .then ->
        CallServer = require '../call_server'
        new CallServer 7002, options

Test
====

    test1 = ->
      console.log "Test 1"
      console.log "Creating promise for client"
      new Promise (resolve,reject) ->
        setTimeout reject, 4000
        try
          console.log "Creating client"
          client = FS.client ->
            console.log "Starting client"
            source = '1234'
            destination = '33142'
            @api "originate {origination_caller_id_number=#{source}}sofia/test-sender/sip:#{destination}@#{domain} &park"
            .then ->
              console.log "Call established"
              client.end()
              resolve true
            .catch (exception) ->
              client.end()
              console.log "Test 1 Call failed"
              reject exception
          client.on 'error', (data) ->
            console.dir 'test.on error':data
            client.end()
            reject new Error 'test error'
          client.connect 8022, '127.0.0.1'
          client
        catch exception
          reject exception

    test2 = ->
      console.log "Testing emergency"
      new Promise (resolve,reject) ->
        setTimeout reject, 4000
        try
          console.log "Creating client"
          client = FS.client ->
            console.log "Starting client"
            source = '1235'
            destination = '330112'
            @api "originate [origination_caller_id_number=#{source},sip_h_X-CCNQ3-Routing=brest]sofia/test-sender/sip:#{destination}@#{domain} &park"
            .then ->
              console.log "Call established"
              client.end()
              resolve true
            .catch (exception) ->
              client.end()
              reject exception
          client.on 'error', (data) ->
            console.dir 'test2.on error':data
            client.end()
            reject new Error 'test error'
          client.connect 8022, '127.0.0.1'
          client
        catch exception
          reject exception

    before ->
      @timeout 18000
      ready

    after ->
      cleanup

    describe 'FreeSwitch', ->
      @timeout 5000
      it 'should process a regular call', ->
        t = ready.then test1
        t.should.be.fulfilled
        t.should.eventually.equal true
      it 'should process a registrant call', ->
        t = ready.then test2
        t.should.be.fulfilled
        t.should.eventually.equal true
