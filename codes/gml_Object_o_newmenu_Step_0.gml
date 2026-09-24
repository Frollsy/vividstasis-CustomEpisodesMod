// o_newmenu -- Step event, overridden by the Custom Episodes Mod.
//
// Replaced wholesale (not patched) so the guards below sit at the very top of the
// event. Everything after them is the game's own implementation, copied verbatim.
//
// Why the guards are needed at all: the stock menu reads the confirm key with
// input_check_pressed(Value_4), i.e. the very same key the picker uses, and it is
// only kept quiet by its own "is_active" flag. That flag is not ours to trust -
// several stock windows set it back to true when they close
// (obj_ratingWindow_Step_0, obj_charscreen_window_Alarm_0, ...), so a key press can
// reach both handlers and the two activations fight over the room.

if (global.mod_cs_key_consumed)
{
    // Consume here rather than clearing it every frame in the button's Step: this
    // way it does not matter which of the two events runs first.
    global.mod_cs_key_consumed = false;
    exit;
}

// The picker owns the keyboard while it is open, and the moment an episode starts
// (mode 1) the room transition is already in flight.
if (instance_exists(o_mod_storyentry))
{
    if (o_mod_storyentry.menu_open || o_mod_storyentry.mode == 1)
    {
        exit;
    }
}

if (is_active)
{
    if (input_check_pressed(UnknownEnum.Value_14) || mouse_wheel_down())
    {
        if (currentsel < (array_length(menu_objs) - 1))
        {
            currentsel++;
        }
        else if (input_check_pressed(UnknownEnum.Value_14))
        {
            currentsel = 0;
        }
        hovered = currentsel;
        refreshButtons();
        play_se(sfx_songsel_cursor);
    }
    if (input_check_pressed(UnknownEnum.Value_13) || mouse_wheel_up())
    {
        if (currentsel > 0)
        {
            currentsel--;
        }
        else if (input_check_pressed(UnknownEnum.Value_13))
        {
            currentsel = array_length(menu_objs) - 1;
        }
        hovered = currentsel;
        refreshButtons();
        play_se(sfx_songsel_cursor);
    }
    if (input_check_pressed(UnknownEnum.Value_5))
    {
        audio_stop_all();
        debug(video_get_status());
        if (video_get_status() == 3)
        {
            video_close();
            debug("CLOSE THE FUCKING VIDEO PLEASE I SWEAR TO GOD");
        }
        ini_open(global.profile_file);
        var p = ini_read_real("profile", "story_progress", 0);
        var fin = ini_read_real("profile", "finished_game", false);
        ini_close();
        play_se(sfx_songsel_beginsong);
        var transition = instance_create_depth(room_width / 2, room_height / 2, -10000, o_transition_diamond);
        with (transition)
        {
            TweenEasyScale(1, 1, 320, 320, 0, 60, EaseOutQuad);
            if (p >= 14 && p < 34)
            {
                next_room = scene_2024boot;
            }
            else
            {
                next_room = scene_2023boot;
            }
            if (fin)
            {
                next_room = postgame_titlescreen_go();
            }
            alarm[0] = 60;
        }
        is_active = false;
        exit;
    }
    if (input_check_pressed(UnknownEnum.Value_4))
    {
        global.main_menu_last_selected = currentsel;
        var button = menu_objs[currentsel];
        if (is_method(button.activate))
        {
            if (!button.obfuscate)
            {
                var func = method(self, button.activate);
                func();
            }
        }
    }
    var mouseButton = instance_position(mouse_x, mouse_y, o_newmainbutton);
    if (mouse_x != mouseX || mouse_y != mouseY)
    {
        mouseX = mouse_x;
        mouseY = mouse_y;
        if (mouseButton != -4)
        {
            var changed = false;
            for (var i = 0; i < array_length(menu_objs); i++)
            {
                if (mouseButton.id == menu_objs[i].id)
                {
                    if (hovered != i)
                    {
                        hovered = i;
                        play_se(sfx_songsel_cursor);
                        refreshButtons();
                    }
                    break;
                }
            }
        }
    }
    if (mouseButton != -4)
    {
        if (mouse_check_button_pressed(mb_left))
        {
            global.main_menu_last_selected = hovered;
            if (is_method(mouseButton.activate))
            {
                if (!mouseButton.obfuscate)
                {
                    var func = method(self, mouseButton.activate);
                    func();
                }
            }
        }
    }
}

enum UnknownEnum
{
    Value_4 = 4,
    Value_5,
    Value_13 = 13,
    Value_14
}
