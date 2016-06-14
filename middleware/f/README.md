Numbering plans
===============

The following numbering plans are established with the convention that national-only, short numbers, etc. are routed using `#` as a separator between the country-code and the national number. (Except in the case of France, where `0` is allowed as the separator for historical reasons.)

Available fields, where applicable, are:

- `min`: minimum length of _national_ number
- `max`: maximum lenght of _national_ number

- `fixed`
- `mobile`
- `special`
- `value_added`

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
