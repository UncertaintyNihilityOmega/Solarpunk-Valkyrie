class_name PackOpening
extends Control
## Full-screen pack opening: pack shakes and bursts, cards are revealed one stack
## at a time (click / Space / Enter), then a summary with a Collect button.
## The pack is already added to the profile by Game.open_pack; this is presentation only.
##
## PackOpening.open(parent, result)   result = {"tier", "coins", "cards": [{"id","count","new"}]}
## PackOpening.PackArt is the torn-foil pack graphic (also used by the shop).

signal closed

var result: Dictionary = {}
var _cards: Array = []
var _idx := 0
var _stage := ""
var _content: Control
var _flash: ColorRect
var _skip_btn: Button
var _lock := false
var _tween: Tween
var _closing := false


static func open(parent: Control, res: Dictionary) -> PackOpening:
	var p := PackOpening.new()
	p.result = res
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cards = result.get("cards", [])
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.08, 0.07, 0.97)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_skip_btn = UIKit.button("Skip", UIKit.PANEL_LIGHT, 18, Vector2(100, 44))
	_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_skip_btn.pressed.connect(_show_summary)
	add_child(_skip_btn)
	_start_pack_stage()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if _stage == "summary":
			close()
		else:
			_advance()


func _clear_content() -> void:
	for ch in _content.get_children():
		ch.queue_free()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# ------------------------------------------------------------------ pack stage

func _start_pack_stage() -> void:
	_stage = "pack"
	_clear_content()
	var tier: String = str(result.get("tier", "sprout"))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	var box := UIKit.vbox(18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var art := PackArt.new(tier)
	art.custom_minimum_size = Vector2(280, 400)
	art.pivot_offset = Vector2(140, 200)
	art.scale = Vector2(0.3, 0.3)
	box.add_child(art)
	var info: Dictionary = Game.pack_info(tier)
	var pack_col: Color = info.get("color", UIKit.GOLD)
	box.add_child(UIKit.title(str(info.get("name", "Pack")), 32, UIKit.CREAM))

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float): art.shake = sin(t * TAU * 8.0) * 0.14 * t, 0.0, 1.0, 0.95)
	_tween.tween_callback(func():
		Sfx.play("pack")
		art.shake = 0.0
		_spawn_burst(pack_col)
		var ft := create_tween()
		_flash.color = Color(1, 1, 1, 0.85)
		ft.tween_property(_flash, "color:a", 0.0, 0.4))
	_tween.tween_method(func(v: float): art.tear = v, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.2)
	_tween.tween_callback(_start_reveal)


func _spawn_burst(col: Color) -> void:
	var fx := BurstFx.new()
	fx.color = col
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "t", 1.0, 0.6)
	tw.tween_callback(fx.queue_free)


# ------------------------------------------------------------------ reveal stage

func _start_reveal() -> void:
	if _cards.is_empty():
		_show_summary()
		return
	_stage = "reveal"
	_idx = 0
	_show_card(0)


