Promise = require 'bluebird'
exec = Promise.promisify (require 'child_process').exec

Promise.resolve()
.then -> exec 'docker stop docker-dns'
.catch -> console.log "No docker to stop"
.then -> exec 'docker rm   docker-dns'
.catch -> console.log "No docker to remove"
.delay 3000
.then -> exec "docker run -d -t -h docker-dns --name docker-dns -p 172.17.42.1:53:53/udp -v /var/run/docker.sock:/var/run/docker.sock -v #{process.cwd()}/log:/var/log/supervisor shimaore/docker-dns"
.then -> console.log "Started"
