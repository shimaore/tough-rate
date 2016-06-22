    seem = require 'seem'
    pkg = require '../package'
    @name = "#{pkg.name}:middleware:format-matcher"
    debug = (require 'debug') @name
    @include = seem ->

      return unless @session.direction is 'lcr'

      switch data = is_correct @destination
        when true
          return
        when false
          @repond '484'
        when null
          return
        else
          @session.destination_information = data
          yield @set
            initial_callee_id_name: data.full_name
            origination_callee_id_name: data.full_name

      return


is_correct
==========

Returns information about the destination if the number is correct; returns true if the number is correct but no further information is available; return false if the number is known to be incorrectly formatted; returns null if the number cannot be decided (for example because no data is available).

    @is_correct = is_correct = (number) ->

[Rec. E.164](https://www.itu.int/itu-t/recommendations/rec.aspx?rec=10688) section 6 limits the length of an E.164 number to 15 digits.
Note how we might use `#` to indicate a national-only (e.g. short) number.

      unless number.match /^\d[#\d]{3,14}$/
        debug 'number is not E.164 or compatible', number
        return false

Scan countries' prefixes, matching longest first; ITU assigns up to 7 digits.

      for prefix_length in [0..7].reverse()

Split the number in country-code vs nationally significant numbers

        country_code = number.substr 0, prefix_length
        national_number = number.substr prefix_length
        numbering_plan = numbering_plans[country_code]

        debug 'looking up', {prefix_length,country_code,national_number,numbering_plan}

        if numbering_plan?
          debug 'analyzing number', {number, country_code, national_number, numbering_plan }

CC-level blocking
-----------------

          if numbering_plan.block?
            if national_number.match numbering_plan.block
              debug 'number is blocked', number
              return false

Specific NDC
------------

First try to match by NDC or leading digits of N(S)N

          for ndc_length in [0..national_number.length].reverse()

            ndc = national_number.substr 0, ndc_length

[Rec. E.164](https://www.itu.int/itu-t/recommendations/rec.aspx?rec=10688) section 6.2.1 limits the length of the national number to 14 digits (worst case).
Note how we might use `#` to indicate a national-only (e.g. short) number.

            unless national_number.match /^[#\d]\d{0,13}$/
              debug 'national number is not compatible', national_number
              return false

            data = numbering_plan.plan[ndc]

            if data?

              debug 'analyzing number', {number, country_code, national_number, ndc, data }

If requested to block, then we know the format is incorrect.

              if data.block
                debug 'national number is not compatible', national_number
                return false

If the national number length doesn't match, we positively know that the number format is incorrect.

              significant_number = national_number
              if significant_number[0] is '#'
                significant_number = significant_number.substr 1


              unless data.min <= significant_number.length <= data.max
                debug 'invalid length', {number,significant_number,length:significant_number.length,data}
                return false

              data.country ?= numbering_plan.country

              data.national_name = numbering_plan.name
              if data.name?
                data.full_name = "#{data.name} (#{data.national_name})"
              else
                data.full_name = data.national_name

              return data

CC-level fallback
-----------------

Otherwise attempt to match the provided RegExp if any

          if numbering_plan.match?
            if national_number.match numbering_plan.match
              debug 'national number matches', national_number
              return true
            else
              debug 'national number does not match', national_number
              return false

Cannot decide

      return null


Numbering plans
===============

    numbering_plans = require './f/index'
