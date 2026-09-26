// o_mod_storyentry -- Step event (every frame).
// Two modes:
//   mode 1 = a custom episode is playing inside scene_story (playback itself runs as
//            a game coroutine, so this event only watches for the session ending)
//   mode 0 = anything else; watch for the picker entry key and handle picker input
//
// All keyboard reads live in this Step event on purpose: keyboard_check_pressed()
// is unreliable inside Draw events (the frame's keyboard state is consumed by
// the time drawing runs), which made the picker ignore arrow keys and ESC.
//
// Comments in this file are intentionally ASCII-only. See the Create event.


// Finish a release that mod_cs_end() deferred: by now the room has changed, so the
// story room's o_bg / portraits - the only things that pointed at the external
// sprites - are gone.
if (global.mod_cs_release_pending)
{
    global.mod_cs_release_pending = false;
    mod_cs_log("step: pending release (room=" + string(room) + ")");
    mod_cs_release_episode();
}

// In-chart stories (the "custom_episode" gimmick). A chart has no story
// coroutine, so the request, the playback and the cleanup all run from here; the
// runner stops itself when the song or the room goes away. See the Create event.
mod_cs_chart_tick();

// Track room changes: leaving scene_story while an episode is running means the
// session is over - either the story finished, or the player left through the pause
// menu, which cancels the coroutine and never runs our own cleanup.
var _room_now = room;
var _room_changed = (_room_now != mcs_last_room);
mcs_last_room = _room_now;

if (mode == 1 && _room_changed && _room_now != scene_story)
{
    // Back out of playback mode and hand the keyboard back to the picker. Without
    // this, the mode 1 branch below exits before the picker input is read, so F9
    // would open a picker that ignores Enter.
    var _was_active = global.mod_cs_active;
    mode = 0;
    menu_open = false;
    menu_lock_key = true;
    global.mod_cs_active = false;
    global.mod_cs_pending = undefined;
    // The stock pause menu leaves global.story_paused set when it exits a story.
    global.story_paused = false;
    mod_cs_restore_globals();
    // A cutscene of this story must not survive the session either.
    mod_cs_movie_stop();
    // Leaving through the pause menu skips mod_cs_end(), so the HD state has to be
    // undone here too: obj_resolution_handler is persistent and would otherwise
    // keep rendering the main menu at the multiplier the episode switched on.
    mod_cs_release_episode();
    if (instance_exists(obj_storyportrait))
    {
        with (obj_storyportrait) instance_destroy();
    }
    if (textbox_exists())
    {
        text_clear();
        destroy_textbox();
    }

    // Safety net for the mid-story exit. The stock pause menu sends a cancelled
    // story to the node flowchart ("返回节点流程" -> scene_eventline); an episode was
    // entered from the main menu, so the player belongs there instead. The
    // codepatch in codepatches.json redirects it at the source - this only runs if
    // that patch ever stops matching (e.g. after a game update).
    if (_was_active && _room_now == scene_eventline)
    {
        room_goto(scene_mainmenu);
    }
}

if (mode == 1)
{
    // Playback is driven by the game's coroutine manager; there is nothing to
    // poll here. Leave the mode alone while the room transition is still running.
    exit;
}

// ---------------------------------------------------------------------------
// picker already open: it owns the keyboard until it is dismissed
// ---------------------------------------------------------------------------
if (menu_open)
{
    var _n = array_length(menu_items);
    var _confirm = global.menu_confirm;
    var _cancel = global.menu_cancel;
    if (is_undefined(_confirm) || _confirm == undefined) _confirm = 13;
    if (is_undefined(_cancel) || _cancel == undefined) _cancel = 27;

    // Input gate for confirm/cancel only.
    //
    // The picker is opened by the Shift+Enter hook, which polls Enter every frame,
    // and keyboard_check_pressed() stays true for the whole frame it fired in. The
    // key is also still physically down for the frames that follow. Without this
    // gate the picker would confirm the highlighted story the instant it appeared.
    // Scrolling deliberately stays available, so the gate never feels laggy.
    if (menu_lock_frames > 0) menu_lock_frames--;
    if (menu_lock_key)
    {
        var _held = keyboard_check(vk_enter) || keyboard_check(_confirm) || keyboard_check(vk_shift)
                 || keyboard_check(vk_lshift) || keyboard_check(vk_rshift) || keyboard_check(ord("Z"));
        if (!_held && menu_lock_frames <= 0)
        {
            menu_lock_key = false;
        }
    }

    if (keyboard_check_pressed(vk_down) && _n > 0)
    {
        menu_index = (menu_index >= (_n - 1)) ? 0 : (menu_index + 1);
        menu_error = "";
        play_se(sfx_songsel_cursor);
    }
    if (keyboard_check_pressed(vk_up) && _n > 0)
    {
        menu_index = (menu_index <= 0) ? (_n - 1) : (menu_index - 1);
        menu_error = "";
        play_se(sfx_songsel_cursor);
    }

    if (menu_lock_key)
    {
        // Drop whatever the opening keypress queued (the button's KeyPress events
        // set menu_activate_request on the same frame).
        menu_activate_request = 0;
        exit;
    }

    switch (menu_activate_request)
    {
        case 1:
            menu_activate_request = 0;
            menu_activate();
            exit;

        case 2:
            menu_activate_request = 0;
            menu_close_browser();
            exit;
    }

    if (keyboard_check_pressed(_confirm) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(ord("Z")))
    {
        menu_activate();
        exit;
    }
    if (keyboard_check_pressed(_cancel) || keyboard_check_pressed(vk_escape))
    {
        menu_close_browser();
        exit;
    }
    exit;
}

// ---------------------------------------------------------------------------
// picker closed: fall back to Shift+Enter while the flowchart button is the
// selected entry. The primary hook lives in o_newmainbutton_Step_0; this is a
// safety net in case that button object is missing from a menu variant.
// ---------------------------------------------------------------------------
// Safety net: whenever the picker is closed, make sure the stock menu
// elements we hide are visible again. Covers every exit path (ESC, story end,
// room change) so a hidden UI can never get stuck.
if (room == scene_mainmenu && !menu_open)
{
    menu_set_overlay_visible(true);
}

if (menu_lock_key)
{
    if (!keyboard_check(vk_shift)) menu_lock_key = false;
    exit;
}

if (room == scene_mainmenu && instance_exists(o_newmainbutton))
{
    var _on_flowchart = false;
    with (o_newmainbutton)
    {
        if (is_sel && icon_sprite == sp_icon_ch0story) _on_flowchart = true;
    }

    if (_on_flowchart)
    {
        var _cf = global.menu_confirm;
        if (is_undefined(_cf) || _cf == undefined) _cf = 13;
        if (keyboard_check(vk_shift) && (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(_cf)))
        {
            menu_open_browser();
        }
    }
}



