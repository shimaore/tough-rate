    Promise = require 'bluebird'
    exec = Promise.promisify (require 'child_process').exec
    pkg = require '../package.json'

    IMG = "#{pkg.name}-test"
    t = 'live'
    p = "#{IMG}-#{t}"
    DNS = null
    domain = "#{p}.local.localhost.docker-local:5062"

    Promise.resolve()
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
    .delay 17000
    .then -> test()
    .then ->
      console.log "Test successful"
    .catch (error) ->
      console.dir error
      console.log "Test failed"
    .then ->
      exec "docker logs #{p} > #{p}.log"
    .then -> exec "docker kill #{p}"
    .then -> exec "docker rm #{p}"
    .then -> exec "docker rmi #{p}"
    .then ->
      console.log "Done"
    .finally ->
      server?.stop()


    PouchDB = (require 'pouchdb').defaults db: require 'memdown'
    FS = require 'esl'

    CallServer = require '../call_server'
    options =
      provisioning: new PouchDB 'provisioning'
      profile: 'test-server'
      ruleset_of: (x) -> "the_#{x}_ruleset"
      statistics: require 'winston'
      respond: true

    GatewayManager = require '../gateway_manager'
    options.gateway_manager = new GatewayManager options

    server = new CallServer 7002, options
    test = ->
      console.log "Creating promise for client"
      new Promise (resolve,reject) ->
        setTimeout reject, 4000
        try
          console.log "Creating client"
          client = FS.client ->
            console.log "Starting client"
            source = '1234'
            destination = '2345'
            @api "originate {originate_caller_id_number=#{source}}sofia/test-server/sip:lcr7002-#{destination}@#{domain} &park"
            .then ->
              console.log "Call established"
              client.end()
              resolve()
            .catch (exception) ->
              client.end()
              reject exception
          client.on 'error', (data) ->
            console.dir data
            client.end()
            reject()
          client.connect 8022, '127.0.0.1'
          client
        catch exception
          reject exception
