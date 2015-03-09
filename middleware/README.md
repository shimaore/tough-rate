The middleware is used with a Sinatra/ZappaJS type of API. Compare with ExpressJS middleware.

Module
======

Each module is inserted as follows:

    call_server = new CallServer ...
    module.call call_server, router

See the CallServer source for parameters available at that time, such as:

    @gateway_manager
    @options.provisioning
    @options.ruleset_of
    ...

The module must return a middleware function.

Middleware
==========

The following fields are available as input:

    @data         Data provided by FreeSwitch
    @source       The originating number (caller)
    @destination  The (original) destination number (callee)
    @req.header() Get extra SIP headers (`variable_sip_h`)

The following attributes are also available:

    @call         The current `esl` `FreeSwitchResponse` object.

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

    @attr         Add value to attributes (recorded in CDRs)

The following fields are available to late middleware (i.e. after the call attempts are processed):

    @res.response     The response set by `respond` if any.
    @res.winner       The winning gateway
    @res.gateways     The set (array) of routes to use
    @res.cause        (For late middleware) cause name
    @res.destination  The (final) destination

Other fields might be set by the middlewares, e.g.:

    @res.rule
