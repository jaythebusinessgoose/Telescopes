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

local telescopes = {}
local telescope_activated = false 
local telescope_was_activated = nil
local telescope_previous_zoom = nil
local telescope_button_closed = false

local function reset_telescopes()
	if telescope_previous_zoom then
		zoom(telescope_previous_zoom)
	end
    telescopes = {}
    telescope_activated = false
    telescope_was_activated = nil
    telescope_button_closed = false
    telescope_previous_zoom = nil
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
                    -- Save the previous zoom level so that we can correct the camera's zoom when
                    -- exiting the telescope.
                    telescope_previous_zoom = get_zoom_level()
                    -- Do not focus on the player while interacting with the telescope.
                    state.camera.focused_entity_uid = -1
                    local width, _ = size_of_level(level)
                    -- Set the x position of the camera to the half-way point of the level. The 2.5 is
                    -- added due to the amount
                    -- of concrete border that is shown at the edges of the level.
                    state.camera.focus_x = width * 5 + 2.5
                    -- 30 is a good zoom level to fit a 4-room wide level width-wise. For larger or
                    -- smaller levels, this value should be adjusted. Also, it should be adjusted to
                    -- fit height-wise if the level scrolls horizontally.
                    zoom(30)

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
                zoom(telescope_previous_zoom)
                telescope_previous_zoom = nil
                -- Make the camera follow the player again.
                state.camera.focused_entity_uid = player.uid
                telescope_button_closed = not test_flag(buttons, 6)
                return
            end
            
            -- Calculate the top and bottom of the level to stop the camera from moving.
            -- We don't want to show the player what we had to do at the top to get the level to generate without crashing.
            local _, room_pos_y = get_room_pos(0, 0)
            local width, height = size_of_level(level)
            local camera_speed = .3
            local _, max_room_pos_y = get_room_pos(width, height)
            -- Currently, all levels fit the width of the zoomed-out screen, so only handling moving up
            -- and down.
            if test_flag(buttons, 11) then -- up_key
                state.camera.focus_y = state.camera.focus_y + camera_speed
                if state.camera.focus_y > room_pos_y - 11 then
                    state.camera.focus_y = room_pos_y - 11
                end
            elseif test_flag(buttons, 12) then -- down_key
                state.camera.focus_y = state.camera.focus_y - camera_speed
                if state.camera.focus_y < max_room_pos_y + 8 then
                    state.camera.focus_y = max_room_pos_y + 8
                end
            end
        elseif telescope_was_activated ~= nil and state.time_level  - telescope_was_activated > 40 then
            -- Re-activate the player's inputs 40 frames after the button was pressed to leave the
            -- telescope. This gives plenty of time for the player to release the button that was pressed,
            -- but also doesn't feel too long since it mostly occurs while the camera is moving back.
            return_input(player.uid)
            button_prompts.hide_button_prompts(false)
            telescope_was_activated = nil
        end
    end, ON.FRAME)

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
    activate = activate,
    deactivate = deactivate,
}