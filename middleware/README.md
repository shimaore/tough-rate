The middleware is used with a Sinatra/ZappaJS type of API.

The following fields are available as input:

    @data         Data provided by CouchDB
    @source       The originating number (caller)
    @destination  The (original) destination number (callee)
    @req.header   Get extra SIP headers (`variable_sip_h`)

The following operations are available to modify the responses:

    @redirect     Set the final destination number

    @attempt      Add a gateway to the route-set.
    @finalize     Indicate that no more modifications of the route-set will be allowed.
    @sendto       Set the route-set to a single, final destination URI; the route-set is finalized.
    @respond      Respond with a (numeric) error code; the route-set is cleared and finalised.
    @finalized()  Indicates whether the route-set has been finalized.

    @set          Set a parameter
    @unset        Unset a parameter, shortcut for `@set name, null`
    @export       Export a parameter

    @on           How to handle specific error codes (upon call attempts); the callback receives the gateway description.

The following fields are available to late middleware (i.e. after the call attempts are processed):

    @res.response     The response set by `respond` if any.
    @res.winner       The winning gateway
    @res.gateways     The set (array) of routes to use
    @res.cause        (For late middleware) cause name
    @res.destination  The (final) destination

Other fields might be set by the middlewares, e.g.:

    @res.rule


Typical ordering:

    @use 'middleware/numeric'
    @use 'middleware/response-handlers'
    @use 'middleware/local-number'
    @use 'middleware/emergency'
    @use 'middleware/ccnq-base'
    @use 'middleware/routes-gwid'
    @use 'middleware/routes-carrierid'
    @use 'middleware/routes-registrant'
    @use 'middleware/ccnq-gwlist'
    @use 'middleware/call-handler'
    @use 'middleware/respond'
