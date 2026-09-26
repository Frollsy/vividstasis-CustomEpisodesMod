// o_mod_storyentry -- Create event.
//
// NOTE: everything that used to live in gml_GlobalScript_mod_customstory.gml is
// merged in here. A new gml_GlobalScript_ code entry does NOT get its top-level
// code executed at startup on this VML build (verified: the object ran while the
// global helper functions were still undefined), so the mod must not depend on
// global-init execution. All helpers below are instance methods of this object.
global.mod_cs_dir     = "Custom Episodes/";   // relative to the game directory
global.mod_cs_active  = false;             // is a custom episode playing right now
global.mod_cs_pending = undefined;         // story folder waiting to be loaded
global.mod_cs_saved_load_scene = undefined;
global.mod_cs_saved_episode = "";

// Create the resident listener. It is persistent, so it survives game_restart;
// check first so a restart cannot stack up duplicates.
// (listener creation moved to the button Step lazy-create)

/// Trim whitespace and line breaks (file_text_read_string keeps a trailing CR).
function mod_cs_trim(_str)
{
    var _s = string_replace_all(_str, chr(13), "");
    _s = string_replace_all(_s, chr(10), "");
    _s = string_replace_all(_s, chr(9), " ");
    while (string_length(_s) > 0 && string_char_at(_s, 1) == " ")
    {
        _s = string_delete(_s, 1, 1);
    }
    while (string_length(_s) > 0 && string_char_at(_s, string_length(_s)) == " ")
    {
        _s = string_delete(_s, string_length(_s), 1);
    }
    return _s;
}

/// Safe string conversion: JSON values may be numbers, booleans or undefined.
function mod_cs_str(_v)
{
    if (is_undefined(_v) || _v == undefined) return "";
    return string(_v);
}

/// Safe integer conversion with a fallback for non-numeric input.
function mod_cs_int(_v, _fallback)
{
    if (is_undefined(_v) || _v == undefined) return _fallback;
    var _r = real(_v);
    if (is_string(_v) && _r == 0 && _v != "0") return _fallback;
    if (is_real(_v)) return _r;
    return _fallback;
}

/// Scan every subfolder of Custom Episodes/ and return a name-sorted list.
/// Each entry: { folder, title, file, ok }
function mod_cs_load_list()
{
    var _out = [];
    if (!directory_exists(global.mod_cs_dir)) return _out;

    // GameMaker has no directory-listing function, and file_find_first with an
    // attribute filter of 0 returns FILES ONLY. 16 is the Win32
    // FILE_ATTRIBUTE_DIRECTORY value, used instead of a named constant.
    var _dirs = [];
    var _entry = file_find_first(global.mod_cs_dir + "*", 16);
    while (_entry != "")
    {
        if (directory_exists(global.mod_cs_dir + _entry))
        {
            array_push(_dirs, _entry);
        }
        _entry = file_find_next();
    }
    file_find_close();

    // Fallback if the attribute filter yields nothing.
    if (array_length(_dirs) <= 0)
    {
        _entry = file_find_first(global.mod_cs_dir + "*", 0);
        while (_entry != "")
        {
            if (directory_exists(global.mod_cs_dir + _entry))
            {
                array_push(_dirs, _entry);
            }
            _entry = file_find_next();
        }
        file_find_close();
    }

    for (var _i = 0; _i < array_length(_dirs); _i++)
    {
        var _d = mod_cs_trim(_dirs[_i]);
        if (_d == "" || _d == "." || _d == "..") continue;

        var _item =
        {
            folder: _d,
            title: _d,
            file: global.mod_cs_dir + _d + "/story.json",
            author: "",
            desc: "",
            count: 0,
            note: "",
            ok: false
        };

        if (!file_exists(_item.file))
        {
            // Listed anyway, greyed out: a folder without story.json is a much
            // clearer hint than silently dropping it from the picker.
            _item.note = "no story.json";
            array_push(_out, _item);
            continue;
        }

        var _f = file_text_open_read(_item.file);
        var _raw = "";
        while (!file_text_eof(_f))
        {
            _raw += file_text_read_string(_f);
            _raw += chr(10);
            file_text_readln(_f);
        }
        file_text_close(_f);

        var _data = undefined;
        try
        {
            _data = json_parse(_raw);
        }
        catch (_e)
        {
            _data = undefined;
        }

        if (!is_struct(_data))
        {
            _item.note = "story.json parse error";
            array_push(_out, _item);
            continue;
        }

        if (variable_struct_exists(_data, "title"))
        {
            var _t = mod_cs_str(_data.title);
            if (_t != "") _item.title = _t;
        }
        if (variable_struct_exists(_data, "author")) _item.author = mod_cs_str(_data.author);
        if (variable_struct_exists(_data, "description")) _item.desc = mod_cs_str(_data.description);
        if (variable_struct_exists(_data, "lines") && is_array(_data.lines)) _item.count = array_length(_data.lines);
        _item.data = _data;
        _item.ok = true;
        array_push(_out, _item);
    }

    // Sorted by folder name. NOTE: string_compare() does not exist in this build
    // (0 uses anywhere in the game code) - it resolved as an instance variable and
    // crashed the picker as soon as a second episode existed. The game itself
    // sorts with plain string operators, so do the same.
    array_sort(_out, function(_a, _b)
    {
        var _x = string_lower(mod_cs_str(_a.folder));
        var _y = string_lower(mod_cs_str(_b.folder));
        if (_x > _y) return 1;
        if (_x < _y) return -1;
        return 0;
    });

    return _out;
}

/// Show a mod message through the game's own textbox, so it follows the
/// player's font and language settings.
function mod_cs_say_error(_msg)
{
    create_textbox();
    name_set("custom episode");
    text(_msg);
}

/// Clips a text to at most _max_lines lines that fit into _width pixels.
///
/// Needed by the picker: the vanilla draw_text_ext(text, sep, w) only ever breaks
/// a line at a space, so a Chinese description has no break point at all and runs
/// off the panel. The text is wrapped with the same CJK-aware wrapper the dialogue
/// uses, then cut to the available height with an ellipsis.
function menu_clip_text(_txt, _width, _max_lines)
{
    var _s = mod_cs_str(_txt);
    if (_s == "" || _max_lines <= 0) return "";

    var _lines = string_split(mod_cs_wrap_text(_s, _width), chr(10));
    if (array_length(_lines) <= _max_lines)
    {
        var _same = "";
        for (var _j = 0; _j < array_length(_lines); _j++)
        {
            if (_j > 0) _same += chr(10);
            _same += _lines[_j];
        }
        return _same;
    }

    // Keep the first lines whole, then fill the last one up to the width.
    var _out = "";
    var _lastIdx = _max_lines - 1;
    for (var _i = 0; _i < _lastIdx; _i++) _out += _lines[_i] + chr(10);

    var _src = _lines[_lastIdx];
    var _keep = "";
    for (var _c = 1; _c <= string_length(_src); _c++)
    {
        var _cand = _keep + string_char_at(_src, _c);
        if (string_width(_cand + "...") > _width) break;
        _keep = _cand;
    }
    return _out + _keep + "...";
}

/// Puts the room resolution, the high-res background flag and the HUD back to
/// vanilla.
///
/// set_resolution_multiplier() resizes the application surface (320x180 * n), so
/// the room - and every room after it - renders at that scale. obj_resolution_handler
/// is persistent, so a multiplier left behind would also blow up the main menu.
/// Called from mod_cs_end(), from the failed-start path and from the room-change
/// reset in the Step event.
function mod_cs_reset_resolution()
{
    if (instance_exists(obj_resolution_handler)) reset_resolution();
    if (instance_exists(o_bg)) o_bg.highres = false;
    if (instance_exists(o_cutsceneConductor)) o_cutsceneConductor.hideGui = false;
}

/// True when a JSON sprite reference points at an image file instead of a game
/// asset. Extension based on purpose: an author can mix game assets and own files
/// in the same field without any extra flag.
function mod_cs_is_image_name(_name)
{
    var _n = string_lower(mod_cs_str(_name));
    var _len = string_length(_n);
    if (_len <= 4) return false;
    if (string_copy(_n, _len - 3, 4) == ".png") return true;
    if (string_copy(_n, _len - 3, 4) == ".jpg") return true;
    if (string_copy(_n, _len - 3, 4) == ".gif") return true;
    if (_len > 5 && string_copy(_n, _len - 4, 5) == ".jpeg") return true;
    return false;
}

/// Path of an external image, relative to the game directory: the image lives in
/// the episode folder, either next to story.json or in a subfolder of it.
function mod_cs_image_file(_name)
{
    return global.mod_cs_dir + global.mod_cs_folder + "/" + mod_cs_str(_name);
}

/// Loads an external image once and caches the resulting sprite.
///
/// _origin: 0 = top-left (full screen art), 1 = bottom-centre (portraits, which the
/// vanilla scripts position by their base line, x/y = 70..280 / 140..160).
/// Returns -1 when the file is missing or cannot be decoded - sprite_add is wrapped
/// in try/catch because a build that does not know the function would otherwise
/// take the game down. Failures are also cached, so a broken reference only costs
/// one attempt.
function mod_cs_load_image(_name, _origin)
{
    if (!variable_global_exists("mod_cs_images")) global.mod_cs_images = {};
    var _file = mod_cs_image_file(_name);
    var _key = _file + "#" + string(_origin);
    if (variable_struct_exists(global.mod_cs_images, _key))
    {
        return variable_struct_get(global.mod_cs_images, _key);
    }

    var _spr = -1;
    if (file_exists(_file))
    {
        try
        {
            _spr = sprite_add(_file, 1, false, false, 0, 0);
        }
        catch (_ex)
        {
            _spr = -1;
        }
        if (_spr >= 0)
        {
            if (_origin == 1)
            {
                sprite_set_offset(_spr, sprite_get_width(_spr) / 2, sprite_get_height(_spr));
            }
            sprite_prefetch(_spr);
        }
    }

    variable_struct_set(global.mod_cs_images, _key, _spr);
    if (_spr < 0 && !variable_struct_exists(global.mod_cs_image_missing_map, _file))
    {
        variable_struct_set(global.mod_cs_image_missing_map, _file, true);
        if (global.mod_cs_image_missing != "") global.mod_cs_image_missing += ", ";
        global.mod_cs_image_missing += mod_cs_str(_name);
    }
    if (_spr >= 0)
    {
        if (global.mod_cs_image_sizes != "") global.mod_cs_image_sizes += ", ";
        global.mod_cs_image_sizes += mod_cs_str(_name) + " " + string(sprite_get_width(_spr)) + "x" + string(sprite_get_height(_spr));
    }
    return _spr;
}

/// Resolves a background / CG reference: external image file, or game asset name.
function mod_cs_sprite(_name)
{
    if (mod_cs_is_image_name(_name)) return mod_cs_load_image(_name, 0);
    return asset_get_index(mod_cs_str(_name));
}

/// Same, for portraits (bottom-centre origin).
function mod_cs_portrait_sprite(_name)
{
    if (mod_cs_is_image_name(_name)) return mod_cs_load_image(_name, 1);
    return asset_get_index(mod_cs_str(_name));
}

/// True when a JSON sound reference points at an external OGG file.
///
/// Only OGG: audio_create_stream() is documented to accept OGG exclusively, so
/// accepting .wav/.mp3 here would only produce a "not found" at runtime.
function mod_cs_is_audio_name(_name)
{
    var _n = string_lower(mod_cs_str(_name));
    var _len = string_length(_n);
    if (_len <= 4) return false;
    return (string_copy(_n, _len - 3, 4) == ".ogg");
}

/// Path of an external audio file, relative to the game directory (next to
/// story.json or in a subfolder of the episode).
///
/// An in-chart story lives next to the chart instead, so its audio is resolved
/// against the chart folder (see mod_cs_chart_folder).
function mod_cs_audio_file(_name)
{
    if (variable_global_exists("mod_cs_chart_active") && global.mod_cs_chart_active
        && variable_global_exists("mod_cs_chart_folder") && global.mod_cs_chart_folder != "")
    {
        return global.mod_cs_chart_folder + mod_cs_str(_name);
    }
    return global.mod_cs_dir + global.mod_cs_folder + "/" + mod_cs_str(_name);
}

/// Creates a streamed sound for an external OGG file, once.
///
/// Every stream must be destroyed again with audio_destroy_stream() or it leaks
/// (the manual is explicit about that), so the result is cached per file and freed
/// on the same exits as the external images. Failures are cached too, and recorded
/// for the report in the first dialogue line.
function mod_cs_load_audio(_name)
{
    if (!variable_global_exists("mod_cs_streams")) global.mod_cs_streams = {};
    var _file = mod_cs_audio_file(_name);
    if (variable_struct_exists(global.mod_cs_streams, _file))
    {
        return variable_struct_get(global.mod_cs_streams, _file);
    }

    var _snd = -1;
    if (file_exists(_file))
    {
        try
        {
            _snd = audio_create_stream(_file);
        }
        catch (_ex)
        {
            _snd = -1;
        }
    }
    variable_struct_set(global.mod_cs_streams, _file, _snd);

    if (_snd < 0)
    {
        if (global.mod_cs_audio_missing != "") global.mod_cs_audio_missing += ", ";
        global.mod_cs_audio_missing += mod_cs_str(_name);
    }
    else
    {
        var _secs = 0;
        try
        {
            _secs = audio_sound_length(_snd);
        }
        catch (_ex)
        {
            _secs = 0;
        }
        if (global.mod_cs_audio_sizes != "") global.mod_cs_audio_sizes += ", ";
        global.mod_cs_audio_sizes += mod_cs_str(_name) + " " + string(round(_secs * 10) / 10) + "s";
    }
    return _snd;
}

/// True for an audio file extension that this build cannot stream. Reported to the
/// author instead of silently resolving to nothing.
function mod_cs_is_unsupported_audio(_name)
{
    var _n = string_lower(mod_cs_str(_name));
    var _len = string_length(_n);
    if (_len <= 4) return false;
    var _ext = string_copy(_n, _len - 3, 4);
    if (_ext == ".wav") return true;
    if (_ext == ".mp3") return true;
    if (_ext == ".m4a") return true;
    if (_len > 5 && string_copy(_n, _len - 4, 5) == ".flac") return true;
    return false;
}

