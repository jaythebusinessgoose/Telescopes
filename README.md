# Telescopes
Telescope tile codes for use in Spelunky 2 level mods

## Usage

The only thing required to use the telescopes is to load in the script and use one of the two tile codes:
- `telescope`, for a telescope facing towards the right.
- `telescope_left`, for a telescope facing towards the left.

Both tile codes act the same; the only difference is how the telescope looks.

## Dismissal

There are five inputs that are valid for dismissing the telescope while the player is looking through it:
- Jump
- Whip
- Bomb
- Rope
- Door

By default, all five inputs are enabled. Any input can be disabled via the `disable_dismissal_input`
function. Eg:

```
local telescopes = require("Telescopes/telescopes")
telescopes.disable_dismissal_input(telescopes.INPUTS.JUMP)
```

To re-enable a disabled input, call `allow_dismissal_input`.

```
local telescopes = require("Telescopes/telescopes")
telescopes.allow_dismissal_input(telescopes.INPUTS.JUMP)
```
