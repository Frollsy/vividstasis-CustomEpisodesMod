# 资产名清单（自动生成）

剧情 JSON 里的 `bg` / `bgm` / `se` / `portrait` / `color` 都要写**游戏内部的资产名**，
不能随便起名。这份清单是从游戏本体里提取出来的，可以直接复制。

> 生成方式：从游戏自己的脚本里收集 `o_bg.sprite_index = ...`、`create_portrait_object(...)`、
> `.change(...)`、`play_se(...)`、`play_bgm(...)` 的参数。清单之外还有更多名字（例如只在
> 某段剧情里用到的立绘差分），需要的话可以用 UndertaleModTool 打开 `data.win` 自己查。

---

## 一、背景（`bg` / `{"kind":"bg","value":"..."}`）

共 118 个，全部以 `bg_` 开头。常用的一批：

```
bg_bs_earthquake bg_bs_gate bg_bs_hub bg_bs_hub2 bg_bs_nowhere bg_dulles bg_e24_satalli
bg_magfest bg_nm_cafeteria bg_nm_exterior bg_nm_parking bg_placeholder bg_polyteaser bg_riverbed
bg_satapt395 bg_tg_allihouse bg_tg_e_geology_ext bg_tg_e_park_2 bg_tg_e_precinct_ext
bg_tg_geology_ext bg_tg_geology_int bg_tg_hospital_ceiling bg_tg_hospital_room bg_tg_park_1
bg_tg_park_2 bg_tg_precinct_cubi bg_tg_precinct_ext2 bg_tg_precinct_int bg_tg_terminal_int
bg_tk_airport_ext bg_tk_airport_int bg_tk_akiba bg_tk_alley bg_tk_alli_oldroom bg_tk_apt
bg_tk_apt_bathroom bg_tk_apt_bedroom bg_tk_arcade bg_tk_cafelax1 bg_tk_cafelax2
```

<details>
<summary>展开全部 118 个背景</summary>

```
bg_bs_earthquake bg_bs_gate bg_bs_hub bg_bs_hub2 bg_bs_nowhere bg_dulles bg_e24_satalli
bg_magfest bg_nm_cafeteria bg_nm_exterior bg_nm_parking bg_placeholder bg_polyteaser bg_riverbed
bg_satapt395 bg_tg_allihouse bg_tg_e_geology_ext bg_tg_e_park_2 bg_tg_e_precinct_ext
bg_tg_geology_ext bg_tg_geology_int bg_tg_hospital_ceiling bg_tg_hospital_room bg_tg_park_1
bg_tg_park_2 bg_tg_precinct_cubi bg_tg_precinct_ext2 bg_tg_precinct_int bg_tg_terminal_int
bg_tk_airport_ext bg_tk_airport_int bg_tk_akiba bg_tk_alley bg_tk_alli_oldroom bg_tk_apt
bg_tk_apt_bathroom bg_tk_apt_bedroom bg_tk_arcade bg_tk_cafelax1 bg_tk_cafelax2 bg_tk_e_arcade
bg_tk_e_gamestore bg_tk_e_shinjuku bg_tk_e_shinjuku2 bg_tk_e_sunrise_ext bg_tk_gamestore
bg_tk_ginza bg_tk_ginza_foodcourt bg_tk_ginza_st bg_tk_hachigrave bg_tk_hachigravepath
bg_tk_hachioji bg_tk_hachiojist bg_tk_ikealley bg_tk_ikebukuro bg_tk_ikepark bg_tk_kanshioffice
bg_tk_metro bg_tk_shinjuku bg_tk_sunrise_elev bg_tk_sunrise_ext bg_tk_sunrise_hall
bg_tk_sunrise_lobby bg_tk_sunrise_office bg_tk_sunrise_undg bg_un_dining bg_un_door bg_un_lounge
bg_wm_aboveshed bg_wm_airport_ext bg_wm_airport_int bg_wm_airport_movator bg_wm_apartment1
bg_wm_apartment3 bg_wm_beach bg_wm_bedroom bg_wm_blockedcave bg_wm_e_shrine bg_wm_ferry
bg_wm_ferrycafe bg_wm_ferrychiyo bg_wm_minami bg_wm_minamiapt bg_wm_minamihotel bg_wm_minamiport
bg_wm_minamiroad bg_wm_nightstreet bg_wm_ramenshop bg_wm_shrine bg_wm_shrinestairs
bg_wm_sunriselab bg_wm_undershrine sp_49bg_building sp_49bg_ikebukuro sp_49bg_library1
sp_49bg_library2 sp_79arg_h2bg sp_cg_ep46 sp_cg_ep47 sp_cg_ep48 sp_cg_ep49_1 sp_cg_ep49_2
sp_cg_ep49_3 sp_cg_ep50 sp_ch4_newintro_bg sp_hk_e_exthotel sp_hk_e_hallway sp_hk_e_hotelroom
sp_hk_e_inthotel sp_hk_e_sapporo sp_hk_e_sky sp_hk_exthotel sp_hk_inthotel sp_hk_inthotel2
sp_hk_sky sp_hk_soya sp_theatrebg sp_tint
```

