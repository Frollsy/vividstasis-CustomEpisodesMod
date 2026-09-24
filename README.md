# 自定义剧情模组（Custom Episodes Mod）

给 `vivid/stasis` 加一个**从外部文件夹读取剧情文本**的模组：主界面按住 **Shift 再按 Enter**，
会弹出一个选择器，选择 `Custom Episodes/` 下的任意一段剧情并用游戏原版文本框播放。

> **给剧情作者看的文档在 [`docs/写作手册.md`](docs/写作手册.md)**，
> 配套的资产名清单在 [`docs/asset-names.md`](docs/asset-names.md)。
> 本 README 面向"要改模组代码的人"：讲实现、讲踩过的坑、讲怎么验证。

- 不改动任何原版剧本、不写 `story_progress`、不动 `node.vsd` / `global.story_events`
- 完全独立、可随时删除：删掉 `mods/custom_episodes/` 并还原 `data.win` 即恢复原状

---

## 一、安装

本模组已经放在 build 版 VML 的 mods 目录下：

```
E:\customstories\vsml014\
├── vividstasisModLoader.exe
├── path.json                # {"game_path":"D:\\Steam\\steamapps\\common\\vividstasis", ...}
└── mods\
    ├── Custom Gimmicks v1.12.7\
    ├── Custom Songs Mod Test\
    └── custom_episodes\     ← 本模组
        ├── codepatches.json
        ├── codes\
        ├── raw\
        └── README.md
```

安装步骤：

1. 确认 `path.json` 里的 `game_path` 指向你的游戏目录（当前为 `D:\Steam\steamapps\common\vividstasis`）
2. 双击 `vividstasisModLoader.exe` 正常打一次 mod
3. 启动游戏 → 主界面按住 **Shift** 再按 **Enter**

VML 会把 `raw/Custom Episodes/_example/story.json` 投递到**游戏目录**的
`Custom Episodes/_example/story.json`。之所以要放游戏目录：GML 的 `file_text_open_read`
只能读游戏目录下的相对路径。

> **装完之后要写新剧情，不需要再打一次 mod。** 直接在游戏目录的 `Custom Episodes/` 下新建文件夹
> 放 `story.json` 即可，选择器每次打开都会重新扫描列表。

> **本模组可以重复打而不出问题。** 它只新增代码条目、不改任何原版条目，
> 重复执行时 VML 底层的 `FindOrCreateCodeEntry` 会命中已有条目而不是再建一份，
> 不会像"插入型"补丁那样越打越长。

---

## 二、写一段剧情

在**游戏目录**创建：

```
Custom Episodes/
└── 我的剧情/            ← 文件夹名随意，选择器按文件夹名排序
    └── story.json
```

### 最小示例

```json
{
  "title": "显示在选择器里的标题",
  "bg": "bg_tg_precinct_int",
  "bgm": "bgs_story_road",
  "characters": {
    "saturday": { "display_name": "Saturday", "color": "c_aqua", "portrait": "sat_neutral", "x": 350, "y": 140 }
  },
  "lines": [
    { "kind": "narration", "text": "这是旁白。" },
    { "who": "saturday", "text": "这是 Saturday 说的。" },
    { "kind": "end" }
  ]
}
```

### 顶层字段

| 字段 | 必填 | 说明 |
|---|---|---|
| `title` | 否 | 选择器里显示的标题，缺省用文件夹名 |
| `author` | 否 | 选择器下方显示的作者 / 来源 |
| `description` | 否 | 选择器下方显示的简介（自动折行到剩余空间） |
| `bg` | 否 | 开场背景，**精灵资产名**（如 `bg_tg_precinct_int`） |
| `bgm` | 否 | 开场 BGM，**声音资产名**（如 `bgs_story_road`） |
| `episode_name` | 否 | 章节标签，会写进 `global.last_episode_name`（影响暂停界面显示） |
| `characters` | 否 | 角色表，供 `who` 引用 |
| `lines` | **是** | 步骤数组，见下 |
| `wrap` / `width` | 否 | 整篇的换行设置，见"换行与排版" |

### characters 里的字段

| 字段 | 说明 |
|---|---|
| `display_name` | 名字框里显示的名字，缺省用 key 本身 |
| `color` | **名字框颜色**，必须是 GameMaker 颜色常量（`c_aqua` / `c_orange` / `c_red` …） |
| `portrait` | 立绘**精灵资产名**（如 `sat_neutral`、`sat_frown`、`sat_think`、`sat_raised`） |
| `x` / `y` | 立绘坐标，缺省 400 / 140 |
| `scale` | 立绘缩放，缺省 `0.14`（原版剧情用的就是这个量级） |
| `facing` | `true` = 朝右（原版里的 `facing_right`），缺省 `false` |

### lines 支持的 kind

