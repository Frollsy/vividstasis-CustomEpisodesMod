// o_mod_storyentry -- KeyPress(120) = F9.
//
// Debug shortcut: opens the picker directly, bypassing the entry conditions.
// Useful for testing without the Shift+Enter combination.

// The picker is only usable in mode 0: mode 1 (story playback) owns the keyboard
// and its Step branch returns before the picker input is read. F9 is a debug key,
// so it also forces the mode back and is limited to the main menu.
if (instance_exists(o_mod_storyentry))
{
    with (o_mod_storyentry)
    {
        if (room == scene_mainmenu && !menu_open)
        {
            mode = 0;
            menu_activate_request = 0;
            menu_open_browser();
        }
    }
}
