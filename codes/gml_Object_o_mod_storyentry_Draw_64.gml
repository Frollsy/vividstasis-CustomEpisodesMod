// o_mod_storyentry -- Draw GUI event.
//
// The only job of this event is measuring a running cutscene: o_movie_player
// draws the video with the vid_scale we handed it at creation (0.5 by default),
// and the one authoritative source for the video's real pixel size is the surface
// video_draw() returns. The first drawn frame therefore corrects the scale. See
// mod_cs_movie_measure().
//
// Comments in this file are intentionally ASCII-only. See the Create event.

if (!variable_global_exists("mod_cs_movie_measured")) exit;
mod_cs_movie_measure();
