local button_prompts = require('ButtonPrompts/button_prompts')
define_tile_code("telescope")
define_tile_code("telescope_left")

local INPUTS = {
    JUMP = 1,
    WHIP = 2,
    BOMB = 4,
    ROPE = 8,
    RUN = 16,
    DOOR = 32,
    MENU = 64,
    JOURNAL = 128,
    LEFT = 256,
    RIGHT = 512,
    UP = 1024,
    DOWN = 2048,
}

local active = false
local telescope_right_tc = nil
local telescope_left_tc = nil
local telescope_camera_function = nil
local reset_variable_callback = nil
local hud_callback = nil

local telescopes = {}
local telescope_activated = false 
local telescope_was_activated = nil
local telescope_button_closed = false

local show_hud_buttons = true
local function set_show_hud_buttons(show_buttons)
    show_hud_buttons = show_buttons
end

local valid_inputs = {
    jump = true,
    whip = true,
    bomb = true,
    rope = true,
    door = true,
}

-- Enable an input as a way of dismissing the telescope. Valid inputs are:
-- - INPUTS.JUMP
-- - INPUTS.WHIP
-- - INPUTS.BOMB
-- - INPUTS.ROPE
-- - INPUTS.DOOR
--
-- By default, all valid inputs are enabled.
local function allow_dismissal_input(input)
    if input == INPUTS.JUMP then
        valid_inputs.jump = true
    elseif input == INPUTS.WHIP then
        valid_inputs.whip = true
    elseif input == INPUTS.BOMB then
        valid_inputs.bomb = true
    elseif input == INPUTS.ROPE then
        valid_inputs.rope = true
    elseif input == INPUTS.DOOR then
        valid_inputs.door = true
    elseif input == INPUTS.LEFT or
            input == INPUTS.RIGHT or
            input == INPUTS.UP or
            input == INPUTS.DOWN then
        error("Cannot use a directional input as a dismissal input.")
    elseif input == INPUTS.JOURNAL then
        error("Cannot use journal button as a dismissal input.")
    elseif input == INPUTS.MENU then
        error("Cannot use menu button as a dismissal input.")
    else
        error("Invalid input. Please use one of: INPUTS.JUMP, INPUTS.WHIP, INPUTS.BOMB, INPUTS.ROPE, INPUTS.DOOR.")
    end
end

-- Disable an input so that pressing it does not dismiss the telescope. Valid inputs are:
-- - INPUTS.JUMP
-- - INPUTS.WHIP
-- - INPUTS.BOMB
-- - INPUTS.ROPE
-- - INPUTS.DOOR
--
-- By default, all valid inputs are enabled.
local function disable_dismissal_input(input)
    if input == INPUTS.JUMP then
        valid_inputs.jump = false
    elseif input == INPUTS.WHIP then
        valid_inputs.whip = false
    elseif input == INPUTS.BOMB then
        valid_inputs.bomb = false
    elseif input == INPUTS.ROPE then
        valid_inputs.rope = false
    elseif input == INPUTS.DOOR then
        valid_inputs.door = false
    elseif input == INPUTS.LEFT or
            input == INPUTS.RIGHT or
            input == INPUTS.UP or
            input == INPUTS.DOWN then
        error("Cannot use a directional input as a dismissal input.")
    elseif input == INPUTS.JOURNAL then
        error("Cannot use journal button as a dismissal input.")
    elseif input == INPUTS.MENU then
        error("Cannot use menu button as a dismissal input.")
    else
        error("Invalid input. Please use one of: INPUTS.JUMP, INPUTS.WHIP, INPUTS.BOMB, INPUTS.ROPE, INPUTS.DOOR.")
    end
end

-- Checks if a valid dismissal input is being pressed.
-- inputs: Bitmasked inputs that are being pressed, to be checked.
local function test_dismissal_input(inputs)
    if not telescope_button_closed and not test_flag(inputs, 6) then
        -- Re-activate the telescope button as a potential dismissal button once it has been
        -- released.
        telescope_button_closed = true
    end
    -- 1 = jump, 2 = whip, 3 = bomb, 4 = rope, 6 = Door
    if valid_inputs.jump and test_flag(inputs, 1) then
        return true
    elseif valid_inputs.whip and test_flag(inputs, 2) then
        return true
    elseif valid_inputs.bomb and test_flag(inputs, 3) then
        return true
    elseif valid_inputs.rope and test_flag(inputs, 4) then
        return true
    elseif valid_inputs.door and telescope_button_closed and test_flag(inputs, 6) then
        -- Only allow the door button to deactivate the telescope after a certain amount of time so
        -- that it does not dismiss immediately while being held.
        return true
    end
    return false