func _show_card(i: int) -> void:
	_clear_content()
	_kill_tween()
	var entry: Dictionary = _cards[i]
	var id: String = entry.id
	var cd := CardDB.get_card(id)
	var rarity: String = cd.rarity
	var col: Color = CardDB.RARITY_COLORS[rarity]
	var strength := {"common": 0.5, "rare": 1.0, "epic": 1.5, "legendary": 2.4}.get(rarity, 1.0) as float
	var rays := GlowRays.new()
	rays.color = col
	rays.strength = strength
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(rays)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	var box := UIKit.vbox(8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	box.add_child(UIKit.label("Card %d of %d" % [i + 1, _cards.size()], 16, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var tag_row := CenterContainer.new()
	tag_row.custom_minimum_size = Vector2(0, 40)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag_row)
	if bool(entry.get("new", false)):
		var tag := UIKit.panel(UIKit.GOLD, 12, 6, UIKit.CREAM, 2)
		tag.add_child(UIKit.label("NEW!", 24, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
		tag_row.add_child(tag)
		var bob := tag.create_tween().set_loops()
		bob.tween_property(tag, "scale", Vector2(1.12, 1.12), 0.4).set_trans(Tween.TRANS_SINE)
		bob.tween_property(tag, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
		tag.pivot_offset = Vector2(40, 20)
	var cv := CardView.new(id, maxi(1, Game.level_of(id)))
	cv.custom_minimum_size = Vector2(230, 300)
	cv.pivot_offset = Vector2(115, 150)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.scale = Vector2(0.2, 0.2)
	cv.rotation = -0.3
	box.add_child(cv)
	var nm := UIKit.title(str(cd.name), 30, col)
	box.add_child(nm)
	box.add_child(UIKit.label("%s %s" % [CardDB.RARITY_NAMES[rarity], CardDB.TYPE_NAMES[cd.type]], 18, UIKit.MUTED,
		false, HORIZONTAL_ALIGNMENT_CENTER))
	var cnt := UIKit.title("x%d" % int(entry.count), 52, UIKit.GOLD)
	box.add_child(cnt)
	var hint := UIKit.label("Click to continue", 16, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(hint)

	Sfx.play("legendary" if rarity == "legendary" else "reveal")
	_lock = true
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(cv, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cv, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cnt.modulate.a = 0.0
	_tween.tween_property(cnt, "modulate:a", 1.0, 0.3).set_delay(0.25)
	_tween.chain().tween_callback(func(): _lock = false)


func _advance() -> void:
	if _closing or _stage != "reveal":
		return
	if _lock:
		return
	_idx += 1
	if _idx >= _cards.size():
		_show_summary()
	else:
		_show_card(_idx)


# ------------------------------------------------------------------ summary stage

func _show_summary() -> void:
	if _stage == "summary" or _closing:
		return
	_stage = "summary"
	_kill_tween()
	_skip_btn.visible = false
	_clear_content()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	var box := UIKit.vbox(18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	box.add_child(UIKit.title("Pack Opened!", 42, UIKit.GOLD))
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.custom_minimum_size = Vector2(1000, 0)
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(flow)
	var n := 0
	for entry in _cards:
		var id: String = entry.id
		var cv := CardView.new(id, maxi(1, Game.level_of(id)))
		cv.custom_minimum_size = Vector2(110, 144)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.progress = 1.0
		if bool(entry.get("new", false)):
			cv.badge = "NEW x%d" % int(entry.count)
			cv.badge_color = UIKit.GOLD
		else:
			cv.badge = "x%d" % int(entry.count)
			cv.badge_color = UIKit.LEAF.darkened(0.2)
		cv.pivot_offset = Vector2(55, 72)
		cv.modulate.a = 0.0
		cv.scale = Vector2(0.6, 0.6)
		flow.add_child(cv)
		var tw := cv.create_tween()
		tw.set_parallel(true)
		tw.tween_property(cv, "modulate:a", 1.0, 0.2).set_delay(0.06 * n)
		tw.tween_property(cv, "scale", Vector2.ONE, 0.3).set_delay(0.06 * n).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		n += 1
	var coins: int = int(result.get("coins", 0))
	if coins > 0:
		var row := UIKit.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := CurrencyIcon.new()
		icon.kind = "coins"
		icon.custom_minimum_size = Vector2(36, 36)
		row.add_child(icon)
		row.add_child(UIKit.title("+%s Seeds" % UIKit.format_number(coins), 30, UIKit.GOLD))
		box.add_child(row)
	var collect := UIKit.button("Collect", UIKit.LEAF, 28, Vector2(260, 64))
	collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	collect.pressed.connect(close)
	box.add_child(collect)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


# ------------------------------------------------------------------ inner classes

## Torn-foil pack with a sun/leaf emblem. shake = rotation (radians), tear = 0..1 top flap opening.
class PackArt extends Control:
	var tier: String = "sprout"
	var base_color := Color("7bc96f")
	var tier_index := 0
	var shake := 0.0:
		set(v):
			shake = v
			queue_redraw()
	var tear := 0.0:
		set(v):
			tear = v
			queue_redraw()

	func _init(t: String = "sprout") -> void:
		tier = t
		var info: Dictionary = Game.PACKS.get(t, {})
		base_color = info.get("color", Color("7bc96f"))
		tier_index = maxi(0, Game.PACK_ORDER.find(t))
		custom_minimum_size = Vector2(120, 170)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _crimp(w: float, y: float, amp: float, n: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.append(Vector2(lerpf(-w * 0.5, w * 0.5, float(i) / n), y + (amp if i % 2 == 0 else -amp)))
		return pts

	func _draw() -> void:
		var h := minf(size.y, size.x / 0.68) * 0.92
		var w := h * 0.68
		var cpos := size * 0.5
		var cut_y := -h * 0.5 + h * 0.27
		var amp := h * 0.02
		var jag := PackedVector2Array()
		for i in 9:
			jag.append(Vector2(lerpf(-w * 0.5, w * 0.5, i / 8.0),
				cut_y + sin(i * 2.7) * h * 0.016 + (amp if i % 2 == 0 else -amp)))
		var outline := base_color.darkened(0.6)
		var shade := base_color.darkened(0.18)
		var cream := Color("f6efd9")
		var gold := Color("f2c14e")

		# ---- body
		draw_set_transform(cpos, shake, Vector2.ONE)
		var bottom := _crimp(w, h * 0.5, amp, 10)
		bottom.reverse()
		var body := PackedVector2Array(jag)
		body.append_array(bottom)
		draw_colored_polygon(body, base_color)
		draw_rect(Rect2(-w * 0.5, h * 0.18, w, h * 0.3), Color(shade, 0.55))
		draw_rect(Rect2(-w * 0.5 + w * 0.08, cut_y + h * 0.04, w * 0.12, h * 0.5 - cut_y - h * 0.08), Color(1, 1, 1, 0.18))
		draw_rect(Rect2(w * 0.5 - w * 0.2, cut_y + h * 0.04, w * 0.05, h * 0.5 - cut_y - h * 0.08), Color(1, 1, 1, 0.10))
		var closed_body := PackedVector2Array(body)
		closed_body.append(body[0])
		draw_polyline(closed_body, outline, 3.0, true)
		# emblem
		var ec := Vector2(0, h * 0.14)
		var er := w * 0.25
		var rays := 8 + tier_index * 2
		for i in rays:
			var d := Vector2.from_angle(TAU * i / rays + 0.2)
			draw_colored_polygon(PackedVector2Array([ec + d.rotated(0.13) * er * 1.05,
				ec + d * er * 1.6, ec + d.rotated(-0.13) * er * 1.05]), cream)
		draw_circle(ec, er * 1.04, outline)
		draw_circle(ec, er, gold)
		draw_circle(ec + Vector2(-er * 0.2, -er * 0.25), er * 0.55, Color("ffe27a"))
		draw_line(ec + Vector2(0, er * 0.55), ec + Vector2(0, -er * 0.05), Color("2f7d3a"), maxf(2.0, er * 0.12))
		CardIcons.leaf(self, ec + Vector2(0, -er * 0.05), Vector2(-er * 0.65, -er * 0.55), Color("2f7d3a"))
		CardIcons.leaf(self, ec + Vector2(0, -er * 0.05), Vector2(er * 0.65, -er * 0.55), Color("4cc36b"))
		for i in tier_index + 1:
			draw_circle(Vector2((i - tier_index * 0.5) * w * 0.13, h * 0.405), w * 0.036, cream)

		# ---- top flap
		draw_set_transform(cpos + Vector2(tear * w * 0.25, -tear * h * 0.55), shake + tear * 0.7, Vector2.ONE)
		var flap := _crimp(w, -h * 0.5, amp, 10)
		var jr := PackedVector2Array(jag)
		jr.reverse()
		flap.append_array(jr)
		var fa := 1.0 - tear * 0.6
		draw_colored_polygon(flap, Color(base_color, fa))
		draw_rect(Rect2(-w * 0.5 + w * 0.08, -h * 0.5 + h * 0.05, w * 0.12, h * 0.15), Color(1, 1, 1, 0.2 * fa))
		var closed_flap := PackedVector2Array(flap)
		closed_flap.append(flap[0])
		draw_polyline(closed_flap, Color(outline, fa), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rotating sun rays + soft glow behind a revealed card.
class GlowRays extends Control:
	var color := Color.WHITE
	var strength := 1.0
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var ray_len := size.length()
		var n := 14
		for i in n:
			var d := Vector2.from_angle(t * 0.3 + TAU * i / n)
			draw_colored_polygon(PackedVector2Array([c, c + d.rotated(0.07) * ray_len, c + d.rotated(-0.07) * ray_len]),
				Color(color, minf(0.5, 0.09 * strength)))
		for k in 6:
			draw_circle(c, 280.0 - k * 40.0, Color(color, 0.05 * strength))


## Expanding ring + streaks when the pack bursts.
class BurstFx extends Control:
	var color := Color.WHITE
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var k := 1.0 - t
		for i in 22:
			var d := Vector2.from_angle(TAU * i / 22.0 + 0.1)
			var r0 := 60.0 + t * 380.0 * (0.7 + 0.3 * (i % 3))
			draw_line(c + d * r0, c + d * (r0 + 80.0 * k), Color(color, k), 6.0 * k + 1.0)
		draw_arc(c, 20.0 + t * 360.0, 0.0, TAU, 48, Color(1, 1, 1, k), 10.0 * k + 1.0)