/// Resolves a sound reference: external OGG file, or game asset name.
function mod_cs_sound(_name)
{
    if (mod_cs_is_audio_name(_name)) return mod_cs_load_audio(_name);
    if (mod_cs_is_unsupported_audio(_name))
    {
        if (global.mod_cs_audio_missing != "") global.mod_cs_audio_missing += ", ";
        global.mod_cs_audio_missing += mod_cs_str(_name) + " (only .ogg works)";
        return -1;
    }
    return asset_get_index(mod_cs_str(_name));
}

/// Stops and destroys every streamed sound of the current episode.
///
/// The sounds are stopped first (only the ones we created - the main menu starts
/// its own BGM after we are done) because destroying a playing stream is asking
/// for trouble.
function mod_cs_free_audio()
{
    mod_cs_log("free_audio: start");
    if (!variable_global_exists("mod_cs_streams")) return;
    if (!is_struct(global.mod_cs_streams))
    {
        global.mod_cs_streams = {};
        return;
    }

    var _keys = variable_struct_get_names(global.mod_cs_streams);
    var _n = array_length(_keys);
    var _freed = 0;
    for (var _i = _n - 1; _i >= 0; _i--)
    {
        var _snd = variable_struct_get(global.mod_cs_streams, _keys[_i]);
        if (_snd == undefined || _snd < 0) continue;
        var _ok = false;
        try
        {
            if (audio_is_playing(_snd)) audio_stop_sound(_snd);
            audio_destroy_stream(_snd);
            _ok = true;
        }
        catch (_ex)
        {
            _ok = false;
        }
        if (_ok) _freed++;
        else mod_cs_log("free_audio: failed: " + _keys[_i]);
    }
    mod_cs_log("free_audio: freed " + string(_freed) + " of " + string(_n));

    global.mod_cs_streams = {};
    global.mod_cs_audio_missing = "";
    global.mod_cs_audio_sizes = "";
    mod_cs_log("free_audio: done");
}

/// Appends one line to "Custom Episodes/_modlog.txt" when the episode turned on
/// "debuglog": true. Only for diagnosing an exit path; nothing else is written.
function mod_cs_log(_msg)
{
    if (!variable_global_exists("mod_cs_debug_log")) return;
    if (!global.mod_cs_debug_log) return;
    var _f = -1;
    try
    {
        _f = file_text_open_append(global.mod_cs_dir + "_modlog.txt");
    }
    catch (_ex)
    {
        return;
    }
    if (_f == -1) return;
    file_text_write_string(_f, string(current_time) + "  " + string(_msg));
    file_text_writeln(_f);
    file_text_close(_f);
}

/// True when _spr is one of the sprites loaded from an external image file.
function mod_cs_is_loaded_sprite(_spr)
{
    if (_spr == undefined || _spr < 0) return false;
    if (!variable_global_exists("mod_cs_images")) return false;
    if (!is_struct(global.mod_cs_images)) return false;
    var _keys = variable_struct_get_names(global.mod_cs_images);
    for (var _i = 0; _i < array_length(_keys); _i++)
    {
        if (variable_struct_get(global.mod_cs_images, _keys[_i]) == _spr) return true;
    }
    return false;
}

/// Frees every external image loaded for the current episode.
///
/// Two extra rules keep this safe even on an early exit:
///  1. detach first - an instance that still points at one of these sprites
///     (o_bg keeps the external image until the room actually changes) would
///     otherwise be drawn from freed memory;
///  2. delete from the highest index downwards, in case sprite_delete renumbers
///     the remaining dynamic sprites.
function mod_cs_free_images()
{
    mod_cs_log("free_images: start");
    if (!variable_global_exists("mod_cs_images")) return;
    if (!is_struct(global.mod_cs_images))
    {
        global.mod_cs_images = {};
        return;
    }

    var _keys = variable_struct_get_names(global.mod_cs_images);
    var _n = array_length(_keys);
    if (_n > 0)
    {
        if (instance_exists(o_bg) && mod_cs_is_loaded_sprite(o_bg.sprite_index))
        {
            o_bg.sprite_index = -1;
            o_bg.highres = false;
            mod_cs_log("free_images: detached o_bg");
        }
        if (instance_exists(obj_storyportrait))
        {
            with (obj_storyportrait)
            {
                if (mod_cs_is_loaded_sprite(portrait)) instance_destroy();
            }
        }

        var _deleted = 0;
        for (var _i = _n - 1; _i >= 0; _i--)
        {
            var _spr = variable_struct_get(global.mod_cs_images, _keys[_i]);
            if (_spr == undefined || _spr < 0) continue;
            if (!sprite_exists(_spr)) continue;
            var _ok = false;
            try
            {
                sprite_delete(_spr);
                _ok = true;
            }
            catch (_ex)
            {
                _ok = false;
            }
            if (_ok) _deleted++;
            else mod_cs_log("free_images: sprite_delete failed: " + _keys[_i]);
        }
        mod_cs_log("free_images: deleted " + string(_deleted) + " of " + string(_n));
    }

    global.mod_cs_images = {};
    global.mod_cs_image_missing_map = {};
    global.mod_cs_image_missing = "";
    global.mod_cs_image_sizes = "";
    mod_cs_log("free_images: done");
}

/// Everything that has to be undone when an episode stops running, used on the
/// exits that are already safe (back on the main menu, or nothing on screen points
/// at the images). The story-room exits call mod_cs_reset_resolution() and set the
/// pending flag instead, because freeing there happens before the room has
/// finished drawing.
///
/// NOTE: this used to call itself here - a bulk edit replaced the
/// mod_cs_reset_resolution() call inside this very function. Unconditional
/// self-recursion is what froze the game on "end".
function mod_cs_release_episode()
{
    mod_cs_reset_resolution();
    mod_cs_free_images();
    mod_cs_free_audio();
}

/// Resolves the sprite name for a portrait step.
///
/// Order: an explicit "portrait" field, then an "expression" alias, then the
/// character's default portrait. An alias may either be a full asset / file name
/// (it contains "_" or a dot) or a short word, which is resolved through the
/// character's optional "expressions" map and, failing that, by replacing the
/// suffix of the default portrait: default "sat_neutral" + "happy" -> "sat_happy".
function mod_cs_expression_name(_c, _e)
{
    if (is_struct(_e) && variable_struct_exists(_e, "portrait"))
    {
        var _direct = mod_cs_str(_e.portrait);
        if (_direct != "") return _direct;
    }

    if (is_struct(_e) && variable_struct_exists(_e, "expression"))
    {
        var _alias = mod_cs_str(_e.expression);
        if (_alias != "")
        {
            // Full asset name or image file: use it as written.
            if (string_pos("_", _alias) > 0 || string_pos(".", _alias) > 0) return _alias;

            if (variable_struct_exists(_c, "expressions"))
            {
                var _map = variable_struct_get(_c, "expressions");
                if (is_struct(_map) && variable_struct_exists(_map, _alias))
                {
                    return mod_cs_str(variable_struct_get(_map, _alias));
                }
            }

            if (variable_struct_exists(_c, "portrait"))
            {
                var _def = mod_cs_str(_c.portrait);
                var _us = string_pos("_", _def);
                if (_us > 0) return string_copy(_def, 1, _us) + _alias;
            }
            return "";
        }
    }

    if (variable_struct_exists(_c, "portrait")) return mod_cs_str(_c.portrait);
    return "";
}

/// The live portrait instance of character key _who, or noone.
function mod_cs_portrait_of(_who){
    if (!variable_global_exists("mod_cs_portraits")) return noone;
    var _map = global.mod_cs_portraits;
    if (!is_struct(_map)) return noone;
    if (!variable_struct_exists(_map, _who)) return noone;
    var _inst = variable_struct_get(_map, _who);
    if (_inst == undefined || _inst == noone) return noone;
    if (!instance_exists(_inst)) return noone;
    return _inst;
}

/// Removes every portrait this mod created (the vanilla scripts call
/// instance_destroy(obj_storyportrait) for the same effect).
function mod_cs_portrait_clear()
{
    if (!variable_global_exists("mod_cs_portraits")) return;
    var _map = global.mod_cs_portraits;
    if (!is_struct(_map)) return;
    var _keys = variable_struct_get_names(_map);
    for (var _i = 0; _i < array_length(_keys); _i++)
    {
        var _inst = variable_struct_get(_map, _keys[_i]);
        if (_inst != undefined && _inst != noone && instance_exists(_inst)) instance_destroy(_inst);
    }
    global.mod_cs_portraits = {};
}

/// Loads every external image and OGG the episode references, so a big file cannot
/// cause a hitch in the middle of a scene. Missing files are collected in
/// global.mod_cs_image_missing / global.mod_cs_audio_missing and reported in the
/// first dialogue line.
function mod_cs_preload_assets()
{
    if (global.mod_cs_bg != "" && mod_cs_is_image_name(global.mod_cs_bg))
    {
        mod_cs_load_image(global.mod_cs_bg, 0);
    }
    if (global.mod_cs_bgm != "" && mod_cs_is_audio_name(global.mod_cs_bgm))
    {
        mod_cs_load_audio(global.mod_cs_bgm);
    }

    var _lines = global.mod_cs_lines;
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        var _e = _lines[_i];
        if (!is_struct(_e)) continue;
        if (variable_struct_exists(_e, "value"))
        {
            // Only backgrounds / CGs use "value" for a picture and only bgm / se
            // use it for a sound; the extensions tell them apart.
            if (mod_cs_is_image_name(_e.value)) mod_cs_load_image(_e.value, 0);
            else if (mod_cs_is_audio_name(_e.value)) mod_cs_load_audio(_e.value);
            else if (mod_cs_is_unsupported_audio(_e.value)) mod_cs_sound(_e.value);
        }
        if (variable_struct_exists(_e, "portrait") && mod_cs_is_image_name(_e.portrait))
        {
            mod_cs_load_image(_e.portrait, 1);
        }
        // "change" / "expression" steps can reach an image through an alias too.
        if (variable_struct_exists(_e, "who") && variable_struct_exists(_e, "expression"))
        {
            var _wkey = mod_cs_str(_e.who);
            if (variable_struct_exists(global.mod_cs_chars, _wkey))
            {
                var _alias_name = mod_cs_expression_name(variable_struct_get(global.mod_cs_chars, _wkey), _e);
                if (_alias_name != "" && mod_cs_is_image_name(_alias_name))
                {
                    mod_cs_load_image(_alias_name, 1);
                }
            }
        }
    }

    var _chars = global.mod_cs_chars;
    if (is_struct(_chars))
    {
        var _keys = variable_struct_get_names(_chars);
        for (var _k = 0; _k < array_length(_keys); _k++)
        {
            var _c = variable_struct_get(_chars, _keys[_k]);
            if (is_struct(_c) && variable_struct_exists(_c, "portrait") && mod_cs_is_image_name(_c.portrait))
            {
                mod_cs_load_image(_c.portrait, 1);
            }
        }
    }
}

/// Characters that must not begin a line (basic CJK line-breaking rules).
function mod_cs_no_line_start(_ch)
{
    switch (_ch)
    {
        case "，": case "。": case "、": case "！": case "？": case "；": case "：":
        case "）": case "》": case "」": case "』": case "】": case "〉": case "…":
        case "—": case "·": case "～": case "”": case "’":
        case ",":  case ".":  case "!":  case "?":  case ";":  case ":":
        case ")":  case "]":  case "}":  case "%":
            return true;
    }
    return false;
}

/// Soft-wrap _txt so it fits into _width pixels.
///
/// The vanilla engine only ever breaks a line at a space (TextDrawer.parse(), the
/// " " case), which is why the official localisation inserts stray spaces into
/// Chinese sentences. This function builds the breaks itself and inserts "\n",
/// which the same parser turns into a real line break (its "\n" case), so Chinese
/// text wraps without any manual spaces.
///
/// Vanilla inline codes (`c{color}, `e{effect}, `r, ``) are copied over verbatim
/// and never split across lines. Breaks prefer the last space so Latin words stay
/// whole, and closing punctuation is never pushed to the start of a line.
///
/// The current font decides the widths, so the vanilla dialogue font is selected
/// while measuring. It is deliberately left selected afterwards: it is the same
/// font every stock draw call restores, and every other draw sets its own.
function mod_cs_wrap_text(_txt, _width)
{
    if (is_undefined(_txt) || _txt == undefined) return "";
    var _s = string(_txt);
    if (_width <= 0 || string_length(_s) <= 0) return _s;

    if (variable_global_exists("default_font")) draw_set_font(global.default_font);

    var _n = string_length(_s);
    var _out = "";
    var _line = "";
    var _i = 1;

    while (_i <= _n)
    {
        var _ch = string_char_at(_s, _i);

        // explicit line break, written as \n (or \r\n) in the JSON
        if (_ch == "\n" || _ch == "\r")
        {
            _out += _line + "\n";
            _line = "";
            _i++;
            if (_ch == "\r" && _i <= _n && string_char_at(_s, _i) == "\n") _i++;
            continue;
        }

        // vanilla inline code: copy the whole sequence untouched
        if (_ch == "`")
        {
            var _seq = _ch;
            var _j = _i + 1;
            if (_j <= _n)
            {
                var _flag = string_char_at(_s, _j);
                _seq += _flag;
                _j++;
                if (_flag != "`" && _j <= _n && string_char_at(_s, _j) == "{")
                {
                    while (_j <= _n)
                    {
                        var _c2 = string_char_at(_s, _j);
                        _seq += _c2;
                        _j++;
                        if (_c2 == "}") break;
                    }
                }
            }
            _line += _seq;
            _i = _j;
            continue;
        }

        var _cand = _line + _ch;
        if (string_length(_line) > 0 && string_width(_cand) > _width)
        {
            // Closing punctuation stays on the previous line even if that line
            // ends up slightly too wide.
            if (mod_cs_no_line_start(_ch))
            {
                _line = _cand;
                _i++;
                continue;
            }

            // Prefer the last space, but only when it is close to the edge: a
            // break far to the left would leave an obviously short line.
            var _sp = 0;
            for (var _k = string_length(_line); _k >= 1; _k--)
            {
                if (string_char_at(_line, _k) == " ")
                {
                    _sp = _k;
                    break;
                }
            }

            if (_sp > 0 && _sp > (string_length(_line) - 16))
            {
                _out += string_copy(_line, 1, _sp - 1) + "\n";
                _line = string_copy(_line, _sp + 1, string_length(_line) - _sp) + _ch;
            }
            else
            {
                _out += _line + "\n";
                _line = _ch;
            }
            _i++;
            continue;
        }

        _line = _cand;
        _i++;
    }

    _out += _line;
    return _out;
}

