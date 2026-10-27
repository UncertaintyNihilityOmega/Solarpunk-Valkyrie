extends Control
## App shell: animated background, top bar (profile + currencies), screen area,
## bottom navigation, and battle hand-off.
##
## Headless balance sim: godot --headless --path . -- --sim 200

const SCREENS := {
	"shop": {"title": "Shop", "script": "res://scripts/ui/screens/shop_screen.gd"},
	"cards": {"title": "Cards", "script": "res://scripts/ui/screens/cards_screen.gd"},
	"home": {"title": "Battle", "script": "res://scripts/ui/screens/home_screen.gd"},
	"profile": {"title": "Profile", "script": "res://scripts/ui/screens/profile_screen.gd"},
	"achievements": {"title": "Awards", "script": "res://scripts/ui/screens/achievements_screen.gd"},
	"settings": {"title": "Settings", "script": "res://scripts/ui/screens/settings_screen.gd"},
}
const NAV_ORDER := ["shop", "cards", "home", "achievements", "profile", "settings"]

var menu_root: Control
var content: Control
var top_bar: HBoxContainer
var nav_buttons := {}
var current_screen: Control
var current_key := ""
var battle: Control


func _ready() -> void:
	theme = UIKit.theme()
	var args := OS.get_cmdline_user_args()
	if args.has("--test"):
		var tests = load("res://scripts/tools/rule_tests.gd").new()
		await get_tree().process_frame
		tests.run(args)
		get_tree().quit()
		return
	var sim_idx := args.find("--sim")
	if sim_idx >= 0:
		var n := int(args[sim_idx + 1]) if args.size() > sim_idx + 1 else 100
		_run_sim(n, args)
		return
	_build_menu()
	Game.profile_changed.connect(_refresh_top_bar)
	Game.settings_changed.connect(_refresh_top_bar)
	Game.achievement_unlocked.connect(_on_achievement)
	show_screen("home")
	Sfx.play_music("menu")
	if args.has("--shot"):
		_run_screenshot(args)


## Debug/QA hook: godot --path . -- --shot out.png [--screen cards] [--battle] [--wait 3] [--speed 4]
## Opens a screen (or an autoplayed battle), waits, saves a screenshot and quits.
func _run_screenshot(args: PackedStringArray) -> void:
	var out := args[args.find("--shot") + 1]
	var wait := 1.5
	if args.has("--wait"):
		wait = float(args[args.find("--wait") + 1])
	if args.has("--screen"):
		show_screen(args[args.find("--screen") + 1])
	if args.has("--map"):
		Game.set_meta("forced_map", args[args.find("--map") + 1])
	if args.has("--layout"):
		Game.set_meta("forced_layout", args[args.find("--layout") + 1])
	if args.has("--battle"):
		start_battle()
		if battle and battle.has_method("enable_autoplay"):
			battle.enable_autoplay()
	if args.has("--scroll") and current_screen:
		await get_tree().process_frame
		for sc in current_screen.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = int(args[args.find("--scroll") + 1])
	if args.has("--qa-deploy") and battle:
		# card_id,x,y[,team] — drops a card directly once the countdown ends.
		var qd := args[args.find("--qa-deploy") + 1].split(",")
		await get_tree().create_timer(3.8).timeout
		battle.sim._deploy(int(qd[3]) if qd.size() > 3 else 0, qd[0], Vector2(float(qd[1]), float(qd[2])), 1)
	if args.has("--speed"):
		Engine.time_scale = float(args[args.find("--speed") + 1])
	await get_tree().create_timer(wait * Engine.time_scale).timeout
	Engine.time_scale = 1.0
	if args.has("--qa-hover") and battle:
		var parts := args[args.find("--qa-hover") + 1].split(",")
		battle.qa_hover(int(parts[0]), Vector2(float(parts[1]), float(parts[2])))
		await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("Saved screenshot: ", out)
	get_tree().quit()


func _run_sim(n: int, args: PackedStringArray) -> void:
	var sim_script: Script = load("res://scripts/tools/balance_sim.gd")
	var runner = sim_script.new()
	await get_tree().process_frame
	runner.run(n, args)
	get_tree().quit()