| `kind` | 说明 |
|---|---|
| 省略 或 `line` | 对白：`who` 指定角色 key（省略 = 无名字），`text` 是正文，可选 `speed`（1 = 原版速度，越小越慢）、`wrap` / `width` |
| `narration` | 与 `line` 相同，只是可读性更好 |
| `clear` | 清空文本框 |
| `wait` | 等玩家按确认（`text` 已经播完的前提下），不显示新文本 |
| `delay` | 定时等待，`ms` = 毫秒（`{ "kind": "delay", "ms": 800 }`） |
| `fullscreen` | 切到原版**全屏文本框**（信件 / 日记 / 大段独白），之后的对白自动进全屏框 |
| `fullscreen_end` | 退出全屏文本框，回到普通对话框 |
| `bg` | 换背景，`value` = 精灵资产名 |
| `bgm` | 换 BGM，`value` = 声音资产名 |
| `bgm_gain` | 当前 BGM 音量渐变到 `to`（0 = 静音，1 = 原音量），`time` = 毫秒 |
| `bgm_stop` | 停止 BGM，可选 `fade` = 淡出毫秒数 |
| `se` | 播一个音效，`value` = 声音资产名，可选 `gain`（1 = 原音量） |
| `flash` | 闪屏：`alpha`（缺省 1）、`color`（缺省 16777215 = 白）、`time`（帧） |
| `tint` | 设置剧情色调，`value` = 颜色常量；可选 `from` / `to` / `time` 做渐变 |
| `fade` | **黑屏转场**：`to` 1 = 淡到色幕、0 = 淡回画面，`color`（0 = 黑）、`time`（帧）、`wait`（true = 淡完才继续）。`from` **默认接当前透明度**，所以"淡出→换背景→淡入"不需要自己写 `from` |
| `resolution` | 房间渲染倍率：`value` 1 = 原版（等同 `reset_resolution()`），原版剧情用过 4 / 5 / 6；被限制在 1~8。倍率 > 1 时会自动把 `o_bg.highres` 打开，否则普通背景只占屏幕左上角 1/n |
| `highres` | `o_bg.highres`：`true` = 背景按 `draw_sprite_stretched(..., 320, 180)` 拉伸铺满，`false` = `draw_self()` 按原尺寸 |
| `hidegui` | `o_cutsceneConductor.hideGui`：隐藏左上角地点 / 时间 / 日期 |
| `cg` | 一条完成高清画面（等价原版 CG 段落的写法）：`value` = 大图资产名，可选 `res`（缺省 6）、`hidegui` |
| `portrait` | 显示 / 更新立绘，`who` = 角色 key，可覆盖 `portrait` / `expression` / `x` / `y` / `scale` / `facing`；已有同角色立绘时会**重新定位** |
| `change` | **只换表情**（等价原版 `sat.change(sat_smile)`）：保持位置 / 缩放 / 朝向。写法 `who` + `portrait` 或 `expression`，可选 `bounce`（缺省 true；原版 1074/1258 次调用都是单参数）。角色还没上场时会按 `portrait` 的规则先创建出来 |
| `bounce` | 只做一次弹跳（等价原版 `sat.bounce()`）：`who` + 可选 `mode`（1 从下弹起 = 缺省，2 从上落下） |
| `move` | 立绘移动：`who`、`x`、`y`、`time`（帧，缺省 40）、`flip`（移动时是否翻身） |
| `flip` | 立绘翻身，`who`，可选 `bounce`（缺省 true） |
| `portrait_fade` | 立绘透明度渐变：`who`、`from`（缺省 1）、`to`（缺省 0）、`time`（帧，缺省 60） |
| `hide` / `show` | 隐藏 / 重新显示某个立绘，`who` |
| `portrait_clear` | 移除本模组创建的全部立绘 |
| `narrator` | 直接设置名字框文本，`value` = 字符串 |
| `location` | 设置左上角地点，`value` = 字符串 |
| `time` | 设置左上角时间，`value` = 字符串 |
| `date` | 设置左上角日期，`value` = 字符串 |
| `end` / `goto` / `abort` | 结束剧情，返回主界面 |

> **精灵名字段支持外部图片**：`bg` / `cg` 的 `value`、`portrait`（含角色表里的 `portrait`）只要以
> `.png` / `.jpg` / `.jpeg` / `.gif` 结尾，就按**剧集文件夹里的图片文件**处理（相对路径），否则查游戏资产。
> 运行时由 `sprite_add` 读成精灵、缓存、在剧集结束时 `sprite_delete`；进剧集前会预加载，
> 读不出来的会在第一句对白里报 `[image not found]`。顶层 `"debugimages": true` 会打印每张图的像素尺寸。
> 实现入口：`mod_cs_is_image_name` / `mod_cs_image_file` / `mod_cs_load_image` / `mod_cs_preload_images` /
> `mod_cs_sprite` / `mod_cs_portrait_sprite` / `mod_cs_free_images`。

### 换行与排版

原版引擎**只在空格处折行**（`TextDrawer.parse()` 的 `" "` 分支），这就是官方中文版正文里到处是手塞空格
（例如"探索 这座城市"）的原因：中日文没有空格，一整句会被当成一个超长单词，直接顶出对话框。

本模组在交给原版文本框之前自己算断行，两种方式可以混用：

| 方式 | 写法 | 说明 |
|---|---|---|
| 自动换行（默认开） | 什么都不用写 | 按对话框宽度（**308 像素**，即 `obj_textboxHandler` 的 `setBounds(10, 308)`）逐字测量并插入换行符。中日文不再需要空格；西文优先在最后一个空格处断开，不会把单词劈两半；收尾标点（`。，、！？：；）》」` 等）不会被挤到行首 |
| 手动换行 | `"第一行\n第二行"` | JSON 里的 `\n` 就是真正的换行符，原版 `TextDrawer` 遇到它直接换行 |