/// Restore the globals captured before entering a custom episode, so the stock
/// flow cannot be polluted.
function mod_cs_restore_globals()
{
    if (!variable_global_exists("mod_cs_owns_load_scene")) global.mod_cs_owns_load_scene = false;

    // Only write these back when they existed on entry; creating a global that
    // never existed would change stock behaviour. Every read is guarded: an
    // undefined global throws on read in this build.
    if (global.mod_cs_owns_load_scene && variable_global_exists("load_scene"))
    {
        if (variable_global_exists("mod_cs_saved_load_scene") && !is_undefined(global.mod_cs_saved_load_scene))
        {
            global.load_scene = global.mod_cs_saved_load_scene;
        }
        global.mod_cs_owns_load_scene = false;
    }
    if (variable_global_exists("mod_cs_saved_episode") && !is_undefined(global.mod_cs_saved_episode) && variable_global_exists("last_episode_name"))
    {
        global.last_episode_name = global.mod_cs_saved_episode;
    }
}

/// End the custom episode and return to the main menu.
function mod_cs_end()
{
    global.mod_cs_active = false;
    global.mod_cs_pending = undefined;
    // Tell the resident object to reset the picker once we are back on the menu
    // (the list has to be rescanned).
    mod_cs_restore_globals();
    // A cutscene of this story must not survive it.
    mod_cs_movie_stop();

    if (instance_exists(obj_storyportrait))
    {
        with (obj_storyportrait) instance_destroy();
    }
    // Undo any HD scene the episode switched on before leaving the room. This one
    // is safe here: it only touches the resolution handler and o_bg flags, and it
    // is what the vanilla story scripts do at the end of a CG scene.
    mod_cs_reset_resolution();
    mod_cs_log("end: reset_resolution done, image release deferred");
    // The external images are NOT freed here. mod_cs_end() runs inside the story
    // room while the current frame still draws o_bg with the external sprite; the
    // Step event finishes the release on the next tick, after the room changed.
    global.mod_cs_release_pending = true;
    text_clear();
    destroy_textbox();
    audio_stop_all();
    room_goto(scene_mainmenu);
}

// ---------------------------------------------------------------------------
// Video cutscenes (step kind "video")
//
// The game ships a generic video player, so a cutscene is mostly path work plus
// waiting: o_movie_player opens the file (video_open), draws the current frame in
// its Draw event (video_draw) and closes it when the async "video_end" arrives
// (finished = true). Vanilla cutscenes use the very same object, see
// ss_c1_e3_2.gml:580. Our step waits for checkFinished().
//
// Playback goes through the OS Media Foundation decoder: mp4 with h.264 video and
// AAC audio is what the game itself ships.
// ---------------------------------------------------------------------------

/// Game directory relative path of a video file of the current story.
///
/// Same rule as external audio: relative to story.json (the episode folder, or
/// the chart folder for an in-chart story). A leading "/" means "from the game
/// directory", so an episode can also reuse the game's own movies, e.g.
/// "/MOVIE/C1B_PY_LOOP.mp4".
function mod_cs_video_file(_name)
{
    var _n = mod_cs_str(_name);
    if (_n == "") return "";
    if (string_copy(_n, 1, 1) == "/") return string_delete(_n, 1, 1);
    if (variable_global_exists("mod_cs_chart_active") && global.mod_cs_chart_active
        && variable_global_exists("mod_cs_chart_folder") && global.mod_cs_chart_folder != "")
    {
        return global.mod_cs_chart_folder + _n;
    }
    return global.mod_cs_dir + global.mod_cs_folder + "/" + _n;
}

/// The path o_movie_player expects: it prepends working_directory itself.
function mod_cs_video_movie_path(_name)
{
    var _rel = mod_cs_video_file(_name);
    if (_rel == "") return "";
    return "/" + _rel;
}

/// Initial vid_scale of a cutscene: the "scale" field of the step, or 0.5 - the
/// size of the cutscenes the game itself ships (640x360). The real size is only
/// known once the video decodes, so mod_cs_movie_measure() corrects this from the
/// decoded surface on the first drawn frame (see the Draw GUI event).
function mod_cs_video_scale(_e)
{
    if (variable_struct_exists(_e, "scale"))
    {
        var _s = real(_e.scale);
        if (_s > 0) return _s;
    }
    return 0.5;
}

/// Volume of a cutscene: the game's music volume by default (what the vanilla
/// movie players use), or an explicit 0..1 written in the step.
function mod_cs_video_volume(_e)
{
    var _v = 1;
    if (variable_global_exists("op_music_volume")) _v = global.op_music_volume;
    if (variable_struct_exists(_e, "volume")) _v = real(_e.volume);
    return max(0, min(1, _v));
}

/// Resting y of the dialogue box: 122 in a story room, 132 inside a chart
/// (the values the vanilla in-chart stories and create_textbox() use).
function mod_cs_movie_box_y()
{
    if (variable_global_exists("mod_cs_chart_active") && global.mod_cs_chart_active) return 132;
    return 122;
}

/// Slides the dialogue box off the screen while a cutscene plays - the box is
/// drawn in the GUI layer, i.e. above the video - and back afterwards.
///
/// No locals are used inside the "with" blocks on purpose: a with() makes every
/// bare identifier resolve on the box instance (see README, pitfall 9b).
function mod_cs_movie_box_away(_away)
{
    if (!instance_exists(o_textbox)) return;
    if (_away)
    {
        with (o_textbox) TweenEasyMove(0, y, 0, 180, 0, mod_cs_chart_frames(0.6), EaseOutExpo);
    }
    else if (mod_cs_movie_box_y() == 132)
    {
        with (o_textbox) TweenEasyMove(0, y, 0, 132, 0, mod_cs_chart_frames(0.6), EaseOutExpo);
    }
    else
    {
        with (o_textbox) TweenEasyMove(0, y, 0, 122, 0, mod_cs_chart_frames(0.6), EaseOutExpo);
    }
}

/// Starts the cutscene of a "video" step. Returns the instance, or noone when the
/// file is missing (the caller then reports it).
function mod_cs_video_play(_e)
{
    if (!variable_struct_exists(_e, "value")) return noone;
    var _file = mod_cs_video_file(_e.value);
    if (_file == "" || !file_exists(_file)) return noone;

    // Nothing should show through the cutscene: leftover dialogue is dropped and
    // the box itself slides off the screen (it is drawn above the video).
    text_clear();
    mod_cs_movie_box_away(true);
    // The scale is measured from the decoded surface on the first drawn frame.
    global.mod_cs_movie_measured = false;
    global.mod_cs_movie_started = false;
    global.mod_cs_movie_file = _file;
    var _scale = mod_cs_video_scale(_e);
    mod_cs_video_log("play " + _file + " scale " + string(_scale));
    return instance_create_depth(0, 0, -999, o_movie_player, {
        movie_path: mod_cs_video_movie_path(_e.value),
        volume: mod_cs_video_volume(_e),
        vid_scale: _scale
    });
}

/// True when the player pressed the key that confirms dialogue; used to skip a
/// cutscene (the vanilla ones can be skipped as well).
function mod_cs_skip_pressed()
{
    var _pressed = false;
    try
    {
        _pressed = input_check_pressed(4);
    }
    catch (_ex)
    {
        _pressed = false;
    }
    if (_pressed) return true;
    if (variable_global_exists("menu_confirm") && !is_undefined(global.menu_confirm))
    {
        return keyboard_check_pressed(global.menu_confirm);
    }
    return false;
}

/// True while a cutscene may be skipped. The first 150 ms are ignored on purpose:
/// the key press that advanced the previous line is still down, and without this
/// a cutscene could be skipped by the very same press that started it.
function mod_cs_movie_skip_allowed()
{
    if (!variable_global_exists("mod_cs_movie_start")) return true;
    return ((current_time - global.mod_cs_movie_start) > 150);
}

/// Corrects the vid_scale of a running cutscene from the surface video_draw()
/// hands back: the mp4 header may be unreadable for some files, the decoded frame
/// never lies. Called once per cutscene from the Draw GUI event; until then the
/// scale is the mp4 header guess (or 0.5 if even that failed).
///
/// video_draw() only returns the current frame surface - o_movie_player itself
/// draws it in its own Draw event - so this call draws nothing by itself.
function mod_cs_movie_measure()
{
    if (!variable_global_exists("mod_cs_movie_measured")) return;
    if (global.mod_cs_movie_measured) return;

    var _movie = noone;
    if (global.mod_cs_movie != noone && instance_exists(global.mod_cs_movie)) _movie = global.mod_cs_movie;
    else if (global.mod_cs_chart_movie != noone && instance_exists(global.mod_cs_chart_movie)) _movie = global.mod_cs_chart_movie;
    if (_movie == noone) return;

    var _frame = video_draw();
    if (!is_array(_frame) || array_length(_frame) < 2) return;
    if (_frame[0] != 0) return;                     // frame not decoded yet
    var _w = 0;
    var _h = 0;
    try
    {
        _w = surface_get_width(_frame[1]);
        _h = surface_get_height(_frame[1]);
    }
    catch (_ex)
    {
        return;
    }
    if (_w <= 0 || _h <= 0) return;

    _movie.vid_scale = min(320 / _w, 180 / _h);
    global.mod_cs_movie_measured = true;
    mod_cs_log("movie: surface " + string(_w) + "x" + string(_h)
        + " -> vid_scale " + string(_movie.vid_scale));
}

/// True when the running cutscene neither shows anything nor finishes.
///
/// video_open() fails silently for codecs Media Foundation cannot decode (it needs
/// H.264 video + AAC audio; Opus audio in an mp4 - what OBS writes by default - makes
/// the whole file unplayable). Then video_get_status() stays 0 and "finished" never
/// becomes true, so without this the story would wait forever.
function mod_cs_movie_dead()
{
    if (variable_global_exists("mod_cs_movie_started") && global.mod_cs_movie_started) return false;
    if (!variable_global_exists("mod_cs_movie_start")) return false;
    if ((current_time - global.mod_cs_movie_start) <= 2500) return false;

    var _status = -1;
    try
    {
        _status = video_get_status();
    }
    catch (_ex)
    {
        _status = -1;
    }
    if (_status != 0)
    {
        global.mod_cs_movie_started = true;          // it is playing (or paused)
        return false;
    }
    return true;
}

/// Await of a story room cutscene (global.mod_cs_await_mode == 6).
function mod_cs_movie_done()
{
    if (!variable_global_exists("mod_cs_movie")) return true;
    if (is_undefined(global.mod_cs_movie) || global.mod_cs_movie == noone) return true;
    if (!instance_exists(global.mod_cs_movie))
    {
        global.mod_cs_movie = noone;
        mod_cs_movie_box_away(false);
        return true;
    }
    if (global.mod_cs_movie_skippable && mod_cs_movie_skip_allowed() && mod_cs_skip_pressed())
    {
        mod_cs_video_log("skipped by the player");
        instance_destroy(global.mod_cs_movie);
        global.mod_cs_movie = noone;
        mod_cs_movie_box_away(false);
        return true;
    }
    if (global.mod_cs_movie.checkFinished())
    {
        mod_cs_video_log("finished " + string(global.mod_cs_movie_file));
        instance_destroy(global.mod_cs_movie);
        global.mod_cs_movie = noone;
        mod_cs_movie_box_away(false);
        return true;
    }
    if (mod_cs_movie_dead())
    {
        // Report it in the textbox and carry on - a silent hang is worse. The
        // await that follows this one is a normal "confirm" wait.
        mod_cs_video_log("no picture after 2.5s (codec?), giving up: " + string(global.mod_cs_movie_file));
        instance_destroy(global.mod_cs_movie);
        global.mod_cs_movie = noone;
        mod_cs_movie_box_away(false);
        text_clear();
        name_set("");
        text("`c{red}[video failed to play] `c{white}" + string(global.mod_cs_movie_file)
            + chr(10) + "`c{think}(an mp4 with H.264 video + AAC audio is required)");
        global.mod_cs_await_mode = 0;
        return true;
    }
    return false;
}

/// Stops a running story room cutscene (story exit, room change, pause exit).
function mod_cs_movie_stop()
{
    if (!variable_global_exists("mod_cs_movie")) return;
    if (is_undefined(global.mod_cs_movie) || global.mod_cs_movie == noone) return;
    if (instance_exists(global.mod_cs_movie)) instance_destroy(global.mod_cs_movie);
    global.mod_cs_movie = noone;
    mod_cs_movie_box_away(false);
}

/// Stops a running in-chart cutscene.
function mod_cs_chart_movie_clear()
{
    if (!variable_global_exists("mod_cs_chart_movie")) return;
    // Give the HUD its alpha back if the cutscene hid it (the score/combo layer is
    // drawn in the GUI layer, i.e. above the video).
    if (variable_global_exists("mod_cs_chart_movie_uialpha") && global.mod_cs_chart_movie_uialpha >= 0)
    {
        if (instance_exists(cc) && variable_instance_exists(cc, "mod_uialpha"))
        {
            cc.mod_uialpha = global.mod_cs_chart_movie_uialpha;
        }
        global.mod_cs_chart_movie_uialpha = -1;
    }
    if (is_undefined(global.mod_cs_chart_movie) || global.mod_cs_chart_movie == noone)
    {
        mod_cs_movie_box_away(false);
        return;
    }
    if (instance_exists(global.mod_cs_chart_movie)) instance_destroy(global.mod_cs_chart_movie);
    global.mod_cs_chart_movie = noone;
    mod_cs_movie_box_away(false);
}

// ---------------------------------------------------------------------------
// In-chart stories: gimmick "custom_episode"
//
// The vanilla chart gimmicks (obj_memories_gimmick / obj_supernova_gimmick) put
// their dialogue straight into the gameplay room: they create an o_textbox by
// depth and drive the global text engine (text / name_set / text_clear) while
// the song keeps playing. This mod does the same, driven from the Step event
// instead of a coroutine, so a chart never has to leave its own room.
//
// A chart triggers it from its .vsm with a line such as
//     120,0,linear,_,_,custom_episode,-1
// and the story sits next to the chart as story.json ("!story: other.json"
// overrides the file name). Only the steps handled by mod_cs_chart_step() are
// available; everything else is skipped and written to Custom Episodes/_modlog.txt.
//
// Timing comes from cc.currentms, i.e. from the song, so an in-chart story
// freezes with the song instead of running on the wall clock.
// ---------------------------------------------------------------------------

