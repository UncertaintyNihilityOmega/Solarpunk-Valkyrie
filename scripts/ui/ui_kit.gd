class_name UIKit
extends RefCounted
## Shared solarpunk palette, theme and small widget factories.
## Every screen builds its UI in code with these helpers so the look stays consistent.

const BG_DEEP := Color("0f221e")
const BG := Color("163a33")
const PANEL := Color("1d4a40")
const PANEL_LIGHT := Color("2a6152")
const PANEL_DARK := Color("12302a")
const CREAM := Color("f6efd9")
const INK := Color("13291f")
const MUTED := Color("a6c4b6")
const GOLD := Color("f2c14e")
const LEAF := Color("4cc36b")
const SKY := Color("7fd6e0")
const CORAL := Color("ff6f61")
const VIOLET := Color("a45ae6")

static var _theme: Theme
static var _font: Font
static var _font_bold: Font


static func font(bold: bool = true) -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Nunito", "Segoe UI", "Arial"])
		f.font_weight = 600
		_font = f
		var fb := SystemFont.new()
		fb.font_names = PackedStringArray(["Nunito Black", "Segoe UI Black", "Arial Black", "Segoe UI"])
		fb.font_weight = 800
		_font_bold = fb
	return _font_bold if bold else _font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	# Buttons
	t.set_stylebox("normal", "Button", style(PANEL_LIGHT, 12, PANEL_LIGHT.lightened(0.15), 2))
	t.set_stylebox("hover", "Button", style(PANEL_LIGHT.lightened(0.12), 12, GOLD, 2))
	t.set_stylebox("pressed", "Button", style(PANEL_LIGHT.darkened(0.2), 12, GOLD, 2))
	t.set_stylebox("disabled", "Button", style(PANEL.darkened(0.2), 12, PANEL, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_font("font", "Button", font(true))
	# Panels
	t.set_stylebox("panel", "PanelContainer", style(PANEL, 16, PANEL_LIGHT, 2))
	t.set_stylebox("panel", "Panel", style(PANEL, 16, PANEL_LIGHT, 2))
	# Inputs
	t.set_stylebox("normal", "LineEdit", style(PANEL_DARK, 10, PANEL_LIGHT, 2))
	t.set_stylebox("focus", "LineEdit", style(PANEL_DARK, 10, GOLD, 2))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_stylebox("normal", "OptionButton", style(PANEL_LIGHT, 10, PANEL_LIGHT.lightened(0.15), 2))
	t.set_stylebox("hover", "OptionButton", style(PANEL_LIGHT.lightened(0.1), 10, GOLD, 2))
	t.set_stylebox("pressed", "OptionButton", style(PANEL_LIGHT.darkened(0.2), 10, GOLD, 2))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", style(PANEL_DARK, 10, PANEL_LIGHT, 2))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", style(PANEL_LIGHT, 6))
	# Sliders
	var track := style(PANEL_DARK, 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", style(LEAF, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(LEAF.lightened(0.2), 6))
	# Scroll
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", style(PANEL_DARK, 6))
	t.set_stylebox("grabber", "VScrollBar", style(PANEL_LIGHT, 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", style(LEAF, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", style(GOLD, 6))
	# Check buttons / boxes
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_color", "CheckBox", CREAM)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", style(INK, 8, GOLD, 1))
	t.set_color("font_color", "TooltipLabel", CREAM)
	_theme = t
	return t


static func style(color: Color, radius: int = 12, border_color: Color = Color.TRANSPARENT,
		border: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border > 0:
		s.border_color = border_color
		s.set_border_width_all(border)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func label(text: String, size: int = 18, color: Color = CREAM, bold: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l


## Big outlined heading text.
static func title(text: String, size: int = 34, color: Color = CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, true, align)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	return l


## A chunky colored button. Text color picks itself for contrast.
static func button(text: String, color: Color = PANEL_LIGHT, size: int = 20, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	var dark := color.get_luminance() > 0.55
	var fc := INK if dark else CREAM
	b.add_theme_stylebox_override("normal", style(color, 14, color.darkened(0.35), 3, 14))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.12), 14, GOLD if not dark else CREAM, 3, 14))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.15), 14, color.darkened(0.5), 3, 14))
	b.add_theme_stylebox_override("disabled", style(color.darkened(0.45).lerp(Color(0.3, 0.3, 0.3), 0.5), 14, PANEL_DARK, 3, 14))
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
	b.add_theme_font_override("font", font(true))
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	b.pressed.connect(func(): Sfx.play("click"))
	return b


static func panel(color: Color = PANEL, radius: int = 16, pad: int = 14, border_color: Color = Color.TRANSPARENT, border: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(color, radius, border_color, border, pad)
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", s)
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(child: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	m.add_child(child)
	return m


static func spacer(expand_h: bool = true, expand_v: bool = false) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## "12 345" style thousands separators.
static func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## "2h 05m", "4m 09s" or "0:42".
static func format_time(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%d:%02d" % [seconds / 60, seconds % 60]
	return "0:%02d" % seconds


## Currency display: icon + number. kind = "coins" | "gems" | "trophies".
static func currency_chip(kind: String, amount: int, size: int = 20) -> HBoxContainer:
	var h := hbox(6)
	var icon := CurrencyIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(size + 8, size + 8)
	h.add_child(icon)
	var l := label(format_number(amount), size, CREAM, true)
	l.name = "Amount"
	h.add_child(l)
	return h


static func currency_name(kind: String) -> String:
	return {"coins": "Seeds", "gems": "Sunshards", "trophies": "Trophies"}.get(kind, kind)


## Pops a modal message with an OK button on top of `parent`. Returns the overlay.
static func toast(parent: Control, text: String, color: Color = GOLD) -> void:
	var l := title(text, 26, color)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.position.y = 90
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position.x = (parent.size.x - l.size.x) * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 60.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.tween_callback(l.queue_free)


## Modal confirm dialog. on_yes is called when confirmed.
static func confirm(parent: Control, text: String, yes_text: String, on_yes: Callable, danger: bool = false) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var p := panel(PANEL, 18, 24, GOLD, 3)
	p.custom_minimum_size = Vector2(440, 0)
	center.add_child(p)
	var v := vbox(18)
	p.add_child(v)
	var msg := label(text, 20, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var row := hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var no := button("Cancel", PANEL_LIGHT, 20, Vector2(140, 48))
	no.pressed.connect(overlay.queue_free)
	row.add_child(no)
	var yes := button(yes_text, CORAL if danger else LEAF, 20, Vector2(160, 48))
	yes.pressed.connect(func():
		overlay.queue_free()
		on_yes.call())
	row.add_child(yes)
