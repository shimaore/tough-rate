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

            data = numbering_plan[ndc]

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

              data.national_name = numbering_plan.name
              if data.name?
                data.full_name = data.national_name + ' ' + data.name
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

The following numbering plans are established with the convention that national-only, short numbers, etc. are routed using `#` as a separator between the country-code and the national number. (Except in the case of France, where `0` is allowed as the separator for historical reasons.)

Available fields, where applicable, are:

- `fixed`
- `mobile`
- `special`
= `value_added`

For `fixed`:
- `geographic`
- `corporate`

For `value_added`:
- `freephone`
- `shared_cost`
- `personal`
- `premium`
- `adult`

For `special`:
- `voicemail`
- `test`
- `vpn`
- `emergency`

If a field is absent its value is assumed to be `false`.

    numbering_plans =

Switzerland (+41)
-----------------

Sources:
- https://www.bakom.admin.ch/bakom/en/home/telecommunication/numbering-and-telephony/number-blocks-and-codes.html, especially the document "Numbering plan for international carriers"
- https://www.eofcom.admin.ch/eofcom//public/searchEofcom_e164Allocated.do?target=doChangeLanguage

      41:

        name: 'ch'

Special services, short numbers

        '#1': max: 6, min: 3, special: true

Fixed, geographic

        21: max: 9, min: 9, fixed: true, geographic: true, name: 'Lausanne'
        22: max: 9, min: 9, fixed: true, geographic: true, name: 'Geneva'
        24: max: 9, min: 9, fixed: true, geographic: true, name: 'Yverdon, Aigle'
        26: max: 9, min: 9, fixed: true, geographic: true, name: 'Fribourg'
        27: max: 9, min: 9, fixed: true, geographic: true, name: 'Sion'

        31: max: 9, min: 9, fixed: true, geographic: true, name: 'Berne'
        32: max: 9, min: 9, fixed: true, geographic: true, name: 'Bienne, Neuchâtel, Soleure, Jura'
        33: max: 9, min: 9, fixed: true, geographic: true, name: 'Thun'
        34: max: 9, min: 9, fixed: true, geographic: true, name: 'Burgdorf, Langnau i.E.'

        41: max: 9, min: 9, fixed: true, geographic: true, name: 'Lucerne'
        43: max: 9, min: 9, fixed: true, geographic: true, name: 'Zurich'
        44: max: 9, min: 9, fixed: true, geographic: true, name: 'Zurich'

        51: max: 9, min: 9, fixed: true, corporate: true, name: 'national railways'
        52: max: 9, min: 9, fixed: true, geographic: true, name: 'Winterthur'
        55: max: 9, min: 9, fixed: true, geographic: true, name: 'Rapperswil'
        56: max: 9, min: 9, fixed: true, geographic: true, name: 'Baden'
        58: max: 9, min: 9, fixed: true, corporate: true, name: 'corporate networks'

        61: max: 9, min: 9, fixed: true, geographic: true, name: 'Basel'
        62: max: 9, min: 9, fixed: true, geographic: true, name: 'Olten'

        71: max: 9, min: 9, fixed: true, geographic: true, name: 'St. Gallen'
        73: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'
        74: max: 9, min: 9, mobile: true, name: 'paging services'
        75: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'
        76: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'
        77: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'
        78: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'
        79: max: 9, min: 9, mobile: true, name: 'GSM / UMTS / LTE'

        800: max: 9, min: 9, value_added: true, freephone: true, name: 'freephone numbers'
        81: max: 9, min: 9, fixed: true, geographic: true, name: 'Chur'
        840: max: 9, min: 9, value_added: true, shared_cost: true, name: 'shared cost'
        842: max: 9, min: 9, value_added: true, shared_cost: true, name: 'shared cost'
        844: max: 9, min: 9, value_added: true, shared_cost: true, name: 'shared cost'
        848: max: 9, min: 9, value_added: true, shared_cost: true, name: 'shared cost'
        860: max: 12, min: 12, special: true, voicemail: true, name: 'voicemail'
        868: max: 9, min: 9, special: true, test: true, name: 'test'
        869: max: 13, min: 6, special: true, vpn: true, name: 'VPN'
        878: max: 9, min: 6, value_added: true, personal: true, name: 'personal (UPT)'

        900: max: 9, min: 9, value_added: true, premium: true, name: 'Premium business, marketing'
        901: max: 9, min: 9, value_added: true, premium: true, name: 'Premium entertainment, games, competitions'
        906: max: 9, min: 9, value_added: true, premium: true, adult: true, name: 'Premium adult'

        91: max: 9, min: 9, fixed: true, geographic: true, name: 'Bellinzona'
        # 98 non-diallable
        # 99 non-diallable