# ------------------------------------------------------------------ menu

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(bg)

	var layout := UIKit.vbox(0)
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(layout)

	# Top bar
	var top_panel := UIKit.panel(Color(UIKit.BG_DEEP, 0.85), 0, 10)
	layout.add_child(top_panel)
	top_bar = UIKit.hbox(18)
	top_panel.add_child(top_bar)

	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	layout.add_child(content)

	# Bottom nav
	var nav_panel := UIKit.panel(Color(UIKit.BG_DEEP, 0.92), 0, 8)
	layout.add_child(nav_panel)
	var nav := UIKit.hbox(8)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_panel.add_child(nav)
	for key in NAV_ORDER:
		var b := NavButton.new()
		b.key = key
		b.text_label = SCREENS[key].title
		b.custom_minimum_size = Vector2(150 if key == "home" else 116, 64)
		b.pressed.connect(show_screen.bind(key))
		nav.add_child(b)
		nav_buttons[key] = b
	_refresh_top_bar()


func _refresh_top_bar() -> void:
	if top_bar == null:
		return
	for ch in top_bar.get_children():
		ch.queue_free()
	var avatar := AvatarIcon.new()
	avatar.custom_minimum_size = Vector2(46, 46)
	avatar.avatar = int(Game.profile.get("avatar", 0))
	top_bar.add_child(avatar)
	var name_box := UIKit.vbox(0)
	name_box.add_child(UIKit.label(str(Game.profile.name), 20, UIKit.CREAM, true))
	var league := Game.league_for(int(Game.profile.trophies))
	name_box.add_child(UIKit.label("%s League" % league.name, 14, UIKit.MUTED))
	top_bar.add_child(name_box)
	if Game.is_creative():
		var tag := UIKit.label("  CREATIVE MODE  ", 14, UIKit.INK, true)
		var tp := UIKit.panel(UIKit.GOLD, 8, 4)
		tp.add_child(tag)
		tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_bar.add_child(tp)
	top_bar.add_child(UIKit.spacer())
	top_bar.add_child(UIKit.currency_chip("trophies", int(Game.profile.trophies)))
	top_bar.add_child(UIKit.currency_chip("coins", int(Game.profile.coins)))
	top_bar.add_child(UIKit.currency_chip("gems", int(Game.profile.gems)))


func _on_achievement(id: String) -> void:
	var a := Achievements.get_info(id)
	if a.is_empty():
		return
	Sfx.play("legendary")
	UIKit.toast(self, "Achievement unlocked: %s!" % a.name, UIKit.GOLD)
	for k in nav_buttons:
		nav_buttons[k].queue_redraw()


func show_screen(key: String) -> void:
	if not SCREENS.has(key):
		return
	if current_screen:
		current_screen.queue_free()
		current_screen = null
	current_key = key
	for k in nav_buttons:
		nav_buttons[k].active = (k == key)
	var path: String = SCREENS[key].script
	var screen: Control
	if ResourceLoader.exists(path):
		screen = load(path).new()
	else:
		screen = _placeholder(SCREENS[key].title)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(screen)
	current_screen = screen
	if screen.has_signal("battle_pressed"):
		screen.connect("battle_pressed", start_battle)
	if screen.has_signal("navigate"):
		screen.connect("navigate", show_screen)
	# Slide-in
	screen.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, 0.18)


func _placeholder(title_text: String) -> Control:
	var c := CenterContainer.new()
	c.add_child(UIKit.title(title_text + " (coming soon)"))
	return c


# ------------------------------------------------------------------ battle

func start_battle() -> void:
	var deck := Game.active_deck()
	if not Game.deck_is_valid(deck):
		UIKit.toast(self, "Your active deck needs %d cards!" % Game.DECK_SIZE, UIKit.CORAL)
		show_screen("cards")
		return
	var levels := {}
	for id in deck:
		levels[id] = Game.level_of(id)
	var opponent := Game.make_bot_opponent()
	menu_root.visible = false
	battle = load("res://scripts/battle/battle_screen.gd").new()
	battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(battle)
	battle.setup(deck, levels, opponent)
	battle.finished.connect(_on_battle_finished)
	Sfx.play_music("battle")


func _on_battle_finished() -> void:
	if battle:
		battle.queue_free()
		battle = null
	menu_root.visible = true
	_refresh_top_bar()
	show_screen("home")
	Sfx.play_music("menu")


# ------------------------------------------------------------------ widgets

