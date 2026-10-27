extends Control
## Deck builder + collection. Edit one of 5 deck slots at the top, browse every
## card below. Left-click opens the card popup, right-click on a deck card removes it.

const FILTERS := [
	{"key": "all", "text": "All"},
	{"key": "troop", "text": "Troops"},
	{"key": "building", "text": "Buildings"},
	{"key": "spell", "text": "Spells"},
]

var _slot := 0
var _filter := "all"
var _pending := ""  # collection card waiting to replace a deck card
var _header: VBoxContainer
var _filter_row: HBoxContainer
var _grid: HFlowContainer


func _ready() -> void:
	_slot = Game.active_deck_index()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := UIKit.vbox(10)
	margin.add_child(root)
	_header = UIKit.vbox(8)
	root.add_child(_header)
	_filter_row = UIKit.hbox(8)
	root.add_child(_filter_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var gm := MarginContainer.new()
	gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gm.add_theme_constant_override("margin_top", 6)
	gm.add_theme_constant_override("margin_right", 8)
	scroll.add_child(gm)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 14)
	gm.add_child(_grid)
	Game.profile_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for box in [_header, _filter_row, _grid]:
		for ch in box.get_children():
			ch.queue_free()
	_build_header()
	_build_filters()
	_build_grid()


# ------------------------------------------------------------------ header (slots + deck)

func _build_header() -> void:
	var deck := Game.get_deck(_slot)
	var valid := Game.deck_is_valid(deck)

	var tabs := UIKit.hbox(8)
	_header.add_child(tabs)
	tabs.add_child(UIKit.label("Deck", 22, UIKit.CREAM, true))
	for i in Game.DECK_SLOTS:
		var editing := i == _slot
		var is_active := i == Game.active_deck_index()
		var col := UIKit.GOLD if editing else (UIKit.LEAF.darkened(0.35) if is_active else UIKit.PANEL_LIGHT)
		var b := UIKit.button(str(i + 1), col, 20, Vector2(54, 42))
		b.tooltip_text = "Deck %d%s" % [i + 1, " (battle deck)" if is_active else ""]
		b.pressed.connect(_select_slot.bind(i))
		tabs.add_child(b)
	tabs.add_child(UIKit.label("Green = battle deck", 14, UIKit.MUTED))
	tabs.add_child(UIKit.spacer())
	if _slot == Game.active_deck_index():
		var ab := UIKit.button("Battle deck", UIKit.PANEL_LIGHT, 18, Vector2(170, 42))
		ab.disabled = true
		tabs.add_child(ab)
	else:
		var ub := UIKit.button("Use this deck", UIKit.LEAF, 18, Vector2(170, 42))
		ub.disabled = not valid
		ub.tooltip_text = "" if valid else "Fill all %d slots first" % Game.DECK_SIZE
		ub.pressed.connect(func(): Game.set_active_deck(_slot))
		tabs.add_child(ub)

	if _pending != "":
		var banner := UIKit.panel(Color(UIKit.GOLD, 0.22), 12, 6, UIKit.GOLD, 2)
		var br := UIKit.hbox(10)
		banner.add_child(br)
		var msg := UIKit.label("Deck is full. Pick a deck card to swap out for %s." % str(CardDB.get_card(_pending).name),
			17, UIKit.CREAM, true)
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(msg)
		var cancel := UIKit.button("Cancel", UIKit.PANEL_LIGHT, 16, Vector2(100, 36))
		cancel.pressed.connect(func():
			_pending = ""
			_refresh())
		br.add_child(cancel)
		_header.add_child(banner)

	var row := UIKit.hbox(8)
	_header.add_child(row)
	for i in Game.DECK_SIZE:
		var cv := CardView.new("", 1)
		cv.custom_minimum_size = Vector2(94, 122)
		if i < deck.size():
			var id: String = deck[i]
			cv.card_id = id
			cv.level = Game.level_of(id)
			cv.pressed.connect(_on_deck_card)
			cv.right_pressed.connect(_remove_from_deck)
			if _pending != "":
				cv.selected = true
				var tw := cv.create_tween().set_loops()
				tw.tween_property(cv, "modulate", Color(1.35, 1.3, 0.8), 0.45)
				tw.tween_property(cv, "modulate", Color.WHITE, 0.45)
		row.add_child(cv)
	row.add_child(UIKit.spacer())
	var info := UIKit.vbox(6)
	info.custom_minimum_size = Vector2(190, 0)
	row.add_child(info)
	info.add_child(UIKit.label("Avg cost", 15, UIKit.MUTED))
	var cost_row := UIKit.hbox(6)
	var energy := CurrencyIcon.new()
	energy.kind = "energy"
	energy.custom_minimum_size = Vector2(28, 28)
	cost_row.add_child(energy)
	cost_row.add_child(UIKit.label("%.1f" % Game.deck_average_cost(deck), 28, UIKit.GOLD, true))
	info.add_child(cost_row)
	info.add_child(UIKit.label("Cards: %d / %d" % [deck.size(), Game.DECK_SIZE], 16, UIKit.CREAM, true))
	var status := UIKit.label("Ready to battle" if valid else "Needs %d more" % (Game.DECK_SIZE - deck.size()),
		16, UIKit.LEAF if valid else UIKit.CORAL, true)
	info.add_child(status)
	info.add_child(UIKit.label("Right-click a deck card to remove it", 13, UIKit.MUTED))


