// o_newmainbutton -- Draw GUI event, overridden by the Custom Episodes Mod.
//
// The body below is the game's own implementation, copied verbatim, followed by
// one extra call that draws the episode picker.
//
// Reason for drawing the picker from here: a mod-created object's own Draw GUI
// event is never invoked by this game build (verified with a marker file while
// o_newmainbutton's Draw GUI did run), and a normal Draw event renders under the
// menu's GUI layer. Hooking this event is therefore the only place that both
// runs and sits above the menu.
//
// If a future game update changes the original body, refresh this file from a
// fresh dump and re-append the picker call at the end.
draw_set_alpha(image_alpha);
var selected = instance_exists(menu) ? (menu.hovered == i) : 0;
var _x = round(x);
var _y = round(y);
if (!selected)
{
    draw_set_color(c_white);
}
else
{
    draw_set_color(c_black);
}
if (selected)
{
    draw_sprite(sp_43button_sel, 0, _x, _y);
}
else
{
    draw_sprite(sp_43button_unsel, 0, _x, _y);
}
draw_set_halign(fa_center);
draw_set_font(global.default_font);
draw_text_o(_x + 75, _y + 9, button_text);
if (!obfuscate)
{
    draw_sprite(icon_sprite, 0, _x + 4, _y + 3);
    draw_sprite(icon_sprite, 1, _x + 128, _y + 3);
    if (!unlocked)
    {
        draw_set_alpha(0.5 * image_alpha);
        draw_sprite(sp_43button_disable, 0, _x, _y);
        draw_set_color(c_white);
        draw_set_alpha(image_alpha);
        draw_text_outlined(_x + 75, _y + 9 + 4, unlock_text, 16777215, 0);
    }
}
if (obfuscate)
{
    if (!surface_exists(o_newmenu_main.obfuscated_surface))
    {
        o_newmenu_main.obfuscated_surface = surface_create(sprite_get_width(sp_43button_glitch), sprite_get_height(sp_43button_glitch));
    }
    shader_set(shader_marenol_main);
    shader_set_uniform_f(uTime, ((current_time % 200000) / 1000) + (i * 10));
    shader_set_uniform_f(uSTime, i * 10);
    shader_set_uniform_f(uGlitchAmp, 0.6);
    shader_set_uniform_f(uMove, 0, 0);
    shader_set_uniform_f(uSinm, 0, 1, 0);
    shader_set_uniform_f(uCosm, 0, 1, 0);
    shader_set_uniform_f(uTanm, 0, 1, 0);
    shader_set_uniform_f(uFish, 0);
    var twists = [uTwist1, uTwist2, uTwist3, uTwist4];
    for (var k = 0; k < 4; k++)
    {
        shader_set_uniform_f(twists[k], 0, 0, 0, 0.4);
    }
    texture_set_stage(noisesampler, noisetex);
    surface_target(o_newmenu_main.obfuscated_surface);
    draw_sprite(sp_43button_glitch, current_time, 0, 0);
    surface_untarget();
    shader_reset();
    draw_surface(o_newmenu_main.obfuscated_surface, _x + 2, _y + 2);
    for (var j = 0; j < array_length(randstring); j++)
    {
        var bx = (75 - ((array_length(randstring) / 2) * 12)) + (j * 12) + 6;
        var by = 9;
        draw_text_outlined(_x + bx + randstringoffx[j], _y + by + randstringoffy[j] + 4, randstring[j], 16777215, 0);
    }
}
draw_set_alpha(1);

    with (o_mod_storyentry) { menu_draw_picker(); }