end

local max_zoom = 30
local max_zoom_co = 22
local min_zoom = 13.5
local default_zoom = 13.5
local function set_max_zoom(zoom)
    max_zoom = zoom
end
local function set_max_zoom_co(zoom)
    max_zoom_co = zoom
end
local function set_min_zoom(zoom)
    min_zoom = zoom
end
local function set_default_zoom(zoom)
    default_zoom = zoom
end

-- These are the ratios of zoom value to tiles visible on camera at that zoom level.
-- This means that the width of the camera is equal to `get_zoom_level() * width_zoom_factor` and the
-- height of the camera is equal to `get_zoom_level() * height_zoom_factor`.
-- Similarly, we can divide the height or width of the level by these values to get the appropriate
-- zoom level to use to display the entire level.
local width_zoom_factor = 1.47276954
local height_zoom_factor = 0.82850041

local function zoom_level_fitting_bounds()
    local function preferred_zoom_for_width()
        if state.theme == THEME.COSMIC_OCEAN then
            -- The cosmic ocean has no camera bounds, so use the size of the level only to calculate
            -- the proper zoom level.
            return state.width * 10 / width_zoom_factor
        end
        return (state.camera.bounds_right - state.camera.bounds_left) / width_zoom_factor
    end
    local function preferred_zoom_for_height()
        if state.theme == THEME.COSMIC_OCEAN then
            -- The cosmic ocean has no camera bounds, so use the size of the level only to calculate
            -- the proper zoom level.
            return state.height * 8 / height_zoom_factor
        end
        return (state.camera.bounds_top - state.camera.bounds_bottom) / 0.82850041
    end

    local preferred_width_zoom = preferred_zoom_for_width()
    local preferred_height_zoom = preferred_zoom_for_height()
    -- Use the dimension with the smaller zoom level. In the other dimension, we will scroll.
    local preferred_zoom = math.min(preferred_width_zoom, preferred_height_zoom)

    -- If the level is very large, limit the zoom to 30 and allow the camera to scroll in both
    -- directions. Also, never zoom in from the default zoom value.
    local max_zoom_level = max_zoom
    if state.theme == THEME.COSMIC_OCEAN then
        -- In the CO, the tiles beyond the loop don't start rendering until a certain distance
        -- from the player. Keep the max zoom small enough that the tiles aren't visible as they
        -- are rendering in.
        --
        -- Some things may still look choppy when rendering in, such as very large background
        -- decorations, which will only load in when their center is close enough to load.
        max_zoom_level = max_zoom_co
    end
    return math.max(math.min(max_zoom_level, preferred_zoom), min_zoom)
end

local function camera_size_for_zoom_level(zoom_level)
    return zoom_level * width_zoom_factor, zoom_level * height_zoom_factor
end

local function camera_size_for_expected_zoom_level()
    return camera_size_for_zoom_level(zoom_level_fitting_bounds())
end

local function camera_focus_edges_for_zoom_level(zoom_level)
    local width, height = camera_size_for_zoom_level(zoom_level)
    local camera = state.camera
    local left = camera.bounds_left + width / 2
    local right = camera.bounds_right - width / 2
    if camera.bounds_right - camera.bounds_left < width then
        -- If the level is too narrow for the zoom level, put both edges in the center.
        left = (camera.bounds_right + camera.bounds_left) / 2
        right = left
    end
    local top = camera.bounds_top - height / 2
    local bottom = camera.bounds_bottom + height / 2
    if camera.bounds_top - camera.bounds_bottom < height then
        -- If the level is too short for the zoom level, put both edges in the center.
        top = (camera.bounds_top + camera.bounds_bottom) / 2
        bottom = top
    end
    return left, right, top, bottom
end

local function camera_focus_edges_for_expected_zoom_level()
    return camera_focus_edges_for_zoom_level(zoom_level_fitting_bounds())