/// Appends one line to "Custom Episodes/_modlog.txt" no matter what.
///
/// Used by the two features an author cannot debug with "debuglog": in-chart
/// stories and video cutscenes (a video that does not play is invisible otherwise).
function mod_cs_always_log(_tag, _msg)
{
    var _f = -1;
    try
    {
        _f = file_text_open_append(global.mod_cs_dir + "_modlog.txt");
    }
    catch (_ex)
    {
        return;
    }
    if (_f == -1) return;
    file_text_write_string(_f, string(current_time) + "  [" + string(_tag) + "] " + string(_msg));
    file_text_writeln(_f);
    file_text_close(_f);
}

/// Log line for in-chart stories (see mod_cs_always_log).
function mod_cs_chart_log(_msg)
{
    mod_cs_always_log("chart", _msg);
}

/// Log line for video cutscenes (see mod_cs_always_log).
function mod_cs_video_log(_msg)
{
    mod_cs_always_log("video", _msg);
}

/// Frame count for a duration in seconds.
///
/// The gameplay room sets the game speed to the player's FPS cap (cc_Create_0:
/// game_set_speed(global.gamefps, gamespeed_fps)), which is 1000 on this machine,
/// while the story room runs at 60. A hardcoded 60 frames is therefore 0.06 s in
/// a chart instead of 1 s, which made the textbox snap into place. The vanilla
/// chart stories scale their tweens the same way (ss_memories uses global.gamefps
/// for the box sliding out).
function mod_cs_chart_frames(_seconds)
{
    var _fps = 60;
    if (variable_global_exists("gamefps") && global.gamefps > 0) _fps = global.gamefps;
    else if (room_speed > 0) _fps = room_speed;
    return max(1, round(_seconds * _fps));
}

/// Song position in milliseconds, or 0 when no chart is running.
function mod_cs_chart_clock()
{
    if (!instance_exists(cc)) return 0;
    if (!variable_instance_exists(cc, "currentms")) return 0;
    return cc.currentms;
}

/// Folder of the chart that is playing ("Custom Songs/xxx/"), or "" when the
/// current song is not a custom one. The pack loader stores it in
/// currentSongInfo.chart_path (see the Custom Songs Mod).
function mod_cs_chart_dir()
{
    var _dir = "";
    try
    {
        if (variable_global_exists("currentSongInfo") && global.currentSongInfo != undefined)
        {
            var _info = global.currentSongInfo;
            if (is_struct(_info) && variable_struct_exists(_info, "chart_path"))
            {
                _dir = string(_info.chart_path);
            }
        }
    }
    catch (_ex)
    {
        _dir = "";
    }
    if (_dir == "") return "";
    if (string_copy(_dir, string_length(_dir), 1) != "/") _dir += "/";
    return _dir;
}

/// Full path of the story file of the chart that is playing.
function mod_cs_chart_story_file()
{
    var _dir = mod_cs_chart_dir();
    if (_dir == "") return "";

    // Optional override from the chart's .vsm: "!story: my_story.json". The
    // key/value pairs of a .vsm land in cc.mods.data.
    var _name = "";
    try
    {
        if (instance_exists(cc) && variable_instance_exists(cc, "mods"))
        {
            var _mods = cc.mods;
            if (is_struct(_mods) && variable_struct_exists(_mods, "data"))
            {
                var _data = _mods.data;
                if (is_struct(_data) && variable_struct_exists(_data, "story")) _name = string(_data.story);
            }
        }
    }
    catch (_ex)
    {
        _name = "";
    }
    if (_name == "") _name = "story.json";
    // A name containing a slash is taken from the game directory, so several
    // charts can share one story; a plain file name stays in the chart folder.
    if (string_pos("/", _name) > 0) return _name;
    return _dir + _name;
}

/// Reads the top level of a story file. Only the fields an in-chart story needs
/// are read; portraits, images and the high resolution settings are ignored on
/// purpose. Returns true when the file holds at least one line.
function mod_cs_chart_load(_file)
{
    global.mod_cs_chart_lines = [];
    global.mod_cs_chart_chars = {};
    global.mod_cs_chart_title = "";
    global.mod_cs_chart_wrap = true;
    global.mod_cs_chart_width = 308;
    global.mod_cs_chart_dwell = 0;
    global.mod_cs_chart_folder = "";
    if (!file_exists(_file)) return false;

    var _fh = file_text_open_read(_file);
    var _raw = "";
    while (!file_text_eof(_fh))
    {
        _raw += file_text_read_string(_fh);
        _raw += chr(10);
        file_text_readln(_fh);
    }
    file_text_close(_fh);

    var _data = undefined;
    try
    {
        _data = json_parse(_raw);
    }
    catch (_ex)
    {
        _data = undefined;
    }
    if (!is_struct(_data)) return false;

    if (variable_struct_exists(_data, "lines") && is_array(_data.lines)) global.mod_cs_chart_lines = _data.lines;
    if (variable_struct_exists(_data, "characters") && is_struct(_data.characters)) global.mod_cs_chart_chars = _data.characters;
    if (variable_struct_exists(_data, "title")) global.mod_cs_chart_title = string(_data.title);
    if (variable_struct_exists(_data, "wrap")) global.mod_cs_chart_wrap = (_data.wrap != false);
    if (variable_struct_exists(_data, "width")) global.mod_cs_chart_width = real(_data.width);
    // Default dwell of one dialogue line in milliseconds. 0 = not set: in-chart
    // lines then wait for the next "custom_episode_next" trigger (beat driven, the
    // default). Writing "chart_dwell" (or a per line "dwell") turns lines back into
    // plain timers.
    if (variable_struct_exists(_data, "chart_dwell")) global.mod_cs_chart_dwell = real(_data.chart_dwell);
    // Relative audio paths resolve against the folder of story.json.
    global.mod_cs_chart_folder = string_copy(_file, 1, max(0, string_length(_file) - string_length("story.json")));
    return (array_length(global.mod_cs_chart_lines) > 0);
}

/// Reports a story step that is not available inside a chart, once per kind.
function mod_cs_chart_note(_kind)
{
    if (!variable_global_exists("mod_cs_chart_skipped") || !is_struct(global.mod_cs_chart_skipped))
    {
        global.mod_cs_chart_skipped = {};
    }
    if (variable_struct_exists(global.mod_cs_chart_skipped, _kind)) return;
    variable_struct_set(global.mod_cs_chart_skipped, _kind, true);
    mod_cs_chart_log("step not available in a chart, skipped: " + string(_kind));
}

/// Starts an in-chart story. Returns false when the file cannot be used.
function mod_cs_chart_start(_file)
{
    if (!instance_exists(cc)) return false;
    if (!mod_cs_chart_load(_file)) return false;

    // obj_textboxHandler reads these two globals in its own Step event, and a
    // gameplay room never created them: the vanilla chart stories (see
    // obj_memories_gimmick_Create_0) set them in their gimmick Create event for
    // exactly this reason. The missing "skip" crashed the textbox on frame one.
    if (!variable_global_exists("skip")) global.skip = false;
    if (!variable_global_exists("story_paused")) global.story_paused = false;
    // textbox_exists() reads global.textbox directly and only text() assigns it,
    // so it has to exist before the first textbox_exists() call.
    if (!variable_global_exists("textbox")) global.textbox = undefined;

    global.mod_cs_chart_active = true;
    global.mod_cs_chart_file = _file;
    global.mod_cs_chart_index = 0;
    // Beat driven: the first line belongs to the beat of "custom_episode" itself,
    // so nothing waits for the box to slide in - the text shows while it does.
    global.mod_cs_chart_typing = false;
    global.mod_cs_chart_step_dwell = 0;
    global.mod_cs_chart_deadline = 0;
    global.mod_cs_chart_wait_trigger = false;
    global.mod_cs_chart_step_sync = false;
    global.mod_cs_chart_exit = 0;
    global.mod_cs_chart_room = room;
    global.mod_cs_chart_box = noone;
    // The chart conductor of this run: a quick restart builds a new one while the
    // room index stays the same, which is how a restart is detected.
    global.mod_cs_chart_cc = cc;
    global.mod_cs_chart_created_box = false;
    global.mod_cs_chart_skipped = {};
    global.mod_cs_chart_missing = "";

    // The gameplay room has no "Textbox" layer, so create_textbox() cannot be
    // used here; the vanilla in-chart stories create the box by depth instead.
    // They also rest at y = 132 in a chart (the story room uses 122).
    if (!instance_exists(o_textbox))
    {
        global.mod_cs_chart_box = instance_create_depth(0, 180, -70, o_textbox);
        global.mod_cs_chart_created_box = true;
        with (o_textbox)
        {
            TweenEasyMove(0, 180, 0, 132, 0, mod_cs_chart_frames(1), EaseOutExpo);
        }
    }
    name_set("");
    mod_cs_chart_log("start " + _file);
    return true;
}

/// Ends an in-chart story and hands the textbox back.
function mod_cs_chart_stop(_why)
{
    if (global.mod_cs_chart_active) mod_cs_chart_log("stop (" + string(_why) + ")");
    global.mod_cs_chart_req = undefined;
    global.mod_cs_chart_active = false;
    global.mod_cs_chart_typing = false;
    global.mod_cs_chart_wait_trigger = false;
    global.mod_cs_chart_step_sync = false;
    global.mod_cs_chart_exit = 0;
    if (textbox_exists()) text_clear();
    if (global.mod_cs_chart_created_box && instance_exists(global.mod_cs_chart_box))
    {
        instance_destroy(global.mod_cs_chart_box);
    }
    global.mod_cs_chart_created_box = false;
    global.mod_cs_chart_box = noone;
    global.mod_cs_chart_cc = noone;
    // A cutscene must never outlive the story that started it.
    mod_cs_chart_movie_clear();
    // Streams opened for this story (OGG files relative to the chart folder).
    mod_cs_free_audio();
}

/// Runs one step of an in-chart story. Returns the wait in milliseconds before
/// the next step, -1 when the next step waits for the typewriter first, or -2
/// when it waits for a cutscene (see the movie block in mod_cs_chart_tick).
function mod_cs_chart_step(_e)
{
    if (!is_struct(_e)) return 0;
    var _kind = "line";
    if (variable_struct_exists(_e, "kind")) _kind = string(_e.kind);

    switch (_kind)
    {
        case "line":
        case "narration":
            var _who = "";
            if (variable_struct_exists(_e, "who")) _who = string(_e.who);
            if (_who == "")
            {
                name_set("");
            }
            else if (variable_struct_exists(global.mod_cs_chart_chars, _who))
            {
                var _c = variable_struct_get(global.mod_cs_chart_chars, _who);
                var _label = _who;
                if (variable_struct_exists(_c, "display_name")) _label = string(_c.display_name);
                name_set(_label);
            }
            else
            {
                name_set(_who);
            }

            if (!variable_struct_exists(_e, "text")) return 0;
            var _body = string(_e.text);
            // In-chart typing defaults to half the story room rate: the typewriter
            // runs at 100 * speed characters per second, and a chart can cap the
            // frame rate at 1000 fps, which makes it look instant. A line can
            // raise or lower this with its own "speed".
            var _speed = 0.5;
            if (variable_struct_exists(_e, "speed")) _speed = real(_e.speed);
            var _do_wrap = global.mod_cs_chart_wrap;
            var _w = global.mod_cs_chart_width;
            if (variable_struct_exists(_e, "wrap")) _do_wrap = (_e.wrap != false);
            if (variable_struct_exists(_e, "width")) _w = real(_e.width);
            if (_do_wrap) _body = mod_cs_wrap_text(_body, _w);
            text(_body, _speed);

            // Beat driven by default: the line stays on screen until the next
            // "custom_episode_next" fires (that is what a .vsm can express). An
            // explicit "dwell" on the line - or a top level "chart_dwell" - turns
            // that line back into a plain timer.
            var _sync = true;
            var _dwell = 0;
            if (variable_struct_exists(_e, "dwell"))
            {
                _sync = false;
                _dwell = real(_e.dwell);
            }
            else if (global.mod_cs_chart_dwell > 0)
            {
                _sync = false;
                _dwell = global.mod_cs_chart_dwell;
            }
            if (!_sync) _dwell += (string_length(_body) * 40) / max(0.1, _speed);
            global.mod_cs_chart_step_dwell = max(200, _dwell);
            global.mod_cs_chart_step_sync = _sync;
            return -1;

        case "narrator":
            if (variable_struct_exists(_e, "value")) name_set(string(_e.value));
            return 0;

        case "clear":
            text_clear();
            return 0;

        case "wait":
            // In the story room this waits for a key press. Inside a chart it waits
            // for the next trigger (the beat driven default); writing "ms" makes it
            // a plain timer instead.
            if (variable_struct_exists(_e, "ms")) return max(0, real(_e.ms));
            return -3;              // -3 = wait for a "custom_episode_next"

        case "delay":
            var _dms = 0;
            if (variable_struct_exists(_e, "ms")) _dms = real(_e.ms);
            return max(0, _dms);

        case "se":
            if (variable_struct_exists(_e, "value"))
            {
                var _se = mod_cs_sound(_e.value);
                if (_se >= 0)
                {
                    var _gain = 1;
                    if (variable_struct_exists(_e, "gain")) _gain = real(_e.gain);
                    play_se(_se, _gain);
                }
            }
            return 0;

        case "bgm_gain":
            if (variable_global_exists("bgm") && audio_is_playing(global.bgm))
            {
                var _to = 1;
                var _tms = 1000;
                if (variable_struct_exists(_e, "to")) _to = real(_e.to);
                if (variable_struct_exists(_e, "time")) _tms = real(_e.time);
                audio_sound_gain(global.bgm, _to * global.op_bgm_volume, _tms);
            }
            return 0;

        case "bgm_stop":
            if (variable_global_exists("bgm") && audio_is_playing(global.bgm))
            {
                var _fade = 0;
                if (variable_struct_exists(_e, "fade")) _fade = real(_e.fade);
                if (_fade > 0) audio_sound_gain(global.bgm, 0, _fade);
                else audio_stop_sound(global.bgm);
            }
            return 0;

        case "video":
            // A cutscene inside a chart covers the play area; the song keeps
            // running. Skipping defaults to off here (during play the note keys
            // would cut it); "skippable": true turns it on for the confirm key.
            var _cutname = "";
            if (variable_struct_exists(_e, "value")) _cutname = string(_e.value);
            global.mod_cs_chart_movie = mod_cs_video_play(_e);
            global.mod_cs_movie_start = current_time;
            global.mod_cs_chart_movie_skip = false;
            if (variable_struct_exists(_e, "skippable")) global.mod_cs_chart_movie_skip = (_e.skippable == true);
            // Optional "hidegui": the score/combo HUD is drawn in the GUI layer, so
            // it sits above the video. Its alpha is saved and restored by
            // mod_cs_chart_movie_clear().
            global.mod_cs_chart_movie_uialpha = -1;
            if (variable_struct_exists(_e, "hidegui") && _e.hidegui == true
                && instance_exists(cc) && variable_instance_exists(cc, "mod_uialpha"))
            {
                global.mod_cs_chart_movie_uialpha = cc.mod_uialpha;
                cc.mod_uialpha = 0;
            }
            if (global.mod_cs_chart_movie != noone) return -2;
            mod_cs_video_log("not found: " + _cutname);
            return 0;

        case "end":
        case "goto":
        case "abort":
            global.mod_cs_chart_index = array_length(global.mod_cs_chart_lines);
            return 0;
    }

    // Everything else (portraits, external images, full screen text, high
    // resolution, transitions, the HUD ...) belongs to the story room.
    mod_cs_chart_note(_kind);
    return 0;
}

