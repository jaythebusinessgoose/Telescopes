local button_prompts = require('ButtonPrompts/button_prompts')
define_tile_code("telescope")
define_tile_code("telescope_left")

local active = false
local telescope_right_tc = nil
local telescope_left_tc = nil
local telescope_camera_function = nil
local reset_variable_callback = nil


local telescopes = {}
local telescope_activated = false 
local telescope_was_activated = nil
local telescope_activated_time = nil
local telescope_previous_zoom = nil

local function reset_telescopes()
	if telescope_previous_zoom then
		zoom(telescope_previous_zoom)
	end
    telescopes = {}
    telescope_activated = false
    telescope_was_activated = nil
    telescope_activated_time = nil
    telescope_previous_zoom = nil
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
        for _, telescope in ipairs(telescopes) do
            if telescope and get_entity(telescope) and player.layer == get_entity(telescope).layer and distance(player.uid, telescope) <= 1 and player:is_button_pressed(BUTTON.DOOR) then
                -- Begin telescope interaction when the door button is pressed within a tile of the telescope.
                telescope_activated = true
                telescope_was_activated = nil
                telescope_activated_time = state.time_level
                -- Save the previous zoom level so that we can correct the camera's zoom when exiting the telescope.
                telescope_previous_zoom = get_zoom_level()
                -- Do not focus on the player while interacting with the telescope.
                state.camera.focused_entity_uid = -1
                local width, _ = size_of_level(level)
                -- Set the x position of the camera to the half-way point of the level. The 2.5 is added due to the amount
                -- of concrete border that is shown at the edges of the level.
                state.camera.focus_x = width * 5 + 2.5
                -- 30 is a good zoom level to fit a 4-room wide level width-wise. For larger or smaller levels, this value should be
                -- adjusted. Also, it should be adjusted to fit height-wise if the level scrolls horizontally.
                zoom(30)
                
                -- While looking through the telescope, the player should not be able to make any inputs. Instead, the movement
                -- keys will move the camera and the bomb key will dismiss the telescope.
                steal_input(player.uid)
                button_prompts.hide_button_prompts(true)
                break	
            end
        end
        if telescope_activated then
            -- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
            local buttons = read_stolen_input(player.uid)
            local telescope_activated_long = telescope_activated_time and state.time_level - telescope_activated_time > 40
            -- 1 = jump, 2 = whip, 3 = bomb, 4 = rope, 6 = Door
            if test_flag(buttons, 1) or test_flag(buttons, 2) or test_flag(buttons, 3) or test_flag(buttons, 4) or (telescope_activated_long and test_flag(buttons, 6)) then
                telescope_activated = false
                -- Keep track of the time that the telescope was deactivated. This will allow us to enable the player's
                -- inputs later so that the same input isn't recognized again to cause a bomb to be thrown or another action.
                telescope_was_activated = state.time_level
                telescope_activated_time = nil
                -- Zoom back to the original zoom level.
                zoom(telescope_previous_zoom)
                telescope_previous_zoom = nil
                -- Make the camera follow the player again.
                state.camera.focused_entity_uid = player.uid
                return
            end
            
            -- Calculate the top and bottom of the level to stop the camera from moving.
            -- We don't want to show the player what we had to do at the top to get the level to generate without crashing.
            local _, room_pos_y = get_room_pos(0, 0)
            local width, height = size_of_level(level)
            local camera_speed = .3
            local _, max_room_pos_y = get_room_pos(width, height)
            -- Currently, all levels fit the width of the zoomed-out screen, so only handling moving up and down.
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
            -- Re-activate the player's inputs 40 frames after the button was pressed to leave the telescope.
            -- This gives plenty of time for the player to release the button that was pressed, but also doesn't feel
            -- too long since it mostly occurs while the camera is moving back.
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
    activate = activate,
    deactivate = deactivate,
}