// o_newmainbutton -- Step event, overridden by the Custom Episodes Mod.
//
// Original body (kept verbatim at the bottom) only handles alpha_obfuscate.
// This override adds two things on top:
//
//   1. Lazy creation of the resident listener. The mod's global script is
//      supposed to spawn it at game start, but if that top-level code does not
//      run (global init registration is not guaranteed), nothing would exist.
//      This event runs every frame on the main menu, so it creates the object
//      as soon as the menu appears.
//   2. The Shift+Enter entry hook on the NODE FLOWCHART button.
//
// The button is identified by icon_sprite == sp_icon_ch0story, which is
// language independent (button_text differs between localisations).
//
// Existing code entry, so this is a full replacement: if a future game update
// changes the original body, this file must be refreshed from a fresh dump.

// ---------------------------------------------------------------------------
// lazy listener creation (independent of the mod's global script)
// ---------------------------------------------------------------------------
if (!instance_exists(o_mod_storyentry))
{
    instance_create_depth(0, 0, -999999, o_mod_storyentry);
}

// ---------------------------------------------------------------------------
// stock behaviour
// ---------------------------------------------------------------------------
// NOTE: global.mod_cs_key_consumed is deliberately NOT cleared here any more.
// o_newmenu_Step_0 consumes (and clears) it, which makes the block independent of
// the order in which the two events run this frame.

if (variable_instance_exists(self, "alpha_obfuscate"))
{
    switch (alpha_obfuscate)
    {
        case 1:
            obfuscate = global.alpha_story_progress == 3 || global.alpha_story_progress == 4;
            break;
        case 2:
            obfuscate = global.alpha_story_progress == 3;
            break;
    }
}

// ---------------------------------------------------------------------------
// episode entry hook
// ---------------------------------------------------------------------------
// Only the selected flowchart button reacts, so the hook cannot fire while the
// cursor sits on any other entry.
if (is_sel && icon_sprite == sp_icon_ch0story && !global.mod_cs_key_consumed)
{
    var _shift = keyboard_check(vk_shift) || keyboard_check(vk_lshift) || keyboard_check(vk_rshift);
    var _confirm = global.menu_confirm;
    if (is_undefined(_confirm) || _confirm == undefined) _confirm = 13;
    var _enter = keyboard_check_pressed(vk_enter)
              || keyboard_check_pressed(ord("Z"))
              || keyboard_check_pressed(_confirm);

    if (_shift && _enter)
    {
        // Claim this keypress so o_newmenu_Step_0 does not also open the stock
        // node flowchart on the same frame.
        global.mod_cs_key_consumed = true;
        if (instance_exists(o_mod_storyentry))
        {
            with (o_mod_storyentry)
            {
                menu_open_browser();
            }
        }
    }
}
