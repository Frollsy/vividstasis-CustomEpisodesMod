Custom Episodes Mod - external audio folder
==========================================

Put your own .ogg files here (next to story.json or in any subfolder) and
reference them by relative path, for example:

    { "kind": "bgm", "value": "audio/theme.ogg" }
    { "kind": "se",  "value": "audio/door.ogg" }

Only OGG (Vorbis) works: the mod loads external audio with
audio_create_stream(), which the GameMaker manual documents as OGG only.
.wav / .mp3 / .m4a / .flac are reported as unsupported in the first
dialogue line of the episode.

Streams are created once when the episode starts and are stopped and freed
again when the episode ends, fails to start, or is left through the pause
menu. Sound effects and BGM commands (bgm_gain / bgm_stop) work with them.

Nothing is shipped in this folder on purpose - the mod itself cannot include
music. Drop your own file in and delete this note if you like.
