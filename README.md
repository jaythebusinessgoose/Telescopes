# Telescopes
Telescope tile codes for use in Spelunky 2 level mods

## Usage

The only thing required to use the telescopes is to load in the script and use one of the two tile codes:
- `telescope_right`, for a telescope facing towards the right.
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

## HUD controls

By default directional controls will show in the HUD when the telescope is active, showing in the directions that the camera is available to move in. This behavior can be disabled via the `set_show_hud_buttons` method.

```
telescopes.set_show_hud_buttons(false)
```

The hud buttons are by default positioned at the edges of the screen. In the case that there is other UI near the edges of the screen, the hud buttons can be inset.

```
telescopes.set_hud_button_insets(top_inset, left_inset, bottom_inset, right_inset)
```

Positive insets move the hud closer to the center, whereas negative insets move the hud farther from the center.

Insets use decimal values where the entire screen has a width and height of 2, so an inset of 1 in any dimension will move it close to the center.

## Zoom levels

When activating a telescope, a zoom level is chosen so that the camera fits either the width or the height of the level, whichever is smaller. 

### max_zoom

If the level is extra large, the zoom level will instead be set to the max zoom, which is about the zoom of a 4-wide level. This behavior can be configured by setting a different max zoom via `set_max_zoom`.

Default: 30

```
telescopes.set_max_zoom(40)
```

- To disable this behavior, set the max zoom to a large value.

### max_zoom_co

In the cosmic ocean, tiles on the other side of the loop don't render until they are a certain distance from the camera's center. For this reason a smaller zoom is used as the max zoom in the CO. The default max zoom was chosen to not show tiles rendering in in a 4-wide level, but other values may be preferred in different level sizes. This value is separately configurable via `set_max_zoom_co`, and the value of `max_zoom` is completely ignored in the cosmic ocean and won't affect this value.

Default: 22

```
telescopes.set_max_zoom_co(30)
```

### min_zoom

Very small levels would require zooming in closer than the default zoom to fit the width of the level. To prevent zooming in, a minimum allowed zoom is used. This is also configurable, via `set_min_zoom`.

Default: 13.5

```
telescopes.set_min_zoom(3)
```

### default_zoom

When the telescope is dismissed, the zoom level is set back to the default_zoom. By default, this is the same as the normal zoom level when playing the game. If this zoom is being changed, the default_zoom can be configured to match the desired zooming behavior via `set_default_zoom`.

Default: 13.5

```
telescopes.set_default_zoom(20)
```
