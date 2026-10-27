class_name CardView
extends Control
## A single card tile: rarity frame, procedural art, cost, level and name.
## Used in the battle hand, deck builder, collection and pack opening.

signal pressed(card_id: String)
signal right_pressed(card_id: String)

var card_id: String = "":
	set(v):
		card_id = v
		queue_redraw()
## 0 = not owned (drawn locked).
var level: int = 1:
	set(v):
		level = v
		queue_redraw()
var show_name: bool = true
var show_level: bool = true
var dimmed: bool = false:
	set(v):
		dimmed = v
		queue_redraw()
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
## Optional text under the card art, e.g. "12/20" or "x5".
var badge: String = "":
	set(v):
		badge = v
		queue_redraw()
var badge_color: Color = UIKit.LEAF
## 0..1 progress bar drawn behind the badge (e.g. copies toward next upgrade).
var progress: float = -1.0
var team_color: Color = Color("4cc36b")
var hovered := false


func _init(id: String = "", lvl: int = 1) -> void:
	card_id = id
	level = lvl
	custom_minimum_size = Vector2(96, 124)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	if is_instance_valid(Game):
		team_color = Game.player_color()
	mouse_entered.connect(func():
		hovered = true
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(card_id)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit(card_id)
			accept_event()


func _draw() -> void:
	if card_id == "":
		_draw_empty()
		return
	var c := CardDB.get_card(card_id)
	if c.is_empty():
		return
	var rect := Rect2(Vector2.ZERO, size)
	var lift := -3.0 if hovered and not dimmed else 0.0
	rect.position.y += lift
	var rarity_col: Color = CardDB.RARITY_COLORS[c.rarity]
	var locked := level <= 0
	# Shadow
	var sh := UIKit.style(Color(0, 0, 0, 0.35), 12)
	sh.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, 4), rect.size))
	# Frame
	var frame := UIKit.style(rarity_col.darkened(0.15) if not locked else Color("4b5a55"), 12,
		UIKit.GOLD if selected else rarity_col.darkened(0.5), 4 if selected else 2)
	frame.draw(get_canvas_item(), rect)
	# Art area
	var art := Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, rect.size.y * (0.66 if show_name else 0.82)))
	var bg_col := Color("e8f1dc") if c.type != "spell" else Color("efe3f7")
	if c.type == "building":
		bg_col = Color("f3e6cf")
	UIKit.style(bg_col if not locked else Color("9aa5a0"), 9).draw(get_canvas_item(), art)
	# Subtle sunburst behind art
	var ac := art.get_center()
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 + 0.2)
		draw_colored_polygon(PackedVector2Array([ac, ac + d.rotated(0.18) * art.size.x * 0.5,
			ac + d.rotated(-0.18) * art.size.x * 0.5]), Color(1, 1, 1, 0.25))
	var icon_r := minf(art.size.x, art.size.y) * 0.36
	CardIcons.draw(self, card_id, ac, icon_r, team_color if not locked else Color("6b7570"))
	# Name strip
	if show_name:
		var f := UIKit.font(true)
		var fs := clampi(int(size.x / 8.2), 10, 15)
		var name_rect := Rect2(rect.position.x + 4, art.end.y + 2, rect.size.x - 8, rect.end.y - art.end.y - 6)
		var nm: String = c.name
		var lines := _wrap(nm, f, fs, name_rect.size.x)
		var lh := fs + 1
		var y0 := name_rect.position.y + (name_rect.size.y - lh * lines.size()) * 0.5 + fs * 0.8
		for i in lines.size():
			draw_string_outline(f, Vector2(name_rect.position.x, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER,
				name_rect.size.x, fs, 4, UIKit.INK)
			draw_string(f, Vector2(name_rect.position.x, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER,
				name_rect.size.x, fs, UIKit.CREAM)
	# Cost
	var cost_r := clampf(size.x * 0.15, 10, 18)
	var cc := rect.position + Vector2(cost_r + 1, cost_r + 1)
	CurrencyIcon.draw_icon(self, "energy", cc, cost_r)
	var fb := UIKit.font(true)
	var cfs := int(cost_r * 1.25)
	draw_string(fb, cc + Vector2(-cost_r, cfs * 0.36), str(c.cost), HORIZONTAL_ALIGNMENT_CENTER, cost_r * 2, cfs, UIKit.INK)
	# Level
	if show_level and not locked:
		var lfs := clampi(int(size.x / 8.0), 10, 15)
		var lt := "Lv %d" % level
		# Wide enough for "Lv 10" (a narrow box used to clip it to "Lv 1").
		var lw := fb.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 2.0
		var lp := Vector2(rect.end.x - 6 - lw, rect.position.y + lfs + 4)
		draw_string_outline(fb, lp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, 4, UIKit.INK)
		draw_string(fb, lp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, UIKit.CREAM)
	# Badge / progress
	if badge != "":
		var bfs := clampi(int(size.x / 8.0), 10, 14)
		var br := Rect2(rect.position.x + 8, art.end.y - bfs - 6, rect.size.x - 16, bfs + 6)
		UIKit.style(Color(UIKit.INK, 0.85), 6).draw(get_canvas_item(), br)
		if progress >= 0.0:
			var pr := Rect2(br.position, Vector2(br.size.x * clampf(progress, 0.0, 1.0), br.size.y))
			if pr.size.x > 2:
				UIKit.style(badge_color, 6).draw(get_canvas_item(), pr)
		draw_string(fb, br.position + Vector2(0, bfs + 1), badge, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, bfs, UIKit.CREAM)
	if locked:
		_draw_lock(ac, icon_r * 0.55)
	if dimmed:
		UIKit.style(Color(0.05, 0.08, 0.07, 0.55), 12).draw(get_canvas_item(), rect)


func _draw_empty() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var s := UIKit.style(Color(UIKit.PANEL_DARK, 0.7), 12, Color(UIKit.MUTED, 0.4), 2)
	s.draw(get_canvas_item(), rect)
	var c := size * 0.5
	draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(UIKit.MUTED, 0.6), 3)
	draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(UIKit.MUTED, 0.6), 3)


func _draw_lock(c: Vector2, r: float) -> void:
	draw_arc(c + Vector2(0, -r * 0.3), r * 0.5, PI, TAU, 12, UIKit.INK, r * 0.2)
	draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.3), Vector2(r * 1.5, r * 1.1)), UIKit.INK)
	draw_circle(c + Vector2(0, r * 0.2), r * 0.18, UIKit.GOLD)


func _wrap(text: String, f: Font, fs: int, width: float) -> Array:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return [text]
	var words := text.split(" ")
	var lines := []
	var cur := ""
	for w in words:
		var t := w if cur == "" else cur + " " + w
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines.slice(0, 2)