end

local function move_camera_focus_within_co()
    local camera = state.camera
    -- If we go beyond the edge in any dimension, move the camera back in the loop to the same position.
    -- Also move the adjusted focus; otherwise, the camera will pan over across the loop and it will
    -- look bad.
    if camera.focus_x < 0 then
        camera.focus_x = camera.focus_x + (state.width * 10)
        camera.adjusted_focus_x = camera.adjusted_focus_x + (state.width * 10)
    end
    if camera.focus_x > state.width * 10 then
        camera.focus_x = camera.focus_x - state.width * 10
        camera.adjusted_focus_x = camera.adjusted_focus_x - state.width * 10
    end
    if camera.focus_y > 122.5 then
        camera.focus_y = camera.focus_y - state.height * 8
        camera.adjusted_focus_y = camera.adjusted_focus_y - state.height * 8
    end
    if camera.focus_y < 122.5 - state.height * 8 then
        camera.focus_y = camera.focus_y + state.height * 8
        camera.adjusted_focus_y = camera.adjusted_focus_y + state.height * 8
    end
end

local function move_camera_focus_within_bounds()
    if state.theme == THEME.COSMIC_OCEAN then
        -- The CO doesn't have bounds, so we will just make sure it loops properly.
        return move_camera_focus_within_co()
    end
    local max_left, max_right, max_top, max_bottom = camera_focus_edges_for_expected_zoom_level()
    local camera = state.camera

    if camera.focus_x < max_left then
        camera.focus_x = max_left
    end
    if camera.focus_x > max_right then
        camera.focus_x = max_right
    end
    if camera.focus_y > max_top then
        camera.focus_y = max_top
    end
    if camera.focus_y < max_bottom then
        camera.focus_y = max_bottom
    end
end

local function camera_at_bounds()
    if state.theme == THEME.COSMIC_OCEAN then
        return false, false, false, false
    end
    local max_left, max_right, max_top, max_bottom = camera_focus_edges_for_expected_zoom_level()
    local camera = state.camera

    local tiny = 0.0001
    return camera.focus_x <= max_left + tiny,
            camera.focus_x >= max_right - tiny,
            camera.focus_y >= max_top - tiny,
            camera.focus_y <= max_bottom + tiny
end

local function reset_telescopes()
    zoom(default_zoom)
    telescopes = {}
    telescope_activated = false
    telescope_was_activated = nil
    telescope_button_closed = false
end