France (+33)
------------

Source: https://extranet.arcep.fr/portail/Op%C3%A9rateursCE/Num%C3%A9rotation.aspx

      33:

Although these are dialable from within France, using them as-is is incorrect since the proper country-code should be used.
See huge-play/middleware/client/egress/national-FR.coffee.md for proper translations.

        1: max: 9, min: 9, fixed: true, geographic: true, name: 'Île-de-France'
        10: block: true # portability prefixes
        105: max: 9, min: 9, fixed: true, geographic: true, name: 'Île-de-France'

        2: max: 9, min: 9, fixed: true, geographic: true, name: 'Nord-Ouest'
        20: block: true # portability prefixes
        262: block: true # ARCEP 06-0720 # ARCEP 06-0535 + 00-0536
        269: block: true # ARCEP 06-0720

        3: max: 9, min: 9, fixed: true, geographic: true, name: 'Nord-Est'
        30: block: true # portability prefixes

        4: max: 9, min: 9, fixed: true, geographic: true, name: 'Sud-Est'
        30: block: true # portability prefixes

        5: max: 9, min: 9, fixed: true, geographic: true, name: 'Sud-Ouest'
        50: block: true # portability prefixes
        508: block: true # ARCEP 06-0535 + 00-0536
        509: block: true # mobile portability prefixes
        510: block: true # mobile portability prefixes
        511: block: true # mobile portability prefixes
        512: block: true # mobile portability prefixes
        513: block: true # mobile portability prefixes
        514: block: true # mobile portability prefixes
        515: block: true # mobile portability prefixes
        590: block: true # ARCEP 06-0535 + 00-0536
        594: block: true # ARCEP 06-0535 + 00-0536
        596: block: true # ARCEP 06-0535 + 00-0536

        6: max: 9, min: 9, mobile: true
        600: block: true # portability prefixes
        639: block: true, mobile: true, name: 'Mayotte' # ARCEP 06-0720
        653: block: true # Mobile Station Roaming Number
        654: block: true # Mobile Station Roaming Number
        655: block: true # Mobile Station Roaming Number
        69: block: true, mobile: true
        690: block: true, mobile: true, name: 'Guadeloupe' # ARCEP 06-0535 + 00-0536
        691: block: true, mobile: true, name: 'Guadeloupe' # ARCEP 2012-0855
        692: block: true # ARCEP 06-0535 + 00-0536
        694: block: true, mobile: true, name: 'Guyane' # ARCEP 06-0535 + 00-0536
        696: block: true # ARCEP 06-0535 + 00-0536
        697: block: true, mobile: true, name: 'Martinique' # ARCEP 2012-0855

        7: max: 9, min: 9, mobile: true
        700: max: 13, min: 13, mobile: true, m2m: true
        7005: max: 12, min: 12, mobile: true, m2m: true, name: 'Guadeloupe'
        7006: max: 12, min: 12, mobile: true, m2m: true, name: 'Guyane'
        7007: max: 12, min: 12, mobile: true, m2m: true, name: 'Martinique'
        7008: max: 12, min: 12, mobile: true, m2m: true, name: 'Mayotte'
        7009: max: 12, min: 12, mobile: true, m2m: true, name: 'La Réunion'
        73: max: 9, min: 9, mobile: true
        74: max: 9, min: 9, mobile: true
        75: max: 9, min: 9, mobile: true
        76: max: 9, min: 9, mobile: true
        77: max: 9, min: 9, mobile: true
        78: max: 9, min: 9, mobile: true
        79: block: true, max: 9, min: 9, mobile: true, name: 'Reserved'

        8: max: 9, min: 9, value_added: true
        800: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        801: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        802: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        803: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        804: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        805: max: 9, min: 9, value_added: true, freephone: true, name: 'tarification gratuite'
        806: max: 9, min: 9, value_added: true, name: 'tarification banalisée'
        807: max: 9, min: 9, value_added: true, name: 'tarification banalisée'
        808: max: 9, min: 9, value_added: true, name: 'tarification banalisée'
        809: max: 9, min: 9, value_added: true, name: 'tarification banalisée'
        81: max: 9, min: 9, value_added: true, premium: true
        82: max: 9, min: 9, value_added: true, premium: true
        84: block: true # routing prefix for added-value services & others
        85: special: true, vpn: true, name:'VPN'
        836: block: true, value_added: true, premium: true # data services
        860: block: true, value_added: true, premium: true # internet access
        868: block: true, value_added: true, premium: true # internet access
        89: max: 9, min: 9, value_added: true, premium: true
        895: max: 9, min: 9, value_added: true, premium: true, adult: true

