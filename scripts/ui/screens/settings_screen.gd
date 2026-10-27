extends Control
## Settings: team colors, audio, gameplay, creative (test) mode and the danger zone.
## Every change goes through Game.set_setting(), which saves and emits settings_changed.

var _holder: MarginContainer
var _colors_box: VBoxContainer
var _creative_box: VBoxContainer
var _local_pending := false  # true while this screen itself is changing a setting
var _refresh_queued := false


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_holder = MarginContainer.new()
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(_holder)
	Game.settings_changed.connect(_on_settings_changed)
	_build()


func _on_settings_changed() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_deferred_refresh")


func _deferred_refresh() -> void:
	_refresh_queued = false
	if _local_pending:
		# Our own control changed something: only colors/creative sections depend on it.
		_fill_colors()
		_fill_creative()
	else:
		_build()


## Marks the settings_changed emissions of the next frame as caused by this screen.
func _mark_local() -> void:
	_local_pending = true
	get_tree().process_frame.connect(func(): _local_pending = false, CONNECT_ONE_SHOT)


## Changes a setting from one of this screen's own controls.
func _apply(key: String, value) -> void:
	_mark_local()
	Game.set_setting(key, value)


func _build() -> void:
	for ch in _holder.get_children():
		ch.queue_free()
	var col := UIKit.vbox(14)
	col.custom_minimum_size = Vector2(820, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_holder.add_child(col)
	col.add_child(UIKit.title("Settings", 30, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))

	# ---- Colors
	var cp := _section(col, "Team Colors")
	_colors_box = UIKit.vbox(10)
	cp.add_child(_colors_box)
	_fill_colors()

	# ---- Audio
	var ap := _section(col, "Audio")
	ap.add_child(_slider_row("Master", "master_volume"))
	ap.add_child(_slider_row("Music", "music_volume"))
	ap.add_child(_slider_row("Effects", "sfx_volume"))
	ap.add_child(_toggle("Mute all", "mute"))

	# ---- Gameplay
	var gp := _section(col, "Gameplay")
	var diffs: Array = []
	for d in Game.DIFFICULTIES:
		diffs.append(str(d))
	gp.add_child(_option_row("Bot difficulty", diffs, "bot_difficulty"))
	var lengths: Array = []
	for s in Game.MATCH_LENGTHS:
		lengths.append("%d:%02d + %d:%02d overtime" % [int(s) / 60, int(s) % 60, Game.OVERTIME_SECONDS / 60, Game.OVERTIME_SECONDS % 60])
	gp.add_child(_option_row("Match length", lengths, "match_length"))
	gp.add_child(_toggle("Damage numbers", "damage_numbers"))
	gp.add_child(_toggle("Screen shake", "screen_shake"))
	gp.add_child(_toggle("Fullscreen", "fullscreen"))

	# ---- Creative
	var crp := _section(col, "Creative Mode (Test Mode)")
	_creative_box = UIKit.vbox(10)
	crp.add_child(_creative_box)
	_fill_creative()

	# ---- Danger zone
	var dp := _section(col, "Danger Zone", UIKit.CORAL)
	var dl := UIKit.label("Deletes your progress, creative save and settings. This cannot be undone.", 16, UIKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dp.add_child(dl)
	var rb := UIKit.button("Reset all saves", UIKit.CORAL, 20, Vector2(240, 50))
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rb.pressed.connect(func():
		UIKit.confirm(self, "Delete ALL saves and settings? Your cards, Seeds, Sunshards and stats will be lost.",
			"Reset everything", func():
				Game.reset_all_saves()
				UIKit.toast(self, "All saves reset", UIKit.GOLD), true))
	dp.add_child(rb)


# ------------------------------------------------------------------ sections

func _section(parent: Control, title_text: String, accent: Color = UIKit.GOLD) -> VBoxContainer:
	var p := UIKit.panel(UIKit.PANEL, 16, 16)
	parent.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	v.add_child(UIKit.label(title_text, 22, accent, true))
	return v


func _fill_colors() -> void:
	for ch in _colors_box.get_children():
		ch.queue_free()
	var pc := int(Game.settings.player_color) % Game.TEAM_PALETTE.size()
	var ec := int(Game.settings.enemy_color) % Game.TEAM_PALETTE.size()
	if ec == pc:
		ec = (ec + 1) % Game.TEAM_PALETTE.size()
	_colors_box.add_child(UIKit.label("Your color: " + str(Game.TEAM_PALETTE[pc].name), 17, UIKit.CREAM, true))
	_colors_box.add_child(_swatch_row(pc, -1, true))
	_colors_box.add_child(UIKit.label("Opponent color: " + str(Game.TEAM_PALETTE[ec].name), 17, UIKit.CREAM, true))
	_colors_box.add_child(_swatch_row(ec, pc, false))
	var prev := UIKit.hbox(14)
	_colors_box.add_child(prev)
	var board := PreviewBoard.new()
	board.player_col = Game.TEAM_PALETTE[pc].color
	board.enemy_col = Game.TEAM_PALETTE[ec].color
	board.custom_minimum_size = Vector2(300, 84)
	prev.add_child(board)
	var pl := UIKit.vbox(2)
	pl.alignment = BoxContainer.ALIGNMENT_CENTER
	pl.add_child(UIKit.label("Preview", 14, UIKit.MUTED, true))
	pl.add_child(UIKit.label("Left: you   Right: opponent", 15, UIKit.CREAM))
	prev.add_child(pl)


func _swatch_row(selected_idx: int, blocked_idx: int, is_player: bool) -> Control:
	var row := UIKit.hbox(10)
	for i in Game.TEAM_PALETTE.size():
		var sw := Swatch.new()
		sw.idx = i
		sw.col = Game.TEAM_PALETTE[i].color
		sw.selected = i == selected_idx
		sw.blocked = i == blocked_idx
		sw.tooltip_text = str(Game.TEAM_PALETTE[i].name) + (" (used by you)" if sw.blocked else "")
		sw.custom_minimum_size = Vector2(60, 50)
		sw.picked.connect(_pick_player_color if is_player else _pick_enemy_color)
		row.add_child(sw)
	return row


func _pick_player_color(i: int) -> void:
	var old := int(Game.settings.player_color)
	if i == old:
		return
	if i == int(Game.settings.enemy_color):
		_apply("enemy_color", old)  # swap so the two teams never share a color
	_apply("player_color", i)


func _pick_enemy_color(i: int) -> void:
	if i == int(Game.settings.player_color):
		Sfx.play("error")
		return
	_apply("enemy_color", i)


func _fill_creative() -> void:
	for ch in _creative_box.get_children():
		ch.queue_free()
	var cb := CheckButton.new()
	cb.text = "Creative mode"
	cb.add_theme_font_size_override("font_size", 20)
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = Game.is_creative()
	cb.toggled.connect(func(on: bool):
		_mark_local()
		Game.set_creative_mode(on))
	_creative_box.add_child(cb)
	var info := UIKit.label("Separate save with every card at max level and unlimited Seeds and Sunshards. Your normal progress is kept safe.",
		16, UIKit.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creative_box.add_child(info)
	if Game.is_creative():
		_creative_box.add_child(_toggle("Infinite Sunlight in battle", "creative_infinite_energy"))


# ------------------------------------------------------------------ rows

func _toggle(text: String, key: String) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = text
	cb.add_theme_font_size_override("font_size", 20)
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(Game.settings.get(key, false))
	cb.toggled.connect(func(on: bool): _apply(key, on))
	return cb


func _slider_row(text: String, key: String) -> Control:
	var row := UIKit.hbox(14)
	var lab := UIKit.label(text, 19, UIKit.CREAM, true)
	lab.custom_minimum_size = Vector2(110, 0)
	row.add_child(lab)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = float(Game.settings.get(key, 0.5))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 28)
	row.add_child(s)
	var pct := UIKit.label("%d%%" % roundi(s.value * 100.0), 18, UIKit.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(56, 0)
	row.add_child(pct)
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % roundi(v * 100.0)
		_apply(key, v))
	return row


func _option_row(text: String, items: Array, key: String) -> Control:
	var row := UIKit.hbox(14)
	var lab := UIKit.label(text, 19, UIKit.CREAM, true)
	lab.custom_minimum_size = Vector2(160, 0)
	row.add_child(lab)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(260, 42)
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 19)
	for it in items:
		ob.add_item(str(it))
	ob.select(clampi(int(Game.settings.get(key, 0)), 0, items.size() - 1))
	ob.item_selected.connect(func(i: int): _apply(key, i))
	row.add_child(ob)
	return row


# ------------------------------------------------------------------ inner classes

## Clickable palette swatch.
class Swatch extends Control:
	signal picked(i: int)
	var idx := 0
	var col := Color.WHITE
	var selected := false
	var blocked := false
	var hovered := false

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hovered = true
			queue_redraw())
		mouse_exited.connect(func():
			hovered = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(idx)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var border := UIKit.GOLD if selected else (UIKit.CREAM if hovered else col.darkened(0.45))
		UIKit.style(col if not blocked else col.darkened(0.55), 12, border, 4 if selected else 3).draw(get_canvas_item(), r)
		if selected:
			var c := size * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-10, 0), c + Vector2(-3, 8), c + Vector2(11, -8)]),
				UIKit.INK, 5.0, true)
		if blocked:
			var c2 := size * 0.5
			draw_line(c2 + Vector2(-9, -9), c2 + Vector2(9, 9), UIKit.CREAM, 4.0)
			draw_line(c2 + Vector2(-9, 9), c2 + Vector2(9, -9), UIKit.CREAM, 4.0)


## Tiny arena mock-up showing the two team colors side by side.
class PreviewBoard extends Control:
	var player_col := Color.GREEN
	var enemy_col := Color.PURPLE

	func _draw() -> void:
		var cols := 10
		var rows := 4
		var tw := size.x / cols
		var th := size.y / rows
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.PANEL_DARK)
		for y in rows:
			for x in cols:
				var col := player_col if x < cols / 2 else enemy_col
				var shade := 0.0 if (x + y) % 2 == 0 else 0.12
				draw_rect(Rect2(x * tw + 1, y * th + 1, tw - 2, th - 2), col.darkened(shade))
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.INK, false, 3.0)
