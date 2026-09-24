// KeyPress(13) = Enter, added by the Custom Episodes Mod.
//
// RELIABLE input channel while the picker is open. keyboard_check_pressed() in a
// Draw event does not see the keypress, and o_newmenu_Step_0 consumes the confirm
// key first, so the picker would otherwise ignore Enter/ESC. KeyPress events on
// this button object are proven to fire (the entry hook uses one).
//
// When the picker is open this button is covered by it, so hijacking the
// keypress here cannot affect normal menu navigation.

if (instance_exists(o_mod_storyentry))
{
    with (o_mod_storyentry)
    {
        if (menu_open) menu_activate_request = 1;
    }
}