class NavButton extends Control:
	signal pressed
	var key := ""
	var text_label := ""
	var active := false:
		set(v):
			active = v
			queue_redraw()
	var hovered := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hovered = true
			queue_redraw())
		mouse_exited.connect(func():
			hovered = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := UIKit.GOLD if active else (UIKit.PANEL_LIGHT if hovered else UIKit.PANEL)
		if key == "home" and not active:
			col = UIKit.LEAF.darkened(0.15) if not hovered else UIKit.LEAF
		UIKit.style(col, 14, col.darkened(0.4), 3).draw(get_canvas_item(), r)
		var c := Vector2(size.x * 0.5, size.y * 0.4)
		var ic := UIKit.INK if active else UIKit.CREAM
		_draw_icon(c, 13.0, ic)
		var f := UIKit.font(true)
		draw_string(f, Vector2(0, size.y - 8), text_label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, ic)

	func _draw_icon(c: Vector2, r: float, col: Color) -> void:
		match key:
			"shop":
				draw_rect(Rect2(c + Vector2(-r, -r * 0.2), Vector2(r * 2, r * 1.2)), col, false, 3)
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.6, PI, TAU, 10, col, 3)
			"cards":
				draw_rect(Rect2(c + Vector2(-r * 0.9, -r), Vector2(r * 1.2, r * 1.7)), col, false, 3)
				draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.7), Vector2(r * 1.2, r * 1.7)), col, false, 3)
			"home":
				draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 4)
				draw_line(c + Vector2(r, r), c + Vector2(-r, -r), col, 4)
				draw_circle(c, r * 0.35, col)
			"profile":
				draw_circle(c + Vector2(0, -r * 0.4), r * 0.5, col)
				draw_arc(c + Vector2(0, r * 0.9), r * 0.9, PI, TAU, 12, col, 3)
			"achievements":
				draw_circle(c + Vector2(0, r * 0.25), r * 0.62, col)
				draw_line(c + Vector2(-r * 0.5, -r), c + Vector2(-r * 0.1, -r * 0.2), col, 3)
				draw_line(c + Vector2(r * 0.5, -r), c + Vector2(r * 0.1, -r * 0.2), col, 3)
				var unclaimed := Game.unclaimed_achievements()
				if unclaimed > 0:
					draw_circle(Vector2(size.x - 14, 12), 9, UIKit.CORAL)
					draw_string(UIKit.font(true), Vector2(size.x - 23, 17), str(unclaimed), HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Color.WHITE)
			"settings":
				draw_arc(c, r * 0.6, 0, TAU, 16, col, 4)
				for i in 6:
					var d := Vector2.from_angle(TAU * i / 6.0)
					draw_line(c + d * r * 0.7, c + d * r, col, 4)


class AvatarIcon extends Control:
	var avatar := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var cols := [UIKit.LEAF, UIKit.GOLD, UIKit.SKY, UIKit.CORAL, UIKit.VIOLET, Color("ff9a3c")]
		draw_circle(c, r, UIKit.INK)
		draw_circle(c, r - 3, cols[avatar % cols.size()])
		CardIcons.draw(self, ["sun_valkyrie", "seedling_sprinters", "glacier_gardener", "bramble_knight",
			"dragonfly_mech", "sunflower_turret"][avatar % 6], c, r * 0.7, UIKit.CREAM)


class MenuBackground extends Control:
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var steps := 24
		for i in steps:
			var y0 := size.y * i / steps
			var col := UIKit.BG.lerp(UIKit.BG_DEEP, float(i) / steps)
			draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), col)
		# Slow sun rays from the top-right corner.
		var sun := Vector2(size.x * 0.85, -size.y * 0.15)
		for i in 9:
			var a := PI * 0.55 + i * 0.12 + sin(t * 0.2 + i) * 0.02
			var d := Vector2.from_angle(a)
			var n := d.orthogonal() * 40.0
			draw_colored_polygon(PackedVector2Array([sun, sun + d * size.length() + n * 3.0, sun + d * size.length() - n * 3.0]),
				Color(UIKit.GOLD, 0.035))
		# Drifting leaves.
		for i in 14:
			var px := fmod(i * 197.0 + t * (12.0 + i % 5 * 4.0), size.x + 80.0) - 40.0
			var py := fmod(i * 131.0 + t * (18.0 + i % 3 * 6.0), size.y + 80.0) - 40.0
			var rot := t * 0.5 + i
			CardIcons.leaf(self, Vector2(px, py), Vector2.from_angle(rot) * (14.0 + i % 4 * 4.0), Color(UIKit.LEAF, 0.12))