/// "custom_episode_next" fired: advance the story by one step.
///
/// Only a story that is actually waiting for a trigger moves. Everything else is
/// dropped on purpose (and logged), so a stray trigger can never make the story
/// run away: not running, a cutscene is playing, or an explicit "delay" is still
/// counting down.
function mod_cs_chart_next()
{
    if (!global.mod_cs_chart_active)
    {
        mod_cs_chart_log("next ignored: no story is running");
        return;
    }
    if (global.mod_cs_chart_movie != noone)
    {
        mod_cs_chart_log("next ignored: a cutscene is playing");
        return;
    }
    var _waiting = global.mod_cs_chart_wait_trigger
        || (global.mod_cs_chart_typing && global.mod_cs_chart_step_sync);
    if (!_waiting)
    {
        mod_cs_chart_log("next ignored: not waiting for a trigger (delay / box slide in)");
        return;
    }

    // Beat first: cut the typewriter short and run the next step right now. The
    // tick picks this up in the same frame (deadline 0 = already due).
    global.mod_cs_chart_wait_trigger = false;
    global.mod_cs_chart_typing = false;
    global.mod_cs_chart_step_sync = false;
    global.mod_cs_chart_deadline = 0;
    mod_cs_chart_log("next -> step " + string(global.mod_cs_chart_index + 1));
}

/// One frame of in-chart playback; called first thing in the Step event.
function mod_cs_chart_tick()
{
    // A "custom_episode" gimmick fired: pick the request up here, where the room
    // and the story state are known.
    if (!variable_global_exists("mod_cs_chart_req")) global.mod_cs_chart_req = undefined;
    if (global.mod_cs_chart_req != undefined)
    {
        var _req = global.mod_cs_chart_req;
        global.mod_cs_chart_req = undefined;
        // mode 0 = "custom_episode" (start), mode 1 = "custom_episode_next"
        // (advance one step). See the registration block at the end of this event.
        var _reqmode = 0;
        if (is_struct(_req) && variable_struct_exists(_req, "mode")) _reqmode = _req.mode;
        if (_reqmode == 1)
        {
            mod_cs_chart_next();
        }
        else if (!global.mod_cs_active && room != scene_story && instance_exists(cc))
        {
            // A trigger that arrives while a story is still on screen replaces it:
            // a second gimmick line, or a quick restart re-firing the same one.
            // Stopping first also takes the previous textbox down.
            if (global.mod_cs_chart_active) mod_cs_chart_stop("replaced by a new trigger");
            var _file = mod_cs_chart_story_file();
            if (_file == "")
            {
                mod_cs_chart_log("no story folder for this chart (not a custom song?)");
            }
            else if (!mod_cs_chart_start(_file))
            {
                mod_cs_chart_log("could not start " + _file + " (missing or unreadable)");
            }
        }
    }

    if (!global.mod_cs_chart_active) return;

    // Song over, player quit, retry or room change: leave no textbox behind.
    // A quick restart (cc_Step_1 calls room_restart) keeps the room *and* the room
    // index and only builds a fresh cc, so the instance is compared as well -
    // without this a restart left the story "active" and swallowed the next
    // trigger, so the story never showed up again.
    if (!instance_exists(cc) || room != global.mod_cs_chart_room || cc != global.mod_cs_chart_cc)
    {
        mod_cs_chart_stop("left the song");
        return;
    }

    // A cutscene is on screen: hold the step machine until it is over. The song
    // keeps running, so the deadline check below is skipped on purpose.
    if (global.mod_cs_chart_movie != noone)
    {
        if (!instance_exists(global.mod_cs_chart_movie))
        {
            global.mod_cs_chart_movie = noone;
        }
        else
        {
            var _cut = global.mod_cs_chart_movie;
            var _skip = false;
            if (global.mod_cs_chart_movie_skip && mod_cs_movie_skip_allowed()
                && variable_global_exists("menu_confirm") && !is_undefined(global.menu_confirm))
            {
                _skip = keyboard_check_pressed(global.menu_confirm);
            }
            if (_skip || _cut.checkFinished() || mod_cs_movie_dead())
            {
                instance_destroy(_cut);
                global.mod_cs_chart_movie = noone;
                if (_skip) mod_cs_video_log("skipped by the player (in chart)");
                else if (!global.mod_cs_movie_started) mod_cs_video_log("no picture after 2.5s (codec?), giving up: " + string(global.mod_cs_movie_file));
                mod_cs_movie_box_away(false);
            }
            else
            {
                return;
            }
        }
    }

    // Box sliding out: destroy it when the tween is done.
    if (global.mod_cs_chart_exit > 0)
    {
        global.mod_cs_chart_exit--;
        if (global.mod_cs_chart_exit <= 0)
        {
            text_clear();
            if (global.mod_cs_chart_created_box && instance_exists(global.mod_cs_chart_box))
            {
                instance_destroy(global.mod_cs_chart_box);
            }
            global.mod_cs_chart_created_box = false;
            global.mod_cs_chart_box = noone;
            global.mod_cs_chart_active = false;
            mod_cs_chart_log("finished");
            mod_cs_chart_movie_clear();
            mod_cs_free_audio();
        }
        return;
    }

    // Beat driven: the step machine stands still until "custom_episode_next"
    // arrives (see mod_cs_chart_next). Nothing here is time based, so the deadline
    // gate below is skipped while waiting.
    if (global.mod_cs_chart_wait_trigger) return;

    if (mod_cs_chart_clock() < global.mod_cs_chart_deadline) return;

    if (global.mod_cs_chart_typing)
    {
        // Let the typewriter finish this line before its dwell starts.
        var _done = true;
        try
        {
            if (textbox_exists() && variable_instance_exists(global.textbox, "done")) _done = global.textbox.done;
        }
        catch (_ex)
        {
            _done = true;
        }
        if (!_done) return;
        global.mod_cs_chart_typing = false;
        if (global.mod_cs_chart_step_sync)
        {
            // Beat driven line: no timer, the next trigger moves on.
            global.mod_cs_chart_wait_trigger = true;
            return;
        }
        global.mod_cs_chart_deadline = mod_cs_chart_clock() + global.mod_cs_chart_step_dwell;
        return;
    }

    var _lines = global.mod_cs_chart_lines;
    while (global.mod_cs_chart_index < array_length(_lines))
    {
        var _e = _lines[global.mod_cs_chart_index];
        global.mod_cs_chart_index++;
        var _wait = mod_cs_chart_step(_e);
        if (_wait == -3)
        {
            // "wait" without "ms": stand still until the next trigger.
            global.mod_cs_chart_wait_trigger = true;
            return;
        }
        if (_wait == -2)
        {
            // A cutscene is running: the movie block above drives on when it ends.
            global.mod_cs_chart_typing = false;
            return;
        }
        if (_wait < 0)
        {
            // A line is on screen: wait for the typewriter, then for its dwell (or
            // for the next trigger, see the typing branch above).
            global.mod_cs_chart_typing = true;
            return;
        }
        if (_wait > 0)
        {
            global.mod_cs_chart_deadline = mod_cs_chart_clock() + _wait;
            return;
        }
    }

    // Out of steps: slide the box down and finish. Both numbers are in frames of
    // the current game speed (see mod_cs_chart_frames).
    if (instance_exists(o_textbox))
    {
        with (o_textbox)
        {
            TweenEasyMove(0, y, 0, 180, 0, mod_cs_chart_frames(0.8), EaseOutExpo);
        }
    }
    text_clear();
    global.mod_cs_chart_exit = mod_cs_chart_frames(1);
}