逐行 / 整篇开关：

```json
{
  "wrap": false,
  "width": 380,
  "lines": [
    { "kind": "narration", "text": "这一行按默认设置自动换行。" },
    { "kind": "narration", "wrap": false, "text": "这一行不自动换行，完全交给原版引擎。" },
    { "kind": "narration", "width": 160, "text": "这一行按 160 像素排版。" },
    { "kind": "narration", "text": "这一行手动断行：\n从这里另起一行。" }
  ]
}
```

| 字段 | 位置 | 说明 |
|---|---|---|
| `wrap` | 顶层 / 单行 | `false` 关闭自动换行（默认 `true`） |
| `width` | 顶层 / 单行 | 自动换行的宽度，单位像素（默认 `308`；原版矢量字体模式是 `378`） |

> 自动换行只在**测量用的宽度**上做文章，正文一个字符都不会增删，标点、转义码都原样保留。

### 推进节奏（delay）

原版剧本里大部分对白都是"打完等按键"，本模组保持一致；需要纯定时等待时用 `delay`：

```json
{
  "lines": [
    { "kind": "narration", "text": "这一句要按键才继续。" },
    { "kind": "delay", "ms": 1200 },
    { "kind": "narration", "text": "上面那个 delay 是纯定时等待，不需要文本。" }
  ]
}
```

| 字段 | 位置 | 说明 |
|---|---|---|
| `ms` | `delay` 步骤 | 定时等待的毫秒数 |

> 原版的"文字打完自动跳、不等按键"（`check_textbox_done_auto`）没有接入：等真的有剧本需要再补。

### 正文里的富文本标记

`text` 最终仍由游戏自己的 `TextDrawer` 渲染，所以原版标记全部可用：

- 调色：`` `c{red} ``、`` `c{white} ``、`` `c{aqua} ``、`` `c{think} ``、`` `c{black} ``、`` `c{dawn} ``、
  `` `c{wkeeper} ``、`` `c{sat} ``、`` `c{alli} ``、`` `c{tsuki} ``、`` `c{setsuki} ``、`` `c{kisho} ``、
  `` `c{chiyo} ``、`` `c{kot} ``、`` `c{eri} ``、`` `c{miri} ``
- 效果：`` `e{wave} ``（波浪）、`` `e{jitter} ``（抖动）、`` `e{rcolor} ``（彩闪），`` `e{normal} `` 还原
- 还原全部标记：`` `r ``
- 想显示一个反引号本身：写成两个反引号 ``` `` ```

换完颜色后如果后面还有别的颜色，记得手动切回去（例如用 `` `c{white} ``）。
注意：`` `c{...} `` 里的名字是**文字调色板**，和 `characters` 里的 `color` 不是一回事——
后者的值必须是 GameMaker 颜色常量（`c_aqua` 这种）。

---

## 三、行为与限制

- **入口**：主界面 Shift+Enter。选择器打开时主菜单会被冻结（`is_active = false`），ESC 返回时恢复
- **按键**：↑/↓ 选择、Enter 播放、ESC 返回。Enter/ESC 用的是玩家在设置里绑定的 `global.menu_confirm` / `menu_cancel`
- **字体**：对白走游戏原版 textbox，使用 `global.default_font`，因此**跟随玩家的字体设置**、含完整中文字形
- **资产名写错不会崩**：开场会先校验 `bg` / `bgm` / 角色的 `color` 与 `portrait`，
  有问题的会先在对话框里列出来再继续；`lines` 里未知的 `kind` 也会在对话框里报出来
- **进度隔离**：不进 `story_progress`、不解锁成就、不写存档；进入前后会保存并恢复
  `global.load_scene` 与 `global.last_episode_name`
- **已知限制（第一版）**：
  - 没有立绘移动/淡入淡出指令（`move` / `alpha` 未实现）
  - 没有分支选项与条件判断
  - 不支持 `speed` 以外的逐字控制
  - 结束后返回**主界面**，不会回到流程图
  - `<script>.sp` 那种旧式剧本文件格式**没有**接入，本模组只用 JSON

---

## 四、文件结构

```
mods/custom_episodes/
├── codepatches.json                                  # 空数组：不需要改任何原版代码
├── codes/
│   ├── gml_Object_o_mod_storyentry_Create_0.gml       # 状态、全部逻辑、自动换行
│   ├── gml_Object_o_mod_storyentry_Step_0.gml         # 入口探测 / 选择器输入 / 剧情推进
│   ├── gml_Object_o_mod_storyentry_KeyPress_120.gml   # F9 调试快捷键
│   ├── gml_Object_o_newmainbutton_Step_0.gml          # 主界面按钮：惰性创建对象 + Shift+Enter 入口
│   ├── gml_Object_o_newmainbutton_KeyPress_13.gml     # Enter   → 选择器确认
│   ├── gml_Object_o_newmainbutton_KeyPress_27.gml     # ESC     → 选择器取消
│   ├── gml_Object_o_newmainbutton_Draw_64.gml         # 把选择器画在按钮之上
│   └── gml_Object_o_newmenu_Step_0.gml                # 选择器 / 播放期间拦住原版菜单
├── docs/
│   ├── 写作手册.md                                    # 【给剧情作者】完整写作文档
│   └── asset-names.md                                 # 资产名清单（背景/立绘/BGM/音效）
└── raw/
    └── Custom Episodes/_example/
        ├── story.json                                 # 可直接跑的示例剧集
        └── images/                                    # 自定义图片示例（运行时 sprite_add 加载）
            ├── demo_cg.png
            └── demo_portrait.png
