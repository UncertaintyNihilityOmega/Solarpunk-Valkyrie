extends Control
## Shop: free Sprout pack (timer), four pack tiers bought with Sunshards,
## and a Sunshard -> Seed exchange. No real-money purchases.

const EXCHANGES := [
	{"gems": 50, "coins": 500},
	{"gems": 200, "coins": 2200},
	{"gems": 500, "coins": 6000},
]

var _content: VBoxContainer
var _free_label: Label
var _free_btn: Button
var _free_was_ready := false


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	_content = UIKit.vbox(14)
	margin.add_child(_content)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	Game.profile_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for ch in _content.get_children():
		ch.queue_free()
	_free_label = null
	_free_btn = null
	_free_was_ready = Game.free_pack_ready()

	_content.add_child(UIKit.title("Packs", 28, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	var row := UIKit.hbox(14)
	_content.add_child(row)
	row.add_child(_free_card())
	for tier in Game.PACK_ORDER:
		row.add_child(_pack_card(tier))

	_content.add_child(UIKit.title("Seed Exchange", 28, UIKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	var ex := UIKit.hbox(14)
	_content.add_child(ex)
	for e in EXCHANGES:
		ex.add_child(_exchange_card(int(e.gems), int(e.coins)))


func _tick() -> void:
	if _free_label == null:
		return
	var is_ready := Game.free_pack_ready()
	if is_ready != _free_was_ready:
		_rebuild()
		return
	_free_label.text = "Ready to claim!" if is_ready else "Next in " + UIKit.format_time(Game.free_pack_seconds_left())


# ------------------------------------------------------------------ cards

func _free_card() -> Control:
	var info: Dictionary = Game.pack_info("sprout")
	var p := UIKit.panel(Color("1f5a3b"), 16, 12, UIKit.LEAF, 3)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.label("FREE PACK", 20, UIKit.LEAF.lightened(0.3), true, HORIZONTAL_ALIGNMENT_CENTER))
	var art := PackOpening.PackArt.new("sprout")
	art.custom_minimum_size = Vector2(0, 150)
	v.add_child(art)
	v.add_child(UIKit.label(str(info.name), 18, UIKit.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%d cards" % int(info.cards), 15, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var is_ready := Game.free_pack_ready()
	_free_label = UIKit.label("Ready to claim!" if is_ready else "Next in " + UIKit.format_time(Game.free_pack_seconds_left()),
		15, UIKit.GOLD if is_ready else UIKit.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_free_label)
	v.add_child(UIKit.spacer(false, true))
	_free_btn = UIKit.button("Claim", UIKit.LEAF, 22, Vector2(0, 52))
	_free_btn.disabled = not is_ready
	_free_btn.pressed.connect(_on_claim)
	v.add_child(_free_btn)
	return p


func _pack_card(tier: String) -> Control:
	var info: Dictionary = Game.pack_info(tier)
	var col: Color = info.color
	var p := UIKit.panel(UIKit.PANEL, 16, 12, col.darkened(0.35), 3)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.tooltip_text = _odds_text(tier)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var head := UIKit.hbox(4)
	v.add_child(head)
	var nm := UIKit.label(str(info.name), 20, col.lightened(0.25), true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var ib := UIKit.button("i", UIKit.PANEL_LIGHT, 16, Vector2(34, 34))
	ib.tooltip_text = _odds_text(tier)
	head.add_child(ib)
	var art := PackOpening.PackArt.new(tier)
	art.custom_minimum_size = Vector2(0, 150)
	v.add_child(art)
	v.add_child(UIKit.label("%d cards" % int(info.cards), 15, UIKit.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%s - %s Seeds" % [UIKit.format_number(int(info.coins[0])), UIKit.format_number(int(info.coins[1]))],
		15, UIKit.GOLD, false, HORIZONTAL_ALIGNMENT_CENTER))
	var g := ""
	if str(info.guarantee) != "":
		g = "Guaranteed %s" % CardDB.RARITY_NAMES[info.guarantee]
	var gl := UIKit.label(g if g != "" else " ", 14, CardDB.RARITY_COLORS.get(info.guarantee, UIKit.MUTED), true,
		HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(gl)
	var price := int(info.price)
	var can_buy: bool = Game.profile.gems >= price
	var b := UIKit.button("", UIKit.GOLD, 22, Vector2(0, 52))
	b.disabled = not can_buy
	var h := UIKit.hbox(6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := CurrencyIcon.new()
	icon.kind = "gems"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var pl := UIKit.label(UIKit.format_number(price), 24, UIKit.INK if can_buy else UIKit.MUTED, true)
	h.add_child(pl)
	b.add_child(h)
	b.pressed.connect(_on_buy.bind(tier))
	v.add_child(b)
	return p


func _exchange_card(gems: int, coins: int) -> Control:
	var p := UIKit.panel(UIKit.PANEL, 14, 12, UIKit.PANEL_LIGHT, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(12)
	p.add_child(h)
	var left := UIKit.hbox(8)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.currency_chip("gems", gems, 22))
	left.add_child(UIKit.label("->", 22, UIKit.MUTED, true))
	left.add_child(UIKit.currency_chip("coins", coins, 22))
	h.add_child(left)
	var b := UIKit.button("Trade", UIKit.LEAF, 20, Vector2(110, 46))
	b.disabled = Game.profile.gems < gems
	b.pressed.connect(_on_exchange.bind(gems, coins))
	h.add_child(b)
	return p


func _odds_text(tier: String) -> String:
	var info: Dictionary = Game.pack_info(tier)
	var odds: Array = info.odds
	var lines := ["Odds per card:"]
	for i in CardDB.RARITIES.size():
		lines.append("%s: %s%%" % [CardDB.RARITY_NAMES[CardDB.RARITIES[i]], ("%.1f" % float(odds[i])).trim_suffix(".0")])
	if str(info.guarantee) != "":
		lines.append("Guaranteed: at least one %s card" % CardDB.RARITY_NAMES[info.guarantee])
	return "\n".join(lines)


# ------------------------------------------------------------------ actions

func _overlay_host() -> Control:
	var scene := get_tree().current_scene
	if scene is Control:
		return scene
	return self


func _on_claim() -> void:
	var res := Game.claim_free_pack()
	if res.is_empty():
		Sfx.play("error")
		return
	PackOpening.open(_overlay_host(), res)


func _on_buy(tier: String) -> void:
	var res := Game.buy_pack(tier)
	if res.is_empty():
		Sfx.play("error")
		UIKit.toast(self, "Not enough Sunshards!", UIKit.CORAL)
		return
	PackOpening.open(_overlay_host(), res)


func _on_exchange(gems: int, coins: int) -> void:
	if Game.spend_gems(gems):
		Game.add_coins(coins)
		Sfx.play("coins")
		UIKit.toast(self, "+%s Seeds" % UIKit.format_number(coins), UIKit.GOLD)
	else:
		Sfx.play("error")
		UIKit.toast(self, "Not enough Sunshards!", UIKit.CORAL)