/// Prepare a story: capture globals, install load_scene, then switch rooms.
/// Parsing is left to the object's Step, because by then every game object
/// (o_bg / o_cutsceneConductor / o_story_tint) exists in the new room.
function mod_cs_begin(_folder)
{
    // global.load_scene may not exist yet: nothing on the main menu assigns it
    // until a story button is activated, and reading an undefined global throws.
    // It is only saved while it is not ours: after a pause-menu exit the previous
    // session never restored it, and saving our own builder would make the stock
    // story buttons load this mod instead.
    if (!variable_global_exists("mod_cs_owns_load_scene")) global.mod_cs_owns_load_scene = false;
    if (variable_global_exists("load_scene") && !global.mod_cs_owns_load_scene)
    {
        global.mod_cs_saved_load_scene = global.load_scene;
    }
    else if (!variable_global_exists("load_scene"))
    {
        global.mod_cs_saved_load_scene = undefined;
    }
    if (variable_global_exists("last_episode_name"))
    {
        global.mod_cs_saved_episode = global.last_episode_name;
    }
    else
    {
        global.mod_cs_saved_episode = "";
    }
    global.mod_cs_pending = _folder;

    // Switch the resident object to playback mode immediately, so the picker
    // input handler cannot stay alive across the room change.
    if (instance_exists(o_mod_storyentry))
    {
        with (o_mod_storyentry)
        {
            mode = 1;
            menu_open = false;
            menu_set_overlay_visible(true);
        }
    }

    // The global must exist before it can be assigned; on a fresh boot nothing has
    // created it yet, and assigning to an undefined global throws.
    if (!variable_global_exists("load_scene"))
    {
        global.load_scene = undefined;
    }
// Builds a real game coroutine for one custom episode and runs it.
//
// Two GML rules shape this code, both learned the hard way:
//  1. o_cutsceneConductor stores the result in .coroutine, cancels it on pause
//     lets oCoroutineManager drive it via __Run(), so a plain function will not
//     do - the return value must be a __CoroutineRootClass instance.
//  2. "with (obj)" does NOT merely change self: it also makes every bare
//     identifier resolve as a member of that instance, so captured locals such as
//     _lines become invisible. method(obj, fn) binds the scope while keeping the
//     enclosing locals readable, so it is used for every callback here.
global.mod_cs_run_pending = function()
{
    var _dir = global.mod_cs_dir;
    var _folder = global.mod_cs_pending;
    global.mod_cs_pending = undefined;
    global.mod_cs_active = true;
    // Remembered so external image / audio paths can be resolved relative to the
    // episode.
    global.mod_cs_folder = _folder;
    // A fresh episode never inherits the previous one's images or streams.
    mod_cs_free_images();
    mod_cs_free_audio();

    // Load the story first, then carry the data in globals so the coroutine
    // callbacks never depend on captured locals at all.
    var _lines = [];
    var _chars = {};
    var _title = "";
    var _file = _dir + _folder + "/story.json";
    // Opening background / BGM and the chapter label, all optional.
    var _bg = "";
    var _bgm = "";
    var _epname = "";
    // Dialogue box width used by the vanilla text engine: obj_textboxHandler sets
    // TextDrawer.setBounds(10, 308 + (70 * is_vector)).
    var _wrap = true;
    var _width = 308;
    var _dbgimg = false;
    var _dbglog = false;

    if (file_exists(_file))
    {
        var _fh = file_text_open_read(_file);
        var _raw = "";
        while (!file_text_eof(_fh))
        {
            _raw += file_text_read_string(_fh);
            _raw += chr(10);
            file_text_readln(_fh);
        }
        file_text_close(_fh);

        var _data = undefined;
        try
        {
            _data = json_parse(_raw);
        }
        catch (_ex)
        {
            _data = undefined;
        }

        if (is_struct(_data))
        {
            if (variable_struct_exists(_data, "lines") && is_array(_data.lines)) _lines = _data.lines;
            if (variable_struct_exists(_data, "characters") && is_struct(_data.characters)) _chars = _data.characters;
            if (variable_struct_exists(_data, "title")) _title = string(_data.title);
            if (variable_struct_exists(_data, "bg")) _bg = string(_data.bg);
            if (variable_struct_exists(_data, "bgm")) _bgm = string(_data.bgm);
            if (variable_struct_exists(_data, "episode_name")) _epname = string(_data.episode_name);
            // Optional wrapping settings, see README: "wrap" (bool) switches the
            // automatic wrapping off, "width" overrides the dialogue box width.
            if (variable_struct_exists(_data, "wrap")) _wrap = (_data.wrap != false);
            if (variable_struct_exists(_data, "width")) _width = real(_data.width);
            // "debugimages": true prints the size of every external image the
            // episode loaded into the first dialogue line, which is the quickest
            // way to work out a portrait "scale".
            if (variable_struct_exists(_data, "debugimages")) _dbgimg = (_data.debugimages == true);
            if (variable_struct_exists(_data, "debuglog")) _dbglog = (_data.debuglog == true);
        }
    }

    global.mod_cs_lines = _lines;
    global.mod_cs_chars = _chars;
    global.mod_cs_title = _title;
    global.mod_cs_file = _file;
    global.mod_cs_wrap = _wrap;
    global.mod_cs_width = _width;
    global.mod_cs_bg = _bg;
    global.mod_cs_bgm = _bgm;
    global.mod_cs_debug_images = _dbgimg;
    global.mod_cs_debug_log = _dbglog;
    // The chapter label is consumed by o_cutsceneConductor when it is created, and
    // this builder runs from inside that very Create event, so writing it here is
    // still early enough. mod_cs_restore_globals() puts the old value back later.
    if (_epname != "" && variable_global_exists("last_episode_name")) global.last_episode_name = _epname;
    // Portrait instances of this run (key -> instance), filled by mod_cs_show_portrait.
    global.mod_cs_portraits = {};
    // Decode every external image up front: a 1920x1080 PNG takes a moment, and
    // that moment must not land in the middle of a scene.
    mod_cs_preload_assets();

    var _begin = method(o_mod_storyentry, function()
    {
        // Only globals may be read here: a coroutine lambda cannot resolve the
        // enclosing function's locals (verified: it reported _lines as a member of
        // __CoroutineRootClass). method() binds self, not the local scope.
        if (array_length(global.mod_cs_lines) <= 0)
        {
            create_textbox();
            name_set("custom episode");
            text("Could not read " + global.mod_cs_file);
            global.mod_cs_active = false;
            return;
        }

        // Opening scene from the story's top level ("bg" / "bgm"). Applied before
        // the first line, so a story does not need a leading bg/bgm step.
        if (global.mod_cs_bg != "")
        {
            var _bgi = mod_cs_sprite(global.mod_cs_bg);
            if (_bgi >= 0 && instance_exists(o_bg))
            {
                o_bg.sprite_index = _bgi;
                if (mod_cs_is_image_name(global.mod_cs_bg)) o_bg.highres = true;
            }
        }
        if (global.mod_cs_bgm != "")
        {
            var _bgmi = mod_cs_sound(global.mod_cs_bgm);
            if (_bgmi >= 0) play_bgm(_bgmi);
        }

        var _first = global.mod_cs_lines[0];
        if (is_struct(_first))
        {
            var _k0 = "line";
            if (variable_struct_exists(_first, "kind")) _k0 = string(_first.kind);
            if ((_k0 == "bg" || _k0 == "bgm") && variable_struct_exists(_first, "value"))
            {
                var _a0 = mod_cs_sprite(_first.value);
                var _a0snd = mod_cs_sound(_first.value);
                if (_k0 == "bg")
                {
                    if (_a0 >= 0 && instance_exists(o_bg)) o_bg.sprite_index = _a0;
                }
                else
                {
                    if (_a0snd >= 0) play_bgm(_a0snd);
                }
            }
        }

        set_tint_color(0);
        fade_tint(1, 0, 0);
        create_textbox();

        // Robustness guard. create_textbox() uses instance_create_layer(..., "Textbox")
        // and does nothing when that layer is missing - which happens when the stock
        // menu also acted on the same key press and replaced our room. name_set()
        // would then throw "Unable to find any instance for object index o_textbox"
        // and take the whole game down, so bail out instead.
        if (!instance_exists(o_textbox))
        {
            global.mod_cs_aborted = true;
            global.mod_cs_active = false;
            global.mod_cs_pending = undefined;
            mod_cs_restore_globals();
            mod_cs_reset_resolution();
            // Same reasoning as mod_cs_end(): the frame is still drawn with the
            // images attached, so the actual free happens in the Step event.
            global.mod_cs_release_pending = true;
            // Inside the story room there is nothing left to show, so go back to
            // the menu; anywhere else the player was sent there by the stock flow,
            // so leave the room alone.
            if (room == scene_story) mod_cs_end();
            return;
        }

        // name_set() needs an existing o_textbox, so it must come after
        name_set("");
        // Anything that could not be loaded is reported here, once, instead of
        // silently showing nothing later on.
        var _intro = "playing custom episode: " + global.mod_cs_title;
        if (global.mod_cs_image_missing != "")
        {
            _intro += chr(10) + "`c{red}[image not found] `c{white}" + global.mod_cs_image_missing;
        }
        if (global.mod_cs_audio_missing != "")
        {
            _intro += chr(10) + "`c{red}[audio not found] `c{white}" + global.mod_cs_audio_missing;
        }
        if (global.mod_cs_debug_images)
        {
            if (global.mod_cs_image_sizes != "") _intro += chr(10) + "`c{think}[images] " + global.mod_cs_image_sizes;
            if (global.mod_cs_audio_sizes != "") _intro += chr(10) + "`c{think}[audio] " + global.mod_cs_audio_sizes;
        }
        text(_intro);
    });

    var _end = method(o_mod_storyentry, function()
    {
        global.mod_cs_active = false;
        // self is the coroutine instance while this runs, so the menu cleanup
        // (an instance function of o_mod_storyentry) needs an explicit scope.
        with (o_mod_storyentry)
        {
            menu_close_browser();
        }
        mod_cs_end();
    });

    var _cor = __CoroutineBegin(_begin);

    // One wait step and one apply step per story line, built in a loop so the
    // number of lines can come from the JSON file.
    //
    // NOTE: the coroutine engine runs every queued function with self set to the
    // coroutine instance, so a step body cannot read instance variables - not
    // even ones written here, and not through method(obj, fn). Only globals
    // survive, so this loop cannot hand the line index to the step body: the
    // step advances the global counter itself when it actually runs.
    global.mod_cs_step_index = 0;
    global.mod_cs_await_mode = 0;
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        // The wait in front of every step. Which condition it uses is decided by
        // the *previous* step through global.mod_cs_await_mode:
        //   0 = wait for the player to confirm the textbox
        //   2 = plain timer (global.mod_cs_await_ms, started by the step)
        //   4 = switch to the full screen textbox and wait until it is ready
        //   5 = dismiss the full screen textbox and wait until it is gone
        //   6 = wait for the cutscene of a "video" step to finish / be skipped
        __CoroutineAwait(method(o_mod_storyentry, function()
        {
            var _mode = global.mod_cs_await_mode;

            if (_mode == 2) return ((current_time - global.mod_cs_wait_start) >= global.mod_cs_await_ms);
            if (_mode == 4) return switch_to_fullscreen();
            if (_mode == 5) return end_fullscreen();
            if (_mode == 6) return mod_cs_movie_done();

            // Nothing on screen at all (story start, or right after clear()).
            // o_fullscreen_textbox needs its own check: in full screen mode
            // switch_to_fullscreen() has already destroyed global.textbox.
            if (!textbox_exists() && !instance_exists(o_fullscreen_textbox)) return true;

            return check_textbox_done();
        }));
        __CoroutineThen(global.mod_cs_make_step());
    }

    __CoroutineThen(_end);
    return __CoroutineEnd();
};

// Builds one coroutine step. Stored in a global because this factory is called
// from inside the load_scene function, whose enclosing scope is
// o_cutsceneConductor - an instance method would not resolve there.
// The returned method is bound to the mod object on purpose: the step body runs
// under the coroutine manager, and bound methods keep their own scope.
global.mod_cs_make_step = function()
{
    return method(o_mod_storyentry, function()
    {
        var _dir = global.mod_cs_dir;
        var _chars = global.mod_cs_chars;
        // Reused by every portrait case, declared once so no case redeclares it.
        var _p = noone;
        // Set when the episode could not be started (see the guard in _begin): the
        // queued steps still run, so they have to become no-ops.
        if (global.mod_cs_aborted) return;
        // Steps run strictly in order, so advancing the global counter here
        // yields exactly the line this step is responsible for.
        var _e = global.mod_cs_lines[global.mod_cs_step_index];
        global.mod_cs_step_index++;

        // Pacing of the wait that follows this step. Reset every time; the cases
        // below opt into auto advance / timer / full screen handling.
        global.mod_cs_await_mode = 0;
        global.mod_cs_await_ms = 0;
        if (!is_struct(_e)) return;

        var _kind = "line";
        if (variable_struct_exists(_e, "kind")) _kind = string(_e.kind);

        switch (_kind)
        {
            case "line":
            case "narration":
                var _who = "";
                if (variable_struct_exists(_e, "who")) _who = string(_e.who);

                if (_who == "")
                {
                    name_set("");
                }
                else if (variable_struct_exists(_chars, _who))
                {
                    var _c = variable_struct_get(_chars, _who);
                    var _label = _who;
                    if (variable_struct_exists(_c, "display_name")) _label = string(_c.display_name);
                    if (variable_struct_exists(_c, "color"))
                    {
                        var _col = asset_get_index(string(_c.color));
                        if (_col >= 0) global.textboxcolor = _col;
                    }
                    name_set(_label);
                }
                else
                {
                    name_set(_who);
                }

                var _speed = 1;
                if (variable_struct_exists(_e, "speed")) _speed = real(_e.speed);

                if (!variable_struct_exists(_e, "text")) return;
                // Wrapping settings: story level (JSON "wrap" / "width"), with a
                // per line override.
                var _body = string(_e.text);
                var _do_wrap = global.mod_cs_wrap;
                var _w = global.mod_cs_width;
                if (variable_struct_exists(_e, "wrap")) _do_wrap = (_e.wrap != false);
                if (variable_struct_exists(_e, "width")) _w = real(_e.width);
                if (_do_wrap) _body = mod_cs_wrap_text(_body, _w);
                text(_body, _speed);
                break;

            case "clear":
                text_clear();
                break;

            case "wait":
                // The per-line await already handles pacing; nothing extra here.
                break;

            case "delay":
                // Timed pause: the following await turns into a timer.
                global.mod_cs_await_mode = 2;
                global.mod_cs_await_ms = 1000;
                if (variable_struct_exists(_e, "ms")) global.mod_cs_await_ms = real(_e.ms);
                global.mod_cs_wait_start = current_time;
                break;

            case "fullscreen":
                // The following await calls switch_to_fullscreen() until the full
                // screen box is ready; text() then routes into it automatically.
                global.mod_cs_await_mode = 4;
                break;

            case "fullscreen_end":
                global.mod_cs_await_mode = 5;
                break;

            case "bg":
                if (variable_struct_exists(_e, "value"))
                {
                    var _bg = mod_cs_sprite(_e.value);
                    if (_bg >= 0 && instance_exists(o_bg))
                    {
                        o_bg.sprite_index = _bg;
                        // Keep a plain background filling the screen when an HD
                        // multiplier is active (see the "resolution" case) and when
                        // the picture is an external file.
                        if (mod_cs_is_image_name(_e.value))
                        {
                            o_bg.highres = true;
                        }
                        else if (instance_exists(obj_resolution_handler) && obj_resolution_handler.scale_res > 1)
                        {
                            o_bg.highres = true;
                        }
                    }
                }
                break;

            case "bgm":
                if (variable_struct_exists(_e, "value"))
                {
                    var _bgm = mod_cs_sound(_e.value);
                    if (_bgm >= 0) play_bgm(_bgm);
                }
                break;

            case "se":
                if (variable_struct_exists(_e, "value"))
                {
                    var _se = mod_cs_sound(_e.value);
                    if (_se >= 0)
                    {
                        var _gain = 1;
                        if (variable_struct_exists(_e, "gain")) _gain = real(_e.gain);
                        play_se(_se, _gain);
                    }
                }
                break;

            case "bgm_gain":
                // Fades the running BGM to "to" (0 = silent, 1 = normal volume)
                // over "time" milliseconds. play_bgm() stores the instance.
                if (variable_global_exists("bgm") && audio_is_playing(global.bgm))
                {
                    var _to = 0;
                    var _tms = 1000;
                    if (variable_struct_exists(_e, "to")) _to = real(_e.to);
                    if (variable_struct_exists(_e, "time")) _tms = real(_e.time);
                    audio_sound_gain(global.bgm, _to * global.op_bgm_volume, _tms);
                }
                break;

            case "bgm_stop":
                if (variable_global_exists("bgm") && audio_is_playing(global.bgm))
                {
                    var _fade = 0;
                    if (variable_struct_exists(_e, "fade")) _fade = real(_e.fade);
                    if (_fade > 0) audio_sound_gain(global.bgm, 0, _fade);
                    else audio_stop_sound(global.bgm);
                }
                break;

            case "flash":
                var _fa = 1;
                var _fc = 16777215;
                var _ft = 30;
                if (variable_struct_exists(_e, "alpha")) _fa = real(_e.alpha);
                if (variable_struct_exists(_e, "color")) _fc = real(_e.color);
                if (variable_struct_exists(_e, "time")) _ft = real(_e.time);
                flash_screen(_fa, _fc, _ft);
                break;

            case "resolution":
                // Room render multiplier. 1 = vanilla (same as reset_resolution()),
                // higher lets big sprites stay sharp. Vanilla uses 4, 5 and 6.
                if (!instance_exists(obj_resolution_handler)) break;
                var _resv = 1;
                if (variable_struct_exists(_e, "value")) _resv = floor(real(_e.value));
                if (_resv <= 1)
                {
                    reset_resolution();
                }
                else
                {
                    set_resolution_multiplier(max(1, min(8, _resv)));
                }
                // Above 1x a normal background must be drawn stretched, otherwise
                // draw_self() paints it at native size and it only covers the
                // top-left 1/n of the room.
                if (_resv > 1 && instance_exists(o_bg)) o_bg.highres = true;
                break;

            case "highres":
                // o_bg draws draw_sprite_stretched(..., 320, 180) when this is on.
                if (instance_exists(o_bg))
                {
                    o_bg.highres = true;
                    if (variable_struct_exists(_e, "value")) o_bg.highres = (_e.value == true);
                }
                break;

            case "hidegui":
                // Hides the location / time / date HUD, as the vanilla CG scenes do.
                if (instance_exists(o_cutsceneConductor))
                {
                    o_cutsceneConductor.hideGui = true;
                    if (variable_struct_exists(_e, "value")) o_cutsceneConductor.hideGui = (_e.value == true);
                }
                break;

            case "cg":
                // One-step high resolution scene: multiplier + stretched background
                // + optional HUD hiding, i.e. exactly what the vanilla CG scenes do.
                if (variable_struct_exists(_e, "value"))
                {
                    var _cgspr = mod_cs_sprite(_e.value);
                    if (_cgspr >= 0)
                    {
                        var _cgres = 6;
                        if (variable_struct_exists(_e, "res")) _cgres = floor(real(_e.res));
                        if (instance_exists(obj_resolution_handler))
                        {
                            if (_cgres <= 1) reset_resolution();
                            else set_resolution_multiplier(max(1, min(8, _cgres)));
                        }
                        if (instance_exists(o_bg))
                        {
                            o_bg.highres = true;
                            o_bg.sprite_index = _cgspr;
                        }
                        if (variable_struct_exists(_e, "hidegui") && _e.hidegui == true && instance_exists(o_cutsceneConductor))
                        {
                            o_cutsceneConductor.hideGui = true;
                        }
                    }
                }
                break;

            case "video":
                // Full screen cutscene (mp4). The story waits for it: the await
                // that follows this step runs mod_cs_movie_done() (mode 6).
                if (variable_struct_exists(_e, "value"))
                {
                    global.mod_cs_movie_skippable = true;
                    if (variable_struct_exists(_e, "skippable")) global.mod_cs_movie_skippable = (_e.skippable != false);
                    var _cut = mod_cs_video_play(_e);
                    if (_cut != noone)
                    {
                        global.mod_cs_movie = _cut;
                        global.mod_cs_movie_start = current_time;
                        global.mod_cs_await_mode = 6;
                        // Same meaning as in the "cg" step: hide the location / time /
                        // date HUD (the author turns it back on with another step).
                        if (variable_struct_exists(_e, "hidegui") && _e.hidegui == true
                            && instance_exists(o_cutsceneConductor))
                        {
                            o_cutsceneConductor.hideGui = true;
                        }
                    }
                    else
                    {
                        // Say so in the textbox instead of failing silently; the
                        // await that follows is then a normal "confirm" one.
                        mod_cs_video_log("not found: " + mod_cs_str(_e.value));
                        name_set("");
                        text("`c{red}[video not found] `c{white}" + mod_cs_str(_e.value));
                    }
                }
                break;

            case "tint":
                // Vanilla idiom: set the tint colour, then fade its alpha.
                if (variable_struct_exists(_e, "value"))
                {
                    if (instance_exists(o_story_tint)) set_tint_color(real(_e.value));
                }
                if (instance_exists(o_story_tint))
                {
                    var _tf = 1;
                    var _tt = 0;
                    var _ttime = 0;
                    if (variable_struct_exists(_e, "from")) _tf = real(_e.from);
                    if (variable_struct_exists(_e, "to")) _tt = real(_e.to);
                    if (variable_struct_exists(_e, "time")) _ttime = real(_e.time);
                    fade_tint(_tf, _tt, _ttime);
                }
                break;

            case "fade":
                // Screen fade (scene transition). "to": 1 = cover the screen,
                // 0 = reveal it again. "wait": true makes the next await a timer
                // for the tween, so a scene can be swapped while hidden.
                //
                // "from" defaults to the CURRENT tint alpha, not to a fixed value:
                // a fade out followed by a fade in must continue from where the
                // previous one stopped, otherwise the second one jumps (0 -> 0
                // would snap the screen visible in a single frame).
                if (!instance_exists(o_story_tint)) break;
                if (variable_struct_exists(_e, "color")) set_tint_color(real(_e.color));

                var _df = o_story_tint.image_alpha;
                var _dt = 1;
                var _dtm = 30;
                if (variable_struct_exists(_e, "from")) _df = real(_e.from);
                if (variable_struct_exists(_e, "to")) _dt = real(_e.to);
                if (variable_struct_exists(_e, "time")) _dtm = real(_e.time);
                fade_tint(_df, _dt, _dtm);

                if (variable_struct_exists(_e, "wait") && _e.wait == true)
                {
                    global.mod_cs_await_mode = 2;
                    global.mod_cs_await_ms = (_dtm / 60) * 1000;
                    global.mod_cs_wait_start = current_time;
                }
                break;

            case "portrait":
                if (variable_struct_exists(_e, "who")) global.mod_cs_show_portrait(string(_e.who), _e);
                break;

            case "change":
                // Sprite swap in place - the JSON counterpart of the vanilla
                // "sat.change(sat_smile)". See mod_cs_change_expression.
                if (variable_struct_exists(_e, "who")) global.mod_cs_change_expression(string(_e.who), _e);
                break;

            case "bounce":
                // Standalone hop, the counterpart of the vanilla "sat.bounce()".
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone)
                    {
                        var _bmode = 1;
                        if (variable_struct_exists(_e, "mode")) _bmode = real(_e.mode);
                        _p.bounce(_bmode);
                    }
                }
                break;

            case "move":
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone)
                    {
                        var _mx = _p.x;
                        var _my = _p.y;
                        var _mt = 40;
                        var _mf = false;
                        if (variable_struct_exists(_e, "x")) _mx = real(_e.x);
                        if (variable_struct_exists(_e, "y")) _my = real(_e.y);
                        if (variable_struct_exists(_e, "time")) _mt = real(_e.time);
                        if (variable_struct_exists(_e, "flip")) _mf = (_e.flip == true);
                        move_portrait_object(_p, _mx, _my, _mt, _mf);
                    }
                }
                break;

            case "flip":
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone)
                    {
                        var _bounce = true;
                        if (variable_struct_exists(_e, "bounce")) _bounce = (_e.bounce != false);
                        _p.flip(_bounce);
                    }
                }
                break;

            case "portrait_fade":
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone)
                    {
                        var _pf = 1;
                        var _pt = 0;
                        var _ptm = 60;
                        if (variable_struct_exists(_e, "from")) _pf = real(_e.from);
                        if (variable_struct_exists(_e, "to")) _pt = real(_e.to);
                        if (variable_struct_exists(_e, "time")) _ptm = real(_e.time);
                        _p.alpha(_pf, _pt, _ptm);
                    }
                }
                break;

            case "hide":
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone) _p.visible = false;
                }
                break;

            case "show":
                if (variable_struct_exists(_e, "who"))
                {
                    _p = mod_cs_portrait_of(string(_e.who));
                    if (_p != noone) _p.visible = true;
                }
                break;

            case "portrait_clear":
                mod_cs_portrait_clear();
                break;

            case "narrator":
                if (variable_struct_exists(_e, "value")) name_set(string(_e.value));
                break;

            case "location":
                if (variable_struct_exists(_e, "value") && instance_exists(o_cutsceneConductor))
                {
                    o_cutsceneConductor.location = string(_e.value);
                }
                break;

            case "time":
                if (variable_struct_exists(_e, "value") && instance_exists(o_cutsceneConductor))
                {
                    o_cutsceneConductor.time = string(_e.value);
                }
                break;

            case "date":
                if (variable_struct_exists(_e, "value") && instance_exists(o_cutsceneConductor))
                {
                    o_cutsceneConductor.date = string(_e.value);
                }
                break;

            case "end":
            case "goto":
            case "abort":
                mod_cs_end();
                break;

            default:
                create_textbox();
                name_set("custom episode");
                text("unknown kind: " + _kind);
                break;
        }
    });
};

