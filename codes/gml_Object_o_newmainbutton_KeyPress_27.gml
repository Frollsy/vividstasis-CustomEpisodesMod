// KeyPress(27) = ESC, added by the Custom Episodes Mod. See KeyPress_13 for why the
// picker is driven from KeyPress events instead of Draw/Step keyboard polling.

if (instance_exists(o_mod_storyentry))
{
    with (o_mod_storyentry)
    {
        if (menu_open) menu_activate_request = 2;
    }
}