The 876 block is apparently no longer assigned, but I found no document indicating the blocks were moved (to the 976 block?).

        876: block: true
        8760: block: true # ARCEP 04-0847
        8761: block: true # ARCEP 04-0847
        8762: block: true # ARCEP 04-0847
        8763: block: true # ARCEP 04-0847
        8764: block: true # ARCEP 04-0847
        8766: block: true # ARCEP 04-0847
        8767: block: true # ARCEP 04-0847

        9: max: 9, min: 9, fixed: true, geographic: false
        900: block: true # non-geographic numbers portability prefixes
        976: block: true, fixed: true, geographic: false
        9760: block: true, fixed: true, geographic: false, name: 'Guadeloupe'
        9761: block: true, fixed: true, geographic: false, name: 'Guadeloupe'
        9762: block: true, fixed: true, geographic: false, name: 'Réunion / Océan indien'
        9763: block: true, fixed: true, geographic: false, name: 'Réunion / Océan indien'
        9764: block: true, fixed: true, geographic: false, name: 'Guyane'
        9765: block: true, fixed: true, geographic: false, name: 'Guyane'
        9766: block: true, fixed: true, geographic: false, name: 'Martinique'
        9767: block: true, fixed: true, geographic: false, name: 'Martinique'
        9768: block: true, fixed: true, geographic: false, name: 'Guadeloupe'
        9769: block: true, fixed: true, geographic: false, name: 'Réunion / Océan indien'

        999: block: true # Usage technique interne

        '#10': max: 4, min: 4, value_added: true, premium: true

The following groups must be translated.

        '#11': max: 3, min: 3, special: true, emergency: true
        '#116': max: 6, min: 6, special: true, emergency: true
        '#15': max: 2, min:2, special: true, emergency: true
        '#16': block: true # carrier selection
        '#17': max: 2, min:2, special: true, emergency: true
        '#18': max: 2, min:2, special: true, emergency: true
        '#19': max: 3, min: 3, special: true, emergency: true

        '#3': max: 4, min: 4, value_added: true
        '#30': max: 4, min: 4, value_added: true, freephone: true, name: 'tarification gratuite'
        '#3008': max: 4, min: 4, block: true # carrier-dependent
        '#31': max: 4, min: 4, value_added: true, freephone: true, name: 'tarification gratuite'
        '#3170': max: 4, min: 4, block: true # carrier-dependent
        '#3171': max: 4, min: 4, block: true # carrier-dependent
        '#3172': max: 4, min: 4, block: true # carrier-dependent
        '#3173': max: 4, min: 4, block: true # carrier-dependent
        '#3174': max: 4, min: 4, block: true # reserved
        '#3175': max: 4, min: 4, block: true # reserved
        '#3176': max: 4, min: 4, block: true # reserved
        '#3177': max: 4, min: 4, block: true # reserved
        '#3178': max: 4, min: 4, block: true # reserved
        '#3179': max: 4, min: 4, block: true # carrier-dependent
        '#32': max: 4, min: 4, value_added: true, premium: true
        '#33': max: 4, min: 4, value_added: true, premium: true
        '#34': max: 4, min: 4, value_added: true, premium: true
        '#35': max: 4, min: 4, value_added: true, premium: true
        '#36': max: 4, min: 4, value_added: true, premium: true
        '#37': max: 4, min: 4, value_added: true, premium: true
        '#38': max: 4, min: 4, value_added: true, premium: true
        '#39': max: 4, min: 4, value_added: true, premium: true

        '#118': max: 6, min: 6, value_added: true, premium: true

NANPA (+1)
----------

      1:

Block all matching

        block: /// ^ \d\d\d 555 ///

Fallback

        match: /// ^ \d\d\d \d\d\d \d\d\d\d $ ///