// Shows, moves or restyles the story portrait for character key _who.
//
// Portrait instances are tracked in global.mod_cs_portraits (key -> instance) so
// that later steps (move / flip / fade / hide) can address the same instance even
// though a coroutine lambda cannot see instance variables of its own object.
// Optional per-line overrides: portrait / expression / x / y / scale / facing.
// _spr_override lets the caller pass an already resolved sprite (the "change" step
// reuses this function to create a portrait that is not on screen yet).
global.mod_cs_show_portrait = function(_who, _e, _spr_override = -1)
{
    var _chars = global.mod_cs_chars;
    if (!variable_struct_exists(_chars, _who)) return;

    var _c = variable_struct_get(_chars, _who);

    var _spr = -1;
    if (!is_undefined(_spr_override) && _spr_override >= 0)
    {
        _spr = _spr_override;
    }
    else
    {
        var _spr_name = mod_cs_expression_name(_c, _e);
        if (_spr_name == "") return;
        _spr = mod_cs_portrait_sprite(_spr_name);
    }
    if (_spr < 0) return;

    var _x = 400;
    var _y = 140;
    var _scale = 0.14;
    var _facing = false;
    if (variable_struct_exists(_c, "x")) _x = real(_c.x);
    if (variable_struct_exists(_c, "y")) _y = real(_c.y);
    if (variable_struct_exists(_c, "scale")) _scale = real(_c.scale);
    if (variable_struct_exists(_c, "facing")) _facing = (_c.facing == true);
    if (is_struct(_e))
    {
        if (variable_struct_exists(_e, "x")) _x = real(_e.x);
        if (variable_struct_exists(_e, "y")) _y = real(_e.y);
        if (variable_struct_exists(_e, "scale")) _scale = real(_e.scale);
        if (variable_struct_exists(_e, "facing")) _facing = (_e.facing == true);
    }

    var _inst = mod_cs_portrait_of(_who);
    if (_inst != noone)
    {
        // Already on screen: restyle in place instead of popping a new instance.
        _inst.scale_port = _scale;
        _inst.facing_right = _facing;
        _inst.setPosition(_x, _y);
        _inst.change(_spr, true);
        _inst.visible = true;
        return;
    }

    _inst = create_portrait_object(_x, _y, _spr, _facing, _scale);
    variable_struct_set(global.mod_cs_portraits, _who, _inst);
};

/// Swaps the sprite of a portrait WITHOUT touching its position, scale or facing -
/// the counterpart of the vanilla "sat.change(sat_smile)".
///
/// In the stock scripts 1074 of 1258 .change() calls pass no second argument, so
/// "bounce" defaults to true; write "bounce": false for a silent swap. When the
/// character is not on screen yet the portrait is created instead (with the new
/// sprite, using the usual x / y / scale / facing rules), so a "change" step can
/// also be the first appearance of a character.
global.mod_cs_change_expression = function(_who, _e)
{
    if (!variable_struct_exists(global.mod_cs_chars, _who)) return;
    var _c = variable_struct_get(global.mod_cs_chars, _who);

    var _spr_name = mod_cs_expression_name(_c, _e);
    if (_spr_name == "") return;
    var _spr = mod_cs_portrait_sprite(_spr_name);
    if (_spr < 0) return;

    var _inst = mod_cs_portrait_of(_who);
    if (_inst == noone)
    {
        // Nothing on screen: behave like "portrait" so the expression shows up.
        global.mod_cs_show_portrait(_who, _e, _spr);
        return;
    }

    var _bounce = true;
    if (is_struct(_e) && variable_struct_exists(_e, "bounce")) _bounce = (_e.bounce != false);
    _inst.change(_spr, _bounce);
    _inst.visible = true;
};

    global.load_scene = global.mod_cs_run_pending;
    global.mod_cs_owns_load_scene = true;

    // o_cutsceneConductor only exists inside the story room, so it must not be
    // touched here (referencing it on the menu throws "Unable to find any
    // instance"). The story room creates it; location/time/date are set from the JSON lines.

    audio_stop_all();
    play_se(sfx_songsel_beginsong);
    room_goto(scene_story);
}

// o_mod_storyentry -- Create event, first lines added by the Custom Episodes Mod.
//
// o_mod_storyentry -- resident object of the Custom Episodes Mod.
// Created at game start by gml_GlobalScript_mod_customstory (persistent).
// Duties:
//   1. watch Shift+Enter on the main menu to open the story picker
//   2. handle picker navigation / confirm / cancel
//   3. drive JSON step playback inside scene_story
//
// Comments in this file are intentionally ASCII-only: a GML source file whose
// comments carry non-ASCII bytes can be mis-decoded by the code importer,
// which then fails to parse statements ("Expression floating outside of any
// statement").

mode = 0;                  // 0 = picker, 1 = playing a story
persistent = true;
depth = -999999;

menu_index = 0;
menu_items = [];
menu_open = false;
menu_lock_key = false;
menu_lock_frames = 0;          // confirm/cancel input gate, see menu_open_browser
menu_error = "";
menu_activate_request = 0;   // set by the button KeyPress events

mcs_last_room = room;          // room watched for "back on the main menu" resets

// True while global.load_scene holds our own entry function. Without this flag a
// session that ended through the pause menu (no cleanup) would save our builder
// as the "stock" value on the next entry and break the real story buttons.
global.mod_cs_owns_load_scene = false;

// Created here so that reading them can never throw ("Variable ... not set") in
// the Step event or in the coroutine cleanup paths. Existing values are kept.
if (!variable_global_exists("mod_cs_active")) global.mod_cs_active = false;
if (!variable_global_exists("mod_cs_pending")) global.mod_cs_pending = undefined;
if (!variable_global_exists("mod_cs_lines")) global.mod_cs_lines = [];
// Automatic text wrapping (see mod_cs_wrap_text) and the dialogue box width used
// for it; both are overridable per story and per line in the JSON.
if (!variable_global_exists("mod_cs_wrap")) global.mod_cs_wrap = true;
if (!variable_global_exists("mod_cs_width")) global.mod_cs_width = 308;
// Opening background / BGM and chapter label of the current episode.
if (!variable_global_exists("mod_cs_bg")) global.mod_cs_bg = "";
if (!variable_global_exists("mod_cs_bgm")) global.mod_cs_bgm = "";
// Await state shared between a step and the wait that follows it.
if (!variable_global_exists("mod_cs_await_mode")) global.mod_cs_await_mode = 0;
if (!variable_global_exists("mod_cs_await_ms")) global.mod_cs_await_ms = 0;
if (!variable_global_exists("mod_cs_wait_start")) global.mod_cs_wait_start = -1;
// Live portrait instances of the current story: character key -> instance id.
if (!variable_global_exists("mod_cs_portraits")) global.mod_cs_portraits = {};
// External images of the current episode: cache key (path#origin) -> sprite index,
// plus the bookkeeping behind the "missing image" and "debugimages" reports.
if (!variable_global_exists("mod_cs_images")) global.mod_cs_images = {};
if (!variable_global_exists("mod_cs_image_missing_map")) global.mod_cs_image_missing_map = {};
if (!variable_global_exists("mod_cs_image_missing")) global.mod_cs_image_missing = "";
if (!variable_global_exists("mod_cs_image_sizes")) global.mod_cs_image_sizes = "";
if (!variable_global_exists("mod_cs_debug_images")) global.mod_cs_debug_images = false;
if (!variable_global_exists("mod_cs_folder")) global.mod_cs_folder = "";
// External OGG streams of the current episode and their reporting fields.
if (!variable_global_exists("mod_cs_streams")) global.mod_cs_streams = {};
if (!variable_global_exists("mod_cs_audio_missing")) global.mod_cs_audio_missing = "";
if (!variable_global_exists("mod_cs_audio_sizes")) global.mod_cs_audio_sizes = "";
// Deferred release of the external images (see mod_cs_end) and the optional log.
if (!variable_global_exists("mod_cs_release_pending")) global.mod_cs_release_pending = false;
if (!variable_global_exists("mod_cs_debug_log")) global.mod_cs_debug_log = false;
// True when the episode could not be started; the queued coroutine steps check it.
if (!variable_global_exists("mod_cs_aborted")) global.mod_cs_aborted = false;
// Set while the picker or an episode owns the keyboard; consumed by o_newmenu.
if (!variable_global_exists("mod_cs_key_consumed")) global.mod_cs_key_consumed = false;

