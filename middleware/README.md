The middleware is based on the `useful-wind` project, with extensions provided by the `setup` middleware.

Middleware
==========

The following fields are available as input (provided by `useful-wind`):

    @data         Data provided by FreeSwitch
    @source       The originating number (caller)
    @destination  The (original) destination number (callee)
    @req.header() Get extra SIP headers (`variable_sip_h`)

The following attributes are also available (provided by `useful-wind`):

    @call         The current `esl` `FreeSwitchResponse` object.

The following operations are available to modify the responses (provided by the `setup` middleware):

    @res.redirect     Set the final destination number

    @res.attempt      Add a gateway to the route-set.
    @res.finalize     Indicate that no more modifications of the route-set will be allowed.
    @res.sendto       Set the route-set to a single, final destination URI, and returns that gateway; the route-set is finalized.
    @res.respond      Respond with a (numeric) error code; the route-set is cleared and finalised.
    @res.finalized()  Indicates whether the route-set has been finalized.

    @on               How to handle specific error codes (upon call attempts); the callback receives the gateway description.

    @res.attr         Add value to attributes (recorded in CDRs)

The following fields are available to late middleware (i.e. after the call attempts are processed):

    @session.winner   The winning gateway
    @res.gateways     The set (array) of routes to use
    @res.cause        (For late middleware) cause name
    @res.destination  The (final) destination

Other fields might be set by the middlewares, e.g.:

    @res.rule