local function activate()
    if active then return end
    active = true
    button_prompts.activate()
    function spawn_telescope(x, y, layer, facing_right)
        local new_telescope = spawn_entity(ENT_TYPE.ITEM_TELESCOPE, x, y, layer, 0, 0)
        telescopes[#telescopes+1] = new_telescope
        local telescope_entity = get_entity(new_telescope)
        -- Disable the telescope's default interaction because it interferes with the zooming and panning we want to do
        -- when interacting with the telescope.
        telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
        if facing_right then
            -- Turn the telescope to the right.
            telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.FACING_LEFT)
        end
        button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.VIEW, x, y, layer)
    end
    telescope_right_tc = set_pre_tile_code_callback(function(x, y, layer)
        spawn_telescope(x, y, layer, true)
        return true
    end, "telescope")

    -- Telescope facing left.
    telescope_left_tc = set_pre_tile_code_callback(function(x, y, layer)
        spawn_telescope(x, y, layer, false)
        return true
    end, "telescope_left")

    telescope_camera_function = set_callback(function() 
        if #players < 1 or not telescopes then return end
        
        local camera = state.camera
        local player = players[1]
        if not telescope_activated and telescope_was_activated == nil then
            if not telescope_button_closed and not player:is_button_pressed(BUTTON.DOOR) then
                telescope_button_closed = true
            end
            for _, telescope in ipairs(telescopes) do
                if telescope_button_closed and
                        telescope and get_entity(telescope) and
                        player.layer == get_entity(telescope).layer and
                        distance(player.uid, telescope) <= 1 and
                        player:is_button_pressed(BUTTON.DOOR) then
                    -- Begin telescope interaction when the door button is pressed within a tile of the
                    -- telescope.
                    telescope_activated = true
                    telescope_was_activated = nil
                    telescope_button_closed = false

                    -- Do not focus on the player while interacting with the telescope.
                    camera.focused_entity_uid = -1

                    -- Zoom the camera out and move the focus of the camera so that the camera is in
                    -- bounds with the new zoom level.
                    move_camera_focus_within_bounds()
                    zoom(zoom_level_fitting_bounds())

                    -- While looking through the telescope, the player should not be able to make any
                    -- inputs. Instead, the movement keys will move the camera and the bomb key will
                    -- dismiss the telescope.
                    steal_input(player.uid)
                    button_prompts.hide_button_prompts(true)
                    break
                end
            end
        end

        if telescope_activated then
            -- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
            local buttons = read_stolen_input(player.uid)
            if test_dismissal_input(buttons) then
                telescope_activated = false
                -- Keep track of the time that the telescope was deactivated. This will allow us to
                -- enable the player's inputs later so that the same input isn't recognized again to
                -- cause a bomb to be thrown or another action.
                telescope_was_activated = state.time_level
                -- Zoom back to the original zoom level.
                zoom(default_zoom)
                -- Make the camera follow the player again.
                state.camera.focused_entity_uid = player.uid
                telescope_button_closed = not test_flag(buttons, 6)
                return
            end
            
            local camera_speed = .3
            if test_flag(buttons, 11) then -- up_key
                camera.focus_y = camera.focus_y + camera_speed
            end
            if test_flag(buttons, 12) then -- down_key
                camera.focus_y = camera.focus_y - camera_speed
            end
            if test_flag(buttons, 10) then -- right_key
                camera.focus_x = camera.focus_x + camera_speed
            end
            if test_flag(buttons, 9) then -- left_key
                camera.focus_x = camera.focus_x - camera_speed
            end
            -- Now that we have resolved all of the inputs for the frame, make sure to keep the
            -- focus so that the camera is still in bounds.
            move_camera_focus_within_bounds()
        elseif telescope_was_activated ~= nil and state.time_level  - telescope_was_activated > 40 then
            -- Re-activate the player's inputs 40 frames after the button was pressed to leave the
            -- telescope. This gives plenty of time for the player to release the button that was pressed,
            -- but also doesn't feel too long since it mostly occurs while the camera is moving back.
            return_input(player.uid)
            button_prompts.hide_button_prompts(false)
            telescope_was_activated = nil
        end
    end, ON.FRAME)

    hud_callback = set_callback(function(ctx)
        if not telescope_activated or not show_hud_buttons then return end
        local buttonsx = .95
        local buttonssize = .0014
        local at_left, at_right, at_top, at_bottom = camera_at_bounds()
        if not at_left then
            ctx:draw_text("\u{8B}", -buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
        if not at_right then
            ctx:draw_text("\u{8C}", buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
        if not at_top then
            ctx:draw_text("\u{8D}", 0, .9, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
        if not at_bottom then
            ctx:draw_text("\u{8E}", 0, -.8, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
    end, ON.RENDER_POST_HUD)

    reset_variable_callback = set_callback(function()
        reset_telescopes()
    end, ON.PRE_LOAD_LEVEL_FILES)
end

local function deactivate()
    if not active then return end
    active = false
    reset_telescopes()
    if telescope_left_tc then
        clear_callback(telescope_left_tc)
    end
    if telescope_right_tc then
        clear_callback(telescope_right_tc)
    end
    if telescope_camera_function then
        clear_callback(telescope_camera_function)
    end
    if reset_variable_callback then
        clear_callback(reset_variable_callback)
    end
    if hud_callback then
        clear_callback(hud_callback)
    end
    button_prompts.deactivate()
end

set_callback(function(ctx)
    -- Initialize in the active state.
    activate()
end, ON.LOAD)

return {
    INPUTS = INPUTS,
    allow_dismissal_input = allow_dismissal_input,
    disable_dismissal_input = disable_dismissal_input,
    set_show_hud_buttons = set_show_hud_buttons,
    set_max_zoom = set_max_zoom,
    set_max_zoom_co = set_max_zoom_co,
    set_min_zoom = set_min_zoom,
    set_default_zoom = set_default_zoom,
    activate = activate,
    deactivate = deactivate,
}