</details>

命名规律：`bg_<地区>_<地点>`，例如 `bg_tk_ikebukuro`（池袋）、`bg_nm_cafeteria`（食堂）、
`bg_tg_precinct_int`（警局内部）。

### 高清背景 / CG（配合 `resolution` / `cg` 使用）

这些是大尺寸整屏画面，必须配合 `{"kind":"cg","value":"...","res":6}` 或 `resolution` + `highres` 才清晰（共 26 个）。

```
sp_49bg_building sp_49bg_ikebukuro sp_49bg_library1 sp_49bg_library2 sp_79arg_h2bg sp_cg_ep46
sp_cg_ep47 sp_cg_ep48 sp_cg_ep49_1 sp_cg_ep49_2 sp_cg_ep49_3 sp_cg_ep50 sp_ch4_newintro_bg
sp_hk_e_exthotel sp_hk_e_hallway sp_hk_e_hotelroom sp_hk_e_inthotel sp_hk_e_sapporo sp_hk_e_sky
sp_hk_exthotel sp_hk_inthotel sp_hk_inthotel2 sp_hk_sky sp_hk_soya sp_theatrebg sp_tint
```

---

## 二、立绘（`portrait` / `{"kind":"portrait","portrait":"..."}`）

共 220 个差分，按角色前缀分组。

### `sat2_*`（37 个）

```
sat2_angry_1 sat2_happy_1 sat2_happy_2 sat2_happy_3 sat2_happy_4 sat2_joy_1 sat2_joy_3
sat2_joy_4 sat2_neutral_1 sat2_neutral_2 sat2_neutral_3 sat2_pissed_3 sat2_pissed_4 sat2_sad_1
sat2_sad_3 sat2_sad_5 sat2_shock_2 sat2_shock_4 sat2_shock_5 sat2_sigh_2 sat2_sigh_3
sat2_smile_4 sat2_talk_3 sat2_talk_4 sat2_talk_5 sat2_unamuse_1 sat2_unamuse_2 sat2_unamuse_3
sat2_whuh_1 sat2_whuh_4 sat2_whuh_5 sat2_wonder_2 sat2_wonder_3 sat2_wonder_5 sat2_worry_2
sat2_worry_3 sat2_worry_5
```

### `tsuki_*`（33 个）

```
tsuki_angry_1 tsuki_angry_2 tsuki_angry_3 tsuki_angry_4 tsuki_angry_5 tsuki_happy_2
tsuki_happy_3 tsuki_happy_4 tsuki_happy_5 tsuki_neutral_1 tsuki_neutral_2 tsuki_neutral_3
tsuki_neutral_4 tsuki_neutral_5 tsuki_shock_1 tsuki_shock_2 tsuki_shock_3 tsuki_shock_4
tsuki_shock_5 tsuki_unamused_1 tsuki_unamused_2 tsuki_unamused_3 tsuki_unamused_4
tsuki_unamused_5 tsuki_upset_1 tsuki_upset_2 tsuki_upset_3 tsuki_upset_4 tsuki_worry_1
tsuki_worry_2 tsuki_worry_3 tsuki_worry_4 tsuki_worry_5
```

### `alli_*`（29 个）

```
alli_angry alli_bash alli_frustrated alli_fu_bash alli_hd_angry alli_hd_bash alli_hd_frustrated
alli_hd_neutral alli_hd_sad alli_hd_surprise alli_hd_talking alli_hd_worried alli_hd_yawn
alli_hu_angry alli_hu_frustrated alli_hu_neutral alli_hu_sad alli_hu_smug alli_hu_surprise
alli_hu_talking alli_hu_worried alli_hu_yawn alli_neutral alli_sad alli_smug alli_surprise
alli_talking alli_worried alli_yawn
```

### `kot_*`（26 个）

```
kot_ad_cloudy kot_ad_defeated kot_ad_neutral kot_ad_panic kot_ad_pissed kot_ad_smile
kot_ad_unamused kot_ad_wonder kot_au_cloudy kot_au_neutral kot_au_panic kot_au_pissewd
kot_au_smile kot_au_surprised kot_bashful kot_cloudy kot_defeated kot_excited kot_hh_neutral
kot_neutral kot_panic kot_pissed kot_smile kot_surprised kot_unamused kot_wonder
```

### `dawn_*`（22 个）

```
dawn_hd_gloom dawn_hd_happy dawn_hd_happy2 dawn_hd_neutral dawn_hd_neutral2 dawn_hd_neutral3
dawn_hd_smile dawn_hd_whuh dawn_hd_wink dawn_hd_wonder dawn_hd_worry dawn_hu_gloom dawn_hu_happy
dawn_hu_happy2 dawn_hu_neutral dawn_hu_neutral2 dawn_hu_neutral3 dawn_hu_smile dawn_hu_whuh
dawn_hu_wink dawn_hu_wonder dawn_hu_worry
```

