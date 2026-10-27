class_name CurrencyIcon
extends Control
## Procedurally drawn currency icon: "coins" (Seeds), "gems" (Sunshards), "trophies".

@export var kind: String = "coins":
	set(v):
		kind = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	CurrencyIcon.draw_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.45)


static func draw_icon(ci: CanvasItem, k: String, c: Vector2, r: float) -> void:
	match k:
		"coins":
			# A golden seed coin with a sprout.
			ci.draw_circle(c, r, Color("b9771f"))
			ci.draw_circle(c, r * 0.86, Color("f2c14e"))
			ci.draw_circle(c, r * 0.62, Color("e3a832"))
			ci.draw_line(c + Vector2(0, r * 0.45), c + Vector2(0, -r * 0.1), Color("2f7d3a"), maxf(1.5, r * 0.14))
			CardIcons.leaf(ci, c + Vector2(0, -r * 0.1), Vector2(-r * 0.4, -r * 0.35), Color("4cc36b"))
			CardIcons.leaf(ci, c + Vector2(0, -r * 0.1), Vector2(r * 0.4, -r * 0.35), Color("4cc36b"))
		"gems":
			# Sunshard: a faceted crystal with a warm core.
			var pts := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.75, -r * 0.25),
				c + Vector2(r * 0.45, r), c + Vector2(-r * 0.45, r), c + Vector2(-r * 0.75, -r * 0.25)])
			ci.draw_colored_polygon(pts, Color("38c7d9"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, -r * 0.25),
				c + Vector2(0, r * 0.1)]), Color("8ff0f5"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.25), c + Vector2(0, r * 0.1),
				c + Vector2(-r * 0.45, r)]), Color("2496ad"))
			ci.draw_circle(c + Vector2(0, r * 0.1), r * 0.22, Color("ffe27a"))
			pts.append(pts[0])
			ci.draw_polyline(pts, Color("13291f"), maxf(1.0, r * 0.1), true)
		"trophies":
			var gold := Color("f2c14e")
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.8), Vector2(r * 1.2, r * 0.9)), gold)
			ci.draw_circle(c + Vector2(0, r * 0.1), r * 0.6, gold)
			ci.draw_arc(c + Vector2(-r * 0.62, -r * 0.35), r * 0.3, PI * 0.5, PI * 1.5, 10, gold, r * 0.14)
			ci.draw_arc(c + Vector2(r * 0.62, -r * 0.35), r * 0.3, -PI * 0.5, PI * 0.5, 10, gold, r * 0.14)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.55), Vector2(r * 0.3, r * 0.25)), Color("c8952d"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.78), Vector2(r * 1.0, r * 0.22)), Color("c8952d"))
			CardIcons.leaf(ci, c + Vector2(0, -r * 0.2), Vector2(0, -r * 0.45), Color("4cc36b"))
		"energy":
			# Sunlight drop used for card costs.
			ci.draw_circle(c, r, Color("13291f"))
			ci.draw_circle(c, r * 0.86, Color("f2c14e"))
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color("fff1b0"))