```

> `docs/` 只是随模组分发的文档，VML 不会投递它（只有 `raw/` 会被投递到游戏目录）。

## 五、改完剧情后的自查

工作区根目录有一个校对工具，依据 `dump_v2`（从 `data.win` 提取的全部 GML）判断
你写的资产名是不是真实存在的：

```bat
node E:\customstories\verify-story-mod.mjs all
```

它做四件事：

1. **示例 story.json** —— JSON 语法 + `bg` / `bgm` / 角色 `color` / `portrait` 是否都是真实资产名
2. **mod 代码标识符** —— 所有函数调用与资产引用是否都有定义来源（拼错会在这里被抓住）
3. **结构初始化顺序** —— 状态变量是否先初始化再使用
4. **游戏目录部署状态** —— 游戏目录是否存在、`raw/` 有没有投递成功、`data.win` 与备份的大小

也可以单独跑某一项，例如只查部署状态：

```bat
node E:\customstories\verify-story-mod.mjs game
```

改了你自己的剧情后，把脚本里的 `EXAMPLE` 常量指向你的 `story.json` 就能复用第 1 项。

## 六、关于 codepatches

模组**几乎不需要** `codepatches`：

`codes/` 里以 `gml_GlobalScript_` 开头且**原本不存在**的文件名，会被 VML 底层的
UndertaleModTool `CodeImportGroup` 自动创建成 GlobalScript 并挂进 `GlobalInitScripts`，
其中的 `function` 声明会注册为全局函数。所以模组的挂载点是**新条目**而不是
`initiategame`，完全不依赖原版代码内容。

`codes/` 里以 `gml_Object_o_mod_storyentry_*` 命名的文件会**自动创建新对象**并绑定事件，
这是 VML 唯一能新建对象的方式（专门给这个对象创一个 `objects/*.json` 壳是多余的）。

### 唯一的一条 codepatch：中途退出剧情要回主界面

原版暂停菜单的第二个按钮是"返回节点流程"，退出时执行 `next_room = scene_eventline`
（节点流程图）。自定义剧集是从主界面进入的，所以退出应该回主界面。这里用一条**定点替换**
比整条目覆盖稳得多（游戏更新后如果那行变了，patch 只是不生效，不会破坏别的逻辑）：

```json
[
  {
    "Entry": "gml_Object_o_story_pause_Step_0",
    "Find": "next_room = scene_eventline;",
    "Value": "next_room = scene_eventline; if (variable_global_exists(\"mod_cs_active\") && global.mod_cs_active) next_room = scene_mainmenu;",
    "Type": 1
  }
]
```

- `Type 1` = 只替换第一处匹配；`Type 0` = 替换全部；`Type 2/3` = 在函数后插入
- 条件里带 `variable_global_exists`，因为这段代码理论上可能在模组对象创建之前执行
- 只判断"当前是不是我们的剧集"，**原版剧情的退出行为完全不变**
- Step 事件里还有一层**兜底**：万一这条 patch 将来不再匹配（例如游戏更新改了那行），
  房间变化复位会在发现落到 `scene_eventline` 时改跳主界面

> VML 的 `Type 2/3`（在函数后插入）在**空 `Function`** 时是插到条目**末尾**而不是开头，
> 所以"在开头加逻辑"不能靠 codepatch，得整条目覆盖 —— 本模组覆盖的那 5 个原版事件就是这个原因。

---

## 七、踩过的坑（写给以后改这个模组的人）

这些坑是我实测确认的，不是推测。

### 1. `story` 不能作为变量名

编译器（Underanalyzer）**拒绝**把 `story` 当裸标识符使用：

```gml
story = undefined;      // ✗ Compile error:
                        //   Expression floating outside of any statement
                        //   Failed to find a valid statement
```

但它在结构体成员位置是合法的（游戏自己的代码里就有 `tnode.story = ...`）。
同样地 `player` 也改掉了（虽然它作为局部变量是合法的，为稳妥起见一并改名）。

**所以本模组统一用 `mod_cs_*`（全局）与 `mcs_*`（对象实例变量）前缀。** 新增变量名请沿用这两套前缀。

注意这类报错的**行号不可信**：报的是解析器放弃的位置，不是真正的出错点。上面那条语句
在 460 行的文件里被报成"第 23 行"，在单行文件里被报成"第 1 行"——同一个错误。

### 2. 对象事件名的 `EventType` 必须在白名单内

`gml_Object_{对象}_{事件类型}_{子类型}.gml` 里的事件类型只认：

```
Create Destroy Alarm Step Collision Keyboard Mouse Other
Draw KeyPress KeyRelease Trigger CleanUp Gesture PreCreate
```

表外的（例如 `User`）会直接报 `Failed to parse object code entry name`。
**结论：`codes/` 无法新建 User Event（自定义事件）。**

### 3. 文件格式要求

四个 `.gml` 必须是 **CRLF 行尾、无 BOM、纯 ASCII 注释**：

- CRLF：与能正常编译的第三方模组一致（`Custom Gimmicks` 就是 CRLF）
- 纯 ASCII 注释：注释里的非 ASCII 字节有被误解码的风险，不值得赌
- `story.json` **不受此限**——它是数据，由游戏自己按 UTF-8 读取，中文完全正常

改完代码后建议先跑自查：

```bat
node E:\customstories\verify-story-mod.mjs all
node E:\customstories\gml-lint.mjs <改过的.gml>
```

`verify-story-mod.mjs` 会检查裸 LF / BOM / 事件类型白名单 / 资产名 / 标识符定义；
`gml-lint.mjs` 检查括号与引号是否配对。

### 4. 协程里的函数读不到任何实例变量（最容易翻车的一条）

剧情播放走游戏原生协程（`__CoroutineBegin/Then/Await/End`，由 `oCoroutineManager` 驱动）。
**协程引擎执行排队进来的函数时，会把 `self` 换成协程实例（`__CoroutineRootClass`）**，
于是：

- 步骤函数里读 `o_mod_storyentry` 的实例变量 → `Variable __CoroutineRootClass.xxx not set`
- `method(o_mod_storyentry, function() {...})` 的绑定**在这里不起作用**（实测报错还是指向协程类）
- 连"外层函数的局部变量"也读不到（`_lines` 那次报错就是因为这个）

**结论：协程里的函数只能读 `global.*`、内建函数、以及显式写出的实例引用
（`o_bg.sprite_index`、`obj_storyportrait`、`global.mod_cs_portraits` 里存的实例）。**

所以播放状态全部走全局：

| 全局 | 作用 |
|---|---|
| `global.mod_cs_step_index` | 当前步骤号。**步骤自己 +1**，不能靠循环变量：循环在步骤执行前就跑完了，闭包会全部读到最后一个值 |
| `global.mod_cs_await_mode` / `_await_ms` / `_wait_start` | 下一步"等什么"：按键 / 自动推进 / 定时 / 全屏切换。由**上一步**设置，由**下一次等待**读取 |
| `global.mod_cs_portraits` | 角色 key → 立绘实例，供 `move` / `flip` / `portrait_fade` / `hide` 使用 |

### 5. 从暂停菜单退出不会走我们的收尾代码

暂停界面退出时，游戏只调用 `coroutine.取消()`，协程末尾的 `_end` **根本不会执行**。
结果是 `mode` 停在 1、`global.load_scene` 还是我们的入口函数。所以：

- Step 事件用**房间变化**判断"回到主界面了"，在那时复位 `mode` 并 `mod_cs_restore_globals()`
- `global.mod_cs_owns_load_scene` 记录 `load_scene` 是不是我们装的：只有不是我们装的才保存原值，
  否则一次中途退出会把我们自己的函数当成"原版值"存下来，之后**原版剧情按钮也会被劫持**

### 6. 同一个按键事件会在同一帧被读两次

Shift+Enter 打开选择器的同一帧，`keyboard_check_pressed(vk_enter)` 对整帧都为真，
选择器会立刻确认并进入剧情。修法：选择器带一道**确认/取消闸门**——
打开后至少 6 帧、且 Enter / Z / Shift 全部抬起之前，忽略确认与取消（方向键不受限制），
同时把按钮 `KeyPress` 事件塞进来的 `menu_activate_request` 清零。

### 6b. `o_newmenu.is_active` 不可信，锁菜单必须锁在自己手里

原版菜单读的是 `input_check_pressed(Value_4)`，也就是**和选择器同一个确认键**，它只靠自己的
`is_active` 决定是否处理输入。而 `is_active` 不是我们能独占的：多个原版窗口在关闭时会把它设回
`true`（`obj_ratingWindow_Step_0`、`obj_charscreen_window_Alarm_0`、`obj_charscreen_window` 等），
所以"进入剧情的同时原版按钮也被按下"这种偶发冲突是必然会发生的——它会 `activate()` 掉当前选中的
按钮（例如打开节点流程图），把我们的房间换掉，随后协程里的 `create_textbox()` 找不到
`"Textbox"` 层，`name_set()` 直接报
`Unable to find any instance for object index '529' name 'o_textbox'` 崩溃。

现在的做法是**不依赖 `is_active`**，直接在我们覆盖的 `o_newmenu_Step_0` 顶部拦：

1. `global.mod_cs_key_consumed` 为真 → `exit`，并**在这里清零**（不再在按钮的 Step 里每帧清），
   这样两个事件谁先跑都不影响；配合 `menu_activate()` 主动置位，启动剧情的这一帧原版菜单必被跳过
2. `o_mod_storyentry.menu_open`（选择器开着）或 `o_mod_storyentry.mode == 1`（剧情启动/播放中）→ `exit`

另外 `_begin` 里加了保险：`create_textbox()` 之后若 `o_textbox` 仍不存在，就置
`global.mod_cs_aborted`、收尾并安全返回（后续排队步骤见到这个标志直接空转），
而不是在 `name_set()` 里崩掉整个游戏。

### 7. 全屏文本框下 `textbox_exists()` 是假

`switch_to_fullscreen()` 内部已经 `text_clear()` 掉了普通文本框，所以等待条件不能写成
`if (!textbox_exists()) return true;`（会直接跳过等待），必须额外判断
`instance_exists(o_fullscreen_textbox)`。

### 8. 文本引擎的几个事实

- `TextDrawer` **只在空格处折行**，所以中文需要自己插 `\n`（本模组已自动做）
- `TextDrawer` 的 `"\n"` 是硬换行；`` `c{颜色} `` / `` `e{效果} `` / `` `r `` 是内联标记
- 对话框宽度 308 像素（`setBounds(10, 308 + (70 * is_vector))`），行距 10
- `create_textbox()` 必须在 `name_set()` / `text()` 之前调用，否则 `o_textbox` 还不存在
- `o_cutsceneConductor` 只在剧情房间存在，主界面上引用它会 `Unable to find any instance`

### 9. 目录枚举与小工具

- GameMaker 没有列目录函数；`file_find_first(path, 0)` **只返回文件**，
  要目录得用属性过滤 **16**（Win32 `FILE_ATTRIBUTE_DIRECTORY`）
- 这个 build 的编译器**不认 `fa_directory` 这个常量**（游戏代码里从未出现），只能用 16
- `debug()` 在本作是空实现，控制台没有任何输出；诊断只能靠屏幕上画字或写文件

### 9b. 具名函数必须声明在事件顶层（嵌套声明不是全局函数）

`function foo() {...}` 写在**事件顶层**时是全局函数，任何作用域都能调用；
但如果它写在**另一个函数体内**（大括号深度 > 0），那么在别的顶层函数里调用 `foo(...)`
会被编译器当成**实例变量调用**，运行时报
`Variable <当前对象>.foo not set`。

真实踩过：`mod_cs_expression_name` / `mod_cs_portrait_of` / `mod_cs_portrait_clear` 原本写在
`mod_cs_begin` 体内（这个函数从第 677 行一直延伸到第 1565 行，很容易把新函数"顺手写进去"），
于是 `mod_cs_preload_images` 调用它们时崩在 `o_cutsceneConductor` 上——因为载入器是由
`o_cutsceneConductor` 的 Create 事件经 `script_load_scene` 调用的，那时候 `self` 是它。

规则：

- **新增具名函数一律写在顶层辅助函数区**（`mod_cs_trim` / `mod_cs_wrap_text` 那一片）
- 需要"运行期才准备好"的函数，就用顶层区的 `global.名字 = function() {...}` 赋值，
  并且调用处**必须带 `global.` 前缀**（`global.mod_cs_show_portrait(...)`、`global.mod_cs_make_step()`）；
  这类函数目前的调用点已全部核对过，没有裸调用
- 检查脚本：`node check-scope.mjs <gml>`（有嵌套声明就会列出并返回非 0）

### 9c. 批量替换调用点时小心"自己调用自己"
一次批量替换把 `mod_cs_release_episode()` 函数体里的 `mod_cs_reset_resolution()` 也一起换掉了，
结果这个函数第一句就是 `mod_cs_release_episode();` —— **无条件自递归**，游戏执行到剧情 `end`
时直接卡死（窗口"未响应"），而语法检查、括号配平、臆造函数审计全都毫无反应。

- 现在有专门的检查脚本：`node check-recursion.mjs <gml...>`（会报"无条件自递归"）
- 批量替换（正则）之后，**必须**回头看一眼被替换的函数体本身有没有被误伤
- 同类症状（游戏"未响应"而不是弹出 Code Error 对话框）优先怀疑死循环/自递归，
  崩错对话框才怀疑变量未定义

### 9d. 外部图片用到的 API 与释放顺序

- `sprite_add()` / `sprite_delete()` / `sprite_set_offset()` / `sprite_prefetch()` 在这个 build
  是**确实可用**的：游戏自己就在用（`obj_presence_Other_70` 用它读 Steam 头像、
  `o_newstore_Draw_64` 调 `sprite_set_offset`、`obj_base_gimmick_Draw_75` 调 `sprite_delete`）
- `sprite_delete()` 之前**必须先解除引用**：`o_bg.sprite_index` 会一直指向那张外部图直到房间真正切换，
  而删精灵发生在切换之前、当前帧还要绘制一次。所以 `mod_cs_end()` 只 `reset_resolution()`
  并置 `global.mod_cs_release_pending`，真正的 `mod_cs_free_images()` 放到 Step 事件下一帧执行
  （`mod_cs_free_images()` 内部也做了兜底：先解引用、再按索引从高到低删除，
  防止 `sprite_delete` 重排动态精灵索引）
- `sprite_add()` 每次调用都会占用一张纹理，同一张图必须缓存（`global.mod_cs_images`），
  剧集结束时释放

### 10. VML 的 `mods/` 目录不能为空

VML 每次修补都先**用 `backup/` 里的原版 `data.win` 覆盖**再逐个应用 `mods/<目录>`。
如果 `mods/` 里一个目录都没有，它会安静地保存一份**纯原版**——所有补丁消失
（`data.win` 从 2,640.9 MB 变回 2,636.9 MB 就是信号）。
**移动/整理 mods 目录时用 Move 而不是 Remove。**

### 11. 改这个文件请用编辑工具，不要用 PowerShell 数组

PowerShell 变量名**不分大小写**，`$L` 和 `$l` 是同一个变量：

```powershell
$L = New-Object System.Collections.Generic.List[string]
foreach ($l in $lines) { $L.Add($l) }   # ✗ $l 把 $L 覆盖成字符串，文件被写成 2 字节
```

已经被这条坑掉过一次（995 行的源文件被覆盖成 2 字节）。用 `edit` 工具或 Node 脚本，
或者至少把临时变量名换成 `$buf` / `$line`。

## 八、兼容性：本模组覆盖 / 修改了哪些原版代码

游戏更新后，下面这些**整条目覆盖**的写法可能丢掉新版本的行为，需要重新从
`data.win` dump 出来同步：

| 文件 | 原版行为 |
|---|---|
| `gml_Object_o_newmainbutton_Step_0.gml` | 只处理 `alpha_obfuscate`；本模组加了惰性创建 + Shift+Enter 入口 |
| `gml_Object_o_newmainbutton_Draw_64.gml` | 原版按钮绘制；本模组在末尾追加选择器绘制 |
| `gml_Object_o_newmainbutton_KeyPress_13.gml` / `_27.gml` | 原版无这两个事件，是模组新增的输入通道 |
| `gml_Object_o_newmenu_Step_0.gml` | 原版菜单输入；本模组在开头加了 `global.mod_cs_key_consumed` 与选择器/播放状态的判断 |

另外有一条**定点 codepatch**（不改整条目，见第六节）：

| 条目 | 修改 |
|---|---|
| `gml_Object_o_story_pause_Step_0` | 在 `next_room = scene_eventline;` 后面追加一句：当前是本模组的剧集时改去 `scene_mainmenu` |

这条 patch 失配时不会报错（VML 找不到 `Find` 就跳过），后果只是"中途退出去节点流程图"，
所以 Step 事件里留了兜底跳转。

选择器绘制之所以挂在按钮的 `Draw_64` 上，是因为**本 build 不会调用模组新建对象的
Draw GUI 事件**，而且主菜单 UI 都在 GUI 层、不按 depth 排序 —— 挂在按钮的绘制事件里
才能盖在菜单之上。同一原因，选择器打开时要手动隐藏 `o_newbanner` /
`obj_mainmenuCharacter` / `o_ratingBox`。

另外：本模组的正文用的是**游戏自己的字体**，所以中文显示依赖你安装的中文字体补丁
（原版 `fnt_monacovs` / `fnt_phosphor` 没有中日文字形）。

---

## 九、谱面内调用剧情（gimmick `custom_episode`）

作者视角的用法写在 `docs/写作手册.md` 第 13 节；这里是实现要点。

### 原版依据

原版谱面内剧情（`obj_memories_gimmick` / `obj_supernova_gimmick` / `obj_libertia_gimmick`）
的做法是：

- 在 gimmick 对象的 Create 里 `addExtraMod("setup_co", method(self, function(){ coroutine = ss_memories(); }))`，
  谱面（`.vsm`）在指定 beat 写 `setup_co`，到点就走 `obj_base_gimmick.updateMods()`
  → `cc.CreateChartCallback(start, cb, duration, v1, v2, ease)`，**回调签名是 `(start, dur, v1, v2, ease)`**；
  `CleanUp_0` 里取消协程
- 剧情本体不切房间：`instance_create_depth(0,180,-70,o_textbox)` + `name_set()` + `text()` +
  `text_clear()`，用 `__CoroutineAwait(function(){ return c_play(秒); })` 按歌曲时间推进

文字引擎（`Dialogue_Box_Handling`）是全局函数、**任何房间都能用**：`text()` 会自己在
`Textbox_Text` 层建 `obj_textboxHandler`（层不存在就 `layer_create(-134, ...)`），
`name_set()` 只要求存在 `o_textbox` 实例。所以谱面内播对白不需要自己写文字引擎。

注意 `create_textbox()` **不能**在谱面里用：它用 `instance_create_layer(..., "Textbox")`，
而游玩房间没有这个层；原版和我们都用 `instance_create_depth(..., -70, o_textbox)`。

### 本模组怎么做

- 注册：`o_mod_storyentry` 的 Create 末尾用**原版** `addGlobalMod("custom_episode", 0, cb, undefined)`
  （`mod_setup.gml`，索引 0..127，已用 66 个）。回调只写全局变量 `global.mod_cs_chart_req`；
  只有原版表用满时才回退到 Custom Gimmicks 的 `UnlimitedAddGlobalMod`。
  这个入口已在公开仓库核对过（2026-08-20 的 `main`）：
  <https://github.com/vivid-stasis-revival/Custom-Gimmicks-Mod> 的
  `codes/gml_GlobalScript_init_customgmk.gml`（`lastIdx` 从 129 起）与
  `codepatches/updateMod.gml`（自定义曲按名字解析），两者与本地 `vsml014` 里的副本逐字节相同
- 解析：作者在 `.vsm` 里写 `beat,dur,ease,_,_,custom_episode,-1` 即可。Custom Songs Mod 的
  `load_text_mods()` 会把 `ms.ig` 设成 `struct_exists(global.mods, 名字)`，而 Custom Gimmicks Mod 的
  `codepatches/updateMod.gml` 把 `obj_base_gimmick.updateMods()` 换成了按名字解析（只对自定义曲生效），
  未注册的名字**静默跳过**、不会崩
- 演奏：Step 事件每帧调用 `mod_cs_chart_tick()`（`mod_cs_chart_start/step/stop` 是同级具名函数，
  全部声明在**事件顶层**，见第七节 9b）。文字框用 `instance_create_depth(0,180,-70,o_textbox)`，
  时间用 `cc.currentms`（跟着歌曲暂停/重开），步骤只支持 `line`/`narration`/`narrator`/`clear`/
  `wait`/`delay`/`se`/`bgm_gain`/`bgm_stop`/`end`；其它 kind 用 `mod_cs_chart_note()` 记进
  `Custom Episodes/_modlog.txt`（这条日志是无条件写的，作者没法给谱面内剧情开 `debuglog`）
- **帧率**：`cc_Create_0` 在谱面房间执行 `global.gamefps = …; game_set_speed(global.gamefps, …)`，
  这台机器 `fpscap=9` → **1000 fps**（剧情房间固定 60）。所以动画/计时一律不能写死帧数：
  滑入滑出用 `mod_cs_chart_frames(秒)` 换算（原版 `ss_memories` 也是用 `global.gamefps` 当帧数），
  台词停留用 `cc.currentms`（毫秒），打字速度缺省给 0.5（`obj_textboxHandler` 的
  time source 是 `0.01 / char_speed` 秒/字，即 100×speed 字/秒）
- **位置**：谱面内文字框停在 **y=132**（`ss_memories` / `ss_supernova` 的值）；剧情房间的
  `create_textbox()` 用的是 122，两者别混
- 剧本位置：`global.currentSongInfo.chart_path`（Custom Songs Mod 的 `readCustomSongInfo()` 写入）
  + `story.json`；`.vsm` 里的 `!story: xxx.json` 可以覆盖（`!` 键值对都落在 `cc.mods.data`）
- 音频：`mod_cs_audio_file()` 在谱面内模式改成相对**谱面文件夹**解析，所以谱面内剧情可以带自己的 `.ogg`

### 实机踩到的坑（都已修）

1. **`global.skip` / `global.story_paused` / `global.textbox` 不存在**
   `obj_textboxHandler` 的 Step 第一行就是 `if (!global.skip)`，而这两个全局是**原版谱面 gimmick 自己在
   Create 里设的**（`obj_memories_gimmick_Create_0.gml:8-9`）。谱面房间没人设过 → 文字框出来那一帧就崩
   `global variable name 'skip' index (100309) not set`。`textbox_exists()` 又直接读 `global.textbox`
   （只由 `text()` 赋值），收尾时同样会炸。现在 `mod_cs_chart_start()` 会先补齐这三个（只在缺失时写）
2. **帧率**：`cc_Create_0` 在谱面房间 `game_set_speed(global.gamefps, …)`，本机 `fpscap=9` → 1000 fps
   （剧情房间固定 60）。写死 60 帧的滑入 = 0.06 秒，看起来"框瞬间弹到终点"；打字机也按最快档跑。
   现在一律用 `mod_cs_chart_frames(秒)` 换算，打字缺省 `speed = 0.5`
3. **文字框位置**：谱面内停在 **y=132**（`ss_memories` / `ss_supernova` 的值）；剧情房间的
   `create_textbox()` 用 122，照抄会偏高
4. **快重开（restart 键）后剧情不再出现**
   `cc_Step_1:18` 的重开是 `room_restart()`：**房间和 room 索引都不变**，只是重建一个 `cc`。
   原来的判断（`room` 变了 / `cc` 不存在）都不成立，于是 `global.mod_cs_chart_active` 一直是 true，
   第二次触发被 `if (!active …)` 吞掉。现在 `mod_cs_chart_start()` 记 `global.mod_cs_chart_cc = cc`，
   tick 里多比一个 `cc != global.mod_cs_chart_cc`；并且**新触发会先停掉正在播的剧情**（不再丢弃请求）

### 还没验证过的点

`gml-lint` / `check-recursion` / `check-scope` / `audit-calls` / `check-manual` 和 VML 编译都过，实机也跑过
触发、播放、收尾、快重开；还没专门测的是：

1. `bgm_gain` / `bgm_stop` 在谱面内作用于 `global.bgm`（可能就是歌曲本身），没有实机验证
2. 名字框（`who` + `characters.display_name`）在谱面内的绘制分支（`o_textbox_Draw_64` 会读
   `global.story_progress` / `global.profile_titles_map`）—— 测试剧本里已经放了一句
3. 多条 gimmick 触发互相覆盖、以及 `!story:` 覆盖路径