# ------------------------------------------------------------------ filters

func _build_filters() -> void:
	for f in FILTERS:
		var b := UIKit.button(f.text, UIKit.GOLD if _filter == f.key else UIKit.PANEL_LIGHT, 17, Vector2(110, 38))
		b.pressed.connect(_set_filter.bind(f.key))
		_filter_row.add_child(b)
	_filter_row.add_child(UIKit.spacer())
	_filter_row.add_child(UIKit.label("Gold border = in this deck", 14, UIKit.MUTED))
	var total := CardDB.collectible_ids().size()
	_filter_row.add_child(UIKit.label("Collection %d/%d" % [Game.owned_ids().size(), total], 20, UIKit.CREAM, true))


func _set_filter(key: String) -> void:
	_filter = key
	_refresh()


# ------------------------------------------------------------------ collection grid

func _sorted_ids() -> Array:
	var ids := CardDB.collectible_ids()
	ids = ids.filter(func(id): return _filter == "all" or CardDB.get_card(id).type == _filter)
	ids.sort_custom(func(a, b):
		var ca: Dictionary = CardDB.get_card(a)
		var cb: Dictionary = CardDB.get_card(b)
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		var ra := CardDB.RARITIES.find(ca.rarity)
		var rb := CardDB.RARITIES.find(cb.rarity)
		if ra != rb:
			return ra < rb
		return str(ca.name) < str(cb.name))
	return ids


func _build_grid() -> void:
	var deck := Game.get_deck(_slot)
	for id in _sorted_ids():
		var lvl := Game.level_of(id)
		var cv := CardView.new(id, lvl)
		cv.custom_minimum_size = Vector2(100, 132)
		if lvl <= 0:
			cv.badge = "Locked"
			cv.badge_color = UIKit.PANEL_LIGHT
		else:
			var req := Game.upgrade_requirement(id)
			if req.maxed:
				cv.badge = "MAX"
				cv.progress = 1.0
				cv.badge_color = UIKit.GOLD.darkened(0.2)
			else:
				var have := Game.copies_of(id)
				var need: int = req.copies
				cv.badge = "%d/%d" % [have, need]
				cv.progress = clampf(float(have) / need, 0.0, 1.0)
				cv.badge_color = UIKit.GOLD.darkened(0.2) if have >= need else UIKit.LEAF.darkened(0.15)
		cv.selected = deck.has(id)
		cv.pressed.connect(_open_card)
		_grid.add_child(cv)


# ------------------------------------------------------------------ actions

func _select_slot(i: int) -> void:
	_slot = i
	_pending = ""
	_refresh()


func _open_card(id: String) -> void:
	_pending = ""
	var actions: Array = []
	if Game.owns(id):
		if Game.get_deck(_slot).has(id):
			actions.append({"text": "Remove from deck", "color": UIKit.CORAL, "callback": _remove_from_deck.bind(id)})
		else:
			actions.append({"text": "Add to deck", "color": UIKit.LEAF, "callback": _add_to_deck.bind(id)})
	_refresh()
	CardDetailPopup.open(self, id, actions)


func _on_deck_card(id: String) -> void:
	if _pending != "":
		_swap(id)
	else:
		_open_card(id)


func _add_to_deck(id: String) -> void:
	var deck := Game.get_deck(_slot)
	if deck.has(id) or not Game.owns(id):
		return
	if deck.size() < Game.DECK_SIZE:
		deck.append(id)
		Sfx.play("deploy")
		Game.set_deck(_slot, deck)
	else:
		_pending = id
		_refresh()
		UIKit.toast(self, "Pick a card to swap out", UIKit.GOLD)


func _remove_from_deck(id: String) -> void:
	if _pending != "":
		return
	var deck := Game.get_deck(_slot)
	if not deck.has(id):
		return
	deck.erase(id)
	Sfx.play("click")
	Game.set_deck(_slot, deck)


func _swap(old_id: String) -> void:
	var deck := Game.get_deck(_slot)
	var i := deck.find(old_id)
	if i < 0 or _pending == "":
		return
	deck[i] = _pending
	_pending = ""
	Sfx.play("deploy")
	Game.set_deck(_slot, deck)