### `st_*`（18 个）

```
st_hm_1 st_hm_2 st_hm_3 st_laugh_1 st_laugh_2 st_laugh_3 st_neutral_1 st_neutral_2 st_neutral_3
st_smile_1 st_smile_2 st_smile_3 st_unamuse1_1 st_unamuse1_2 st_unamuse1_3 st_unamuse2_1
st_unamuse2_2 st_unamuse2_3
```

### `sat_*`（17 个）

```
sat_angry sat_bashful sat_frown sat_happy sat_happy_2 sat_neutral sat_overjoy sat_pissed
sat_pissed_2 sat_raised sat_raised_2 sat_smile sat_smug sat_soft sat_soft_2 sat_speak sat_think
```

### `eri_*`（14 个）

```
eri_flinch eri_flinch_hu eri_happy eri_happy_2 eri_neutral eri_neutral2 eri_neutral2_hu
eri_neutral_hu eri_pissed eri_pissed_hu eri_silly eri_smile eri_upset eri_upset_hu
```

### `kanshi_*`（13 个）

```
kanshi_eyeclosed_au kanshi_eyeclosed_hd kanshi_eyeclosed_hu kanshi_happy_au kanshi_happy_hu
kanshi_neutral_au kanshi_smile_hu kanshi_squint_hd kanshi_squint_hu kanshi_talking_au
kanshi_talking_hd kanshi_talking_hu kanshi_unamused_hd
```

### `chiyo_*`（11 个）

```
chiyo_alert chiyo_confused chiyo_happy chiyo_joy chiyo_neutral chiyo_pissed chiyo_shock
chiyo_smile chiyo_surprise chiyo_unamused chiyo_worried
```

命名规律：`<角色>_<表情>[_<服装/版本>]`，例如 `sat_neutral`、`sat_frown`、
`kot_ad_panic`、`alli_hu_talking`、`tsuki_angry_3`。没有列出的差分可以直接照规律猜，
写错名字不会崩，但那个立绘会被静默跳过。

---

## 三、BGM（`bgm` / `play_bgm`）

共 63 个。

```
_2024intro_loop _2024mainmenu _2025intro_loop acolyte_finaltama_2 arcade_reward_loop
ast_bg_audio bgm_list bgs_story_beach bgs_story_birds bgs_story_birds_eq bgs_story_earthquake
bgs_story_exterior_people bgs_story_fire bgs_story_interior_people bgs_story_interior_room
bgs_story_night bgs_story_rain bgs_story_road bgs_story_shinjuku bgs_story_underground carousel
clair_de_lune computerbuzz do_new enemies flowloop_1_true flowloop_2_true flowloop_3_true
flowloop_4_true flowloop_5_true fragile moonlit music music_story_allison music_story_allison2
music_story_ambientstopmotion music_story_catstory music_story_ch3_episode_22
music_story_ch3_eri_gun music_story_ch4_dawnbetray music_story_ch4_dawnbetray2
music_story_ch4_intervention music_story_ch4_punch music_story_ch4_tsuki
music_story_ch5_apocalypse music_story_ch5_conversation music_story_ch5_darkness
music_story_ch5_neutral music_story_ch5_relevation music_story_duskbreaker music_story_kanshi
music_story_worldkeeper nothingness_second_loop plaudite_cyc_p plaudite_cyc_u plaudite_cyc_v
preview_generic renaintro self_interlude sysmusic_cyberpunks_login sysmusic_green_menu
sysmusic_purple victory
```

---

## 四、音效（`se`）

游戏里通过 `play_se()` 播放的名字共 46 个，其中 `sfx_` 开头的是最安全的常用音效：

```
sfx_failsong sfx_note_hit sfx_results_tick_v2 sfx_solve_puzzle sfx_songsel_beginsong
sfx_songsel_cursor sfx_songsel_cursorOLD sfx_songsel_diff sfx_songsel_keys sfx_songsel_select
sfx_songsel_selectOLD sfx_songsel_sweep sfx_startsong_2024 sfx_startsong_new sfx_tvo_activate
sfx_view_log sfx_wc_ready sfx_wc_unready
```

其它可用音效：

```
burst_intervention_for_cherry buzzer carpass coin1 collapse1 critical cursor cursor235 damage1
damage2 flame forceSound grandfinish gunshot hammer miss notesnd_1 notesnd_3 select shatterfx
shift shiftreverse slash1 snd_atick splash1 textsnd victory wrong
```

---

## 五、文字调色（`c{...}`）

```
red  white  aqua  think  black  dawn  wkeeper  sat
alli  tsuki  setsuki  kisho  chiyo  kot  eri  miri
```

用法：`` `c{red}红色文字`c{white} `` —— 记得用 `` `c{white} `` 或 `` `r `` 调回来。