// In-chart story state (the "custom_episode" gimmick): see mod_cs_chart_tick().
// Created here so the Step event and the gimmick callback can never read an
// undefined global.
if (!variable_global_exists("mod_cs_chart_req")) global.mod_cs_chart_req = undefined;
if (!variable_global_exists("mod_cs_chart_active")) global.mod_cs_chart_active = false;
if (!variable_global_exists("mod_cs_chart_lines")) global.mod_cs_chart_lines = [];
if (!variable_global_exists("mod_cs_chart_chars")) global.mod_cs_chart_chars = {};
if (!variable_global_exists("mod_cs_chart_skipped")) global.mod_cs_chart_skipped = {};
if (!variable_global_exists("mod_cs_chart_missing")) global.mod_cs_chart_missing = "";
if (!variable_global_exists("mod_cs_chart_folder")) global.mod_cs_chart_folder = "";
if (!variable_global_exists("mod_cs_chart_file")) global.mod_cs_chart_file = "";
if (!variable_global_exists("mod_cs_chart_title")) global.mod_cs_chart_title = "";
if (!variable_global_exists("mod_cs_chart_index")) global.mod_cs_chart_index = 0;
if (!variable_global_exists("mod_cs_chart_deadline")) global.mod_cs_chart_deadline = 0;
if (!variable_global_exists("mod_cs_chart_step_dwell")) global.mod_cs_chart_step_dwell = 0;
if (!variable_global_exists("mod_cs_chart_dwell")) global.mod_cs_chart_dwell = 0;
if (!variable_global_exists("mod_cs_chart_typing")) global.mod_cs_chart_typing = false;
if (!variable_global_exists("mod_cs_chart_wait_trigger")) global.mod_cs_chart_wait_trigger = false;
if (!variable_global_exists("mod_cs_chart_step_sync")) global.mod_cs_chart_step_sync = false;
if (!variable_global_exists("mod_cs_chart_exit")) global.mod_cs_chart_exit = 0;
if (!variable_global_exists("mod_cs_chart_room")) global.mod_cs_chart_room = -1;
if (!variable_global_exists("mod_cs_chart_box")) global.mod_cs_chart_box = noone;
if (!variable_global_exists("mod_cs_chart_cc")) global.mod_cs_chart_cc = noone;
// Video cutscenes (step kind "video"): the running cutscene instances, their skip
// flags and the cache of sizes read out of the mp4 headers.
if (!variable_global_exists("mod_cs_movie")) global.mod_cs_movie = noone;
if (!variable_global_exists("mod_cs_movie_skippable")) global.mod_cs_movie_skippable = true;
if (!variable_global_exists("mod_cs_chart_movie")) global.mod_cs_chart_movie = noone;
if (!variable_global_exists("mod_cs_chart_movie_skip")) global.mod_cs_chart_movie_skip = false;
if (!variable_global_exists("mod_cs_chart_movie_uialpha")) global.mod_cs_chart_movie_uialpha = -1;
if (!variable_global_exists("mod_cs_movie_start")) global.mod_cs_movie_start = 0;
if (!variable_global_exists("mod_cs_movie_measured")) global.mod_cs_movie_measured = false;
if (!variable_global_exists("mod_cs_movie_started")) global.mod_cs_movie_started = false;
if (!variable_global_exists("mod_cs_movie_file")) global.mod_cs_movie_file = "";
if (!variable_global_exists("mod_cs_chart_created_box")) global.mod_cs_chart_created_box = false;
if (!variable_global_exists("mod_cs_chart_wrap")) global.mod_cs_chart_wrap = true;
if (!variable_global_exists("mod_cs_chart_width")) global.mod_cs_chart_width = 308;

// ---------------------------------------------------------------------------
// picker
// ---------------------------------------------------------------------------

menu_open_browser = function()
{
    menu_items = mod_cs_load_list();
    menu_index = 0;
    menu_error = "";
menu_activate_request = 0;   // set by the button KeyPress events
    menu_open = true;
    menu_lock_key = true;
    // Frames the confirm/cancel gate stays closed for at minimum, so a picker that
    // is opened and confirmed inside the same frame cannot slip through.
    menu_lock_frames = 6;
    menu_set_overlay_visible(false);

    // Freeze the stock main menu's own arrow/enter handling so that two input
    // handlers do not react to the same keypress. is_active is o_newmenu's gate.
    if (instance_exists(o_newmenu))
    {
        with (o_newmenu)
        {
            is_active = false;
        }
    }
    play_se(sfx_songsel_cursor);
};

menu_close_browser = function()
{
    menu_open = false;
    menu_set_overlay_visible(true);
    if (instance_exists(o_newmenu))
    {
        with (o_newmenu)
        {
            is_active = true;
        }
    }
    play_se(select);
};

// Objects the stock main menu draws around the button list. They are hidden
// while the picker is open, otherwise they overlap it: their GUI draw order
// does not follow plain depth in this build (verified empirically).
menu_set_overlay_visible = function(_on)
{
    var _objs = [o_newbanner, obj_mainmenuCharacter, o_ratingBox];
    for (var _i = 0; _i < array_length(_objs); _i++)
    {
        if (instance_exists(_objs[_i]))
        {
            with (_objs[_i])
            {
                visible = _on;
            }
        }
    }
};

// Draws the story picker. Called from o_newmainbutton_Draw_64, because a
// mod-created object's own Draw GUI event is never invoked by this build, and a
// normal Draw event would sit underneath the menu's GUI layer.
//
// The game renders on a 320x180 canvas (see update_window_size and
// obj_resolution_handler), so every coordinate here is in that space.
menu_draw_picker = function()
{
    if (!menu_open) return;

    var _w = 320;
    var _h = 180;
    if (room_width > 0) _w = room_width;
    if (room_height > 0) _h = room_height;

    // Dim the whole menu, then draw a centred panel.
    draw_set_alpha(0.82);
    draw_set_color(c_black);
    draw_rectangle(0, 0, _w, _h, false);
    draw_set_alpha(1);

    var _pw = _w - 20;
    var _ph = _h - 12;
    var _px = (_w - _pw) / 2;
    var _py = (_h - _ph) / 2;

    draw_set_color(c_black);
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(c_white);
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    draw_set_default();

    // Layout: header, list (5 rows), selection details (1 + 2 lines), error, hint.
    // Rows were reduced from 6 to 5 so the description always has room: anything
    // taller than the panel would be drawn outside the 320x180 canvas.
    var _rows = 5;
    var _row_h = 13;
    var _list_y = _py + 42;

    var _usable = 0;
    for (var _k = 0; _k < array_length(menu_items); _k++)
    {
        if (menu_items[_k].ok) _usable++;
    }

    draw_text_outlined(_px + 8, _py + 6, "CUSTOM EPISODES", c_white, c_black, 1);
    draw_text_outlined(_px + 8, _py + 20, "Custom Episodes/ : " + string(_usable) + " / " + string(array_length(menu_items)) + " ready", c_gray, c_black, 1);

    if (array_length(menu_items) <= 0)
    {
        // draw_text_outlined_wrap(x, y, text, tcol, ocol, sep, width) - seven
        // arguments only; an eighth would silently shift sep and overlap lines.
        draw_text_outlined_wrap(
            _px + 8, _list_y,
            "No episode found." + chr(10) + "Put story.json in:" + chr(10) + "Custom Episodes/<name>/",
            c_yellow, c_black, 12, _pw - 16);
    }
    else
    {
        var _first = 0;
        if (menu_index >= _rows) _first = menu_index - _rows + 1;

        for (var _r = 0; _r < _rows; _r++)
        {
            var _i = _first + _r;
            if (_i >= array_length(menu_items)) break;

            var _item = menu_items[_i];
            var _y = _list_y + (_r * _row_h);

            if (_i == menu_index)
            {
                draw_set_color(c_white);
                draw_rectangle(_px + 4, _y - 2, (_px + _pw) - 12, _y + 11, true);
            }

            var _label = mod_cs_str(_item.title);
            var _tcol = c_white;
            if (!_item.ok)
            {
                // Unusable entries stay visible so a missing or broken story.json
                // is obvious instead of the folder silently disappearing.
                _tcol = c_dkgray;
                if (mod_cs_str(_item.note) != "") _label = _label + "  [" + mod_cs_str(_item.note) + "]";
            }
            else if (_item.count > 0)
            {
                _label = _label + "  (" + string(_item.count) + ")";
            }
            // One line only: a long title must not run past the panel edge.
            draw_text_outlined(_px + 10, _y, menu_clip_text(_label, _pw - 26, 1), _tcol, c_black, 1);
        }

        // Scrollbar, only when the list does not fit into the window.
        var _track_y0 = _list_y - 2;
        var _track_y1 = _list_y + (_rows * _row_h) - 5;
        if (array_length(menu_items) > _rows)
        {
            var _track_h = _track_y1 - _track_y0;
            draw_set_color(c_dkgray);
            draw_rectangle(_px + _pw - 7, _track_y0, _px + _pw - 4, _track_y1, false);

            var _thumb_h = max(6, floor((_track_h * _rows) / array_length(menu_items)));
            var _max_first = max(1, array_length(menu_items) - _rows);
            var _thumb_y = _track_y0 + floor((_track_h - _thumb_h) * (_first / _max_first));
            draw_set_color(c_white);
            draw_rectangle(_px + _pw - 7, _thumb_y, _px + _pw - 4, _thumb_y + _thumb_h, false);
        }

        // Details of the highlighted entry: one line of author + step count, then
        // the optional "description" field, clipped to two lines.
        var _sel = menu_items[menu_index];
        var _info_y = _list_y + (_rows * _row_h) + 3;
        var _head = "";
        if (mod_cs_str(_sel.author) != "") _head = mod_cs_str(_sel.author);
        if (_sel.count > 0)
        {
            if (_head != "") _head += "   ";
            _head += string(_sel.count) + " steps";
        }
        if (_head != "") draw_text_outlined(_px + 8, _info_y, menu_clip_text(_head, _pw - 20, 1), c_gray, c_black, 1);

        var _desc = menu_clip_text(_sel.desc, _pw - 20, 2);
        if (_desc != "")
        {
            draw_text_outlined_wrap(_px + 8, _info_y + 11, _desc, c_silver, c_black, 11, _pw - 20);
        }
    }

    if (menu_error != "")
    {
        draw_text_outlined(_px + 8, _py + _ph - 24, menu_clip_text(menu_error, _pw - 16, 1), c_red, c_black, 1);
    }

    draw_text_outlined(_px + 8, _py + _ph - 12, "UP/DOWN  Enter play  ESC back", c_gray, c_black, 1);

    draw_set_alpha(1);
    draw_set_color(c_white);
};
menu_activate = function()
{
    if (array_length(menu_items) <= 0)
    {
        play_se(buzzer);
        return;
    }

    var _item = menu_items[menu_index];
    if (!_item.ok)
    {
        menu_error = "Cannot load this episode: " + mod_cs_str(_item.title);
        play_se(buzzer);
        return;
    }

    menu_open = false;
    // Claim the key press that started this episode, so the stock menu cannot also
    // act on it in the same frame (that would replace our room and leave the
    // textbox without its layer).
    global.mod_cs_key_consumed = true;
    global.mod_cs_aborted = false;
    mod_cs_begin(_item.folder);
};

/// Registers one chart gimmick name on behalf of this mod.
///
/// The vanilla API (addGlobalMod, mod_setup.gml) hands out indices below 128, which
/// is what obj_base_gimmick.updateMods() understands - both the stock version
/// (mi < 128) and the name based replacement that ships with the Custom Gimmicks
/// mod. Only when that table is exhausted the unlimited registry of that mod is
/// used as a fallback.
function mod_cs_register_chart_gimmick(_name, _callback)
{
    var _ok = false;
    try
    {
        addGlobalMod(_name, 0, _callback, undefined);
        _ok = true;
    }
    catch (_ex)
    {
        _ok = false;
    }

    if (!_ok)
    {
        // Fallback: the unlimited registry of the Custom Gimmicks mod, which is only
        // referenced after that mod announced itself in global.vml_mods.
        var _cg = false;
        try
        {
            _cg = (variable_global_exists("vml_mods") && is_struct(global.vml_mods)
                && variable_struct_exists(global.vml_mods, "custom_gimmicks_mod"));
        }
        catch (_ex2)
        {
            _cg = false;
        }
        if (_cg)
        {
            try
            {
                UnlimitedAddGlobalMod(_name, 0, _callback, undefined);
                _ok = true;
            }
            catch (_ex3)
            {
                _ok = false;
            }
        }
    }

    if (!_ok) mod_cs_always_log("chart", "could not register the " + string(_name) + " gimmick");
}

// ---------------------------------------------------------------------------
// In-chart story gimmicks
//
// Two names are registered, so a chart can drive a story by beat:
//
//     120,0,linear,_,_,custom_episode,-1          ; start, show step 1
//     128,0,linear,_,_,custom_episode_next,-1     ; advance one step
//
// In-chart dialogue is beat driven: a line stays on screen until the next
// "custom_episode_next" fires. A line with an explicit "dwell", or a story with a
// top level "chart_dwell", is a plain timer instead. See mod_cs_chart_next().
// ---------------------------------------------------------------------------
if (variable_global_exists("mods") && is_struct(global.mods))
{
    // These callbacks run with the gimmick object scope, so they may only touch
    // globals: each one just parks its request, the Step event does the rest.
    if (!struct_exists(global.mods, "custom_episode"))
    {
        var _cb_start = function(_start, _duration, _v1, _v2)
        {
            global.mod_cs_chart_req = { mode: 0, ms: _start, v1: _v1, v2: _v2 };
        };
        mod_cs_register_chart_gimmick("custom_episode", _cb_start);
    }

    if (!struct_exists(global.mods, "custom_episode_next"))
    {
        var _cb_next = function(_start, _duration, _v1, _v2)
        {
            global.mod_cs_chart_req = { mode: 1, ms: _start, v1: _v1, v2: _v2 };
        };
        mod_cs_register_chart_gimmick("custom_episode_next", _cb_next);
    }
}
