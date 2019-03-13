    CouchDB = require 'most-couchdb/with-update'

    module.exports = class TestCouchDB extends CouchDB

      bulkDocs: (docs) ->
        uri = new URL '_bulk_docs', @uri+'/'
        @agent
        .post uri.toString()
        .type 'json'
        .accept 'json'
        .send {docs}
        .then ({body}) -> body
