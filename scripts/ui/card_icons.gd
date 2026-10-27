class_name CardIcons
extends RefCounted
## Procedural vector art for every card. Used by card UI and by arena units,
## so no image assets are needed for the prototype.
## draw(ci, id, center, r, team): r is the icon "radius" (half size).

const INK := Color("13291f")
const LEAF_C := Color("4cc36b")
const LEAF_D := Color("2f7d3a")
const SUN := Color("f2c14e")
const SUN_L := Color("ffe27a")
const WOOD := Color("9a6b3f")
const METAL := Color("c9d6d0")
const GLASS := Color("bff3f0")
const PETAL := Color("ff8fb8")
const WATER := Color("5cc8f0")
const ICE := Color("d8f6ff")


static func draw(ci: CanvasItem, id: String, c: Vector2, r: float, team: Color) -> void:
	var w := maxf(1.0, r * 0.08)
	match id:
		"seedling_sprinters", "mossling":
			# Round sprout body with two leaves and little eyes.
			if id == "mossling":
				blob(ci, c, r * 0.75, Color("6a8f4e"), w)
				ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.18, LEAF_C)
				ci.draw_circle(c + Vector2(r * 0.25, r * 0.15), r * 0.2, LEAF_C)
				eyes(ci, c + Vector2(0, -r * 0.05), r * 0.6)
				return
			ci.draw_line(c + Vector2(0, -r * 0.2), c + Vector2(0, -r * 0.65), LEAF_D, w * 1.6)
			leaf(ci, c + Vector2(0, -r * 0.6), Vector2(-r * 0.55, -r * 0.3), LEAF_C)
			leaf(ci, c + Vector2(0, -r * 0.6), Vector2(r * 0.55, -r * 0.35), LEAF_C)
			blob(ci, c + Vector2(0, r * 0.2), r * 0.55, team, w)
			eyes(ci, c + Vector2(0, r * 0.15), r * 0.55)
		"petal_archers":
			ci.draw_arc(c + Vector2(-r * 0.25, 0), r * 0.75, -PI * 0.42, PI * 0.42, 16, WOOD, w * 2.0)
			ci.draw_line(c + Vector2(-r * 0.25 + r * 0.75 * cos(-PI * 0.42), r * 0.75 * sin(-PI * 0.42)),
				c + Vector2(-r * 0.25 + r * 0.75 * cos(PI * 0.42), r * 0.75 * sin(PI * 0.42)), CREAM(), w * 0.8)
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.75, 0), INK, w * 1.4)
			flower(ci, c + Vector2(r * 0.75, 0), r * 0.28, PETAL, SUN)
			leaf(ci, c + Vector2(-r * 0.6, 0), Vector2(-r * 0.3, -r * 0.2), team)
			leaf(ci, c + Vector2(-r * 0.6, 0), Vector2(-r * 0.3, r * 0.2), team)
		"bramble_knight":
			var shield := PackedVector2Array([
				c + Vector2(-r * 0.7, -r * 0.75), c + Vector2(r * 0.7, -r * 0.75), c + Vector2(r * 0.7, 0),
				c + Vector2(0, r * 0.85), c + Vector2(-r * 0.7, 0)])
			ci.draw_colored_polygon(shield, team)
			shield.append(shield[0])
			ci.draw_polyline(shield, INK, w * 1.5, true)
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), LEAF_D, w * 2.0)
			for i in 3:
				var y := -r * 0.4 + i * r * 0.35
				leaf(ci, c + Vector2(0, y), Vector2(-r * 0.35, -r * 0.12), LEAF_C)
				leaf(ci, c + Vector2(0, y + r * 0.12), Vector2(r * 0.35, -r * 0.12), LEAF_C)
		"pollinator_drones":
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				ci.draw_line(c, c + d * r * 0.55, INK, w * 1.2)
				ci.draw_circle(c + d * r * 0.6, r * 0.28, Color(GLASS, 0.85))
				ci.draw_arc(c + d * r * 0.6, r * 0.28, 0, TAU, 14, INK, w)
			blob(ci, c, r * 0.38, team, w)
			ci.draw_circle(c, r * 0.16, SUN)
		"beetle_rider":
			ellipse(ci, c + Vector2(0, r * 0.1), r * 0.62, r * 0.78, team, w)
			ci.draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.85), INK, w * 1.4)
			ci.draw_circle(c + Vector2(-r * 0.28, r * 0.15), r * 0.12, Color(1, 1, 1, 0.35))
			ci.draw_circle(c + Vector2(0, -r * 0.62), r * 0.3, INK)
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(r * 0.15, -r * 1.0), INK, w * 2.0)
			# rider
			ci.draw_circle(c + Vector2(0, -r * 0.1), r * 0.2, SUN)
		"bee_swarm":
			for p in [Vector2(-0.42, -0.32), Vector2(0.42, -0.22), Vector2(0, 0.4)]:
				bee(ci, c + p * r, r * 0.5, team, w)
		"dragonfly_mech":
			for s in [-1.0, 1.0]:
				ellipse(ci, c + Vector2(s * r * 0.48, -r * 0.25), r * 0.45, r * 0.16, Color(GLASS, 0.9), w)
				ellipse(ci, c + Vector2(s * r * 0.42, r * 0.08), r * 0.38, r * 0.14, Color(GLASS, 0.9), w)
			ci.draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.9), team.darkened(0.2), w * 3.0)
			ci.draw_circle(c + Vector2(0, -r * 0.45), r * 0.24, team)
			ci.draw_circle(c + Vector2(-r * 0.1, -r * 0.5), r * 0.08, SUN_L)
			ci.draw_circle(c + Vector2(r * 0.1, -r * 0.5), r * 0.08, SUN_L)
		"moss_golem":
			blob(ci, c + Vector2(0, r * 0.05), r * 0.85, Color("7c8a7a"), w)
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.45), r * 0.3, LEAF_C)
			ci.draw_circle(c + Vector2(r * 0.1, -r * 0.6), r * 0.32, LEAF_C)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.3), r * 0.25, LEAF_D)
			ci.draw_circle(c + Vector2(-r * 0.25, r * 0.15), r * 0.12, team)
			ci.draw_circle(c + Vector2(r * 0.25, r * 0.15), r * 0.12, team)
			ci.draw_line(c + Vector2(-r * 0.2, r * 0.45), c + Vector2(r * 0.2, r * 0.45), INK, w * 1.5)
		"solar_zeppelin":
			ellipse(ci, c + Vector2(0, -r * 0.2), r * 0.9, r * 0.5, team, w)
			for i in 3:
				var x := -r * 0.45 + i * r * 0.45
				ci.draw_line(c + Vector2(x, -r * 0.6), c + Vector2(x, r * 0.2), Color(INK, 0.35), w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.42), Vector2(r * 1.0, r * 0.16)), Color("2f5d8a"))
			ci.draw_line(c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r * 0.2, r * 0.5), INK, w)
			ci.draw_line(c + Vector2(r * 0.25, r * 0.25), c + Vector2(r * 0.2, r * 0.5), INK, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.5), Vector2(r * 0.6, r * 0.3)), WOOD)
		"sun_valkyrie":
			for s in [-1.0, 1.0]:
				var wing := PackedVector2Array([c + Vector2(s * r * 0.2, -r * 0.1), c + Vector2(s * r * 1.0, -r * 0.75),
					c + Vector2(s * r * 0.85, -r * 0.2), c + Vector2(s * r * 0.95, r * 0.1), c + Vector2(s * r * 0.3, r * 0.3)])
				ci.draw_colored_polygon(wing, Color("fff6dc"))
				wing.append(wing[0])
				ci.draw_polyline(wing, INK, w, true)
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.62, 0, TAU, 24, SUN, w * 2.2)
			blob(ci, c + Vector2(0, -r * 0.05), r * 0.36, team, w)
			# helmet crest
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.12, -r * 0.35), c + Vector2(0, -r * 0.75),
				c + Vector2(r * 0.12, -r * 0.35)]), SUN)
			ci.draw_line(c + Vector2(r * 0.3, r * 0.2), c + Vector2(r * 0.75, r * 0.75), METAL, w * 2.0)
		"glacier_gardener":
			blob(ci, c + Vector2(0, r * 0.3), r * 0.5, ICE, w)
			blob(ci, c + Vector2(0, -r * 0.3), r * 0.36, ICE, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.38, -r * 0.08), Vector2(r * 0.76, r * 0.14)), team)
			ci.draw_line(c + Vector2(-r * 0.32, -r * 0.42), c + Vector2(r * 0.32, -r * 0.42), INK, w * 2.0)
			ci.draw_circle(c + Vector2(-r * 0.13, -r * 0.42), r * 0.1, Color("7fd6e0"))
			ci.draw_circle(c + Vector2(r * 0.13, -r * 0.42), r * 0.1, Color("7fd6e0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.28), c + Vector2(r * 0.25, -r * 0.24),
				c + Vector2(0, -r * 0.2)]), Color("ff9a3c"))
			snowflake(ci, c + Vector2(r * 0.65, -r * 0.6), r * 0.25, Color("7fd6e0"), w)
		"sprinkler_tower":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.2), Vector2(r * 0.24, r * 0.9)), METAL)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.6), Vector2(r * 1.0, r * 0.25)), team)
			ci.draw_circle(c + Vector2(0, -r * 0.3), r * 0.32, team)
			ci.draw_arc(c + Vector2(0, -r * 0.3), r * 0.32, 0, TAU, 16, INK, w)
			for a in [-2.4, -1.57, -0.7]:
				var d := Vector2.from_angle(a)
				ci.draw_circle(c + Vector2(0, -r * 0.3) + d * r * 0.62, r * 0.1, WATER)
				ci.draw_circle(c + Vector2(0, -r * 0.3) + d * r * 0.85, r * 0.07, WATER)
		"vine_wall":
			for row in 3:
				for col in 3:
					var off := (r * 0.25) if row % 2 == 1 else 0.0
					var rect := Rect2(c + Vector2(-r * 0.9 + col * r * 0.6 + off - (r * 0.25 if off > 0 and col == 2 else 0.0),
						-r * 0.65 + row * r * 0.45), Vector2(r * 0.55, r * 0.4))
					ci.draw_rect(rect, Color("b98a5a"))
					ci.draw_rect(rect, INK, false, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.9, r * 0.5), c + Vector2(-r * 0.3, -r * 0.2),
				c + Vector2(r * 0.2, r * 0.3), c + Vector2(r * 0.85, -r * 0.5)]), team.darkened(0.1), w * 2.4)
			leaf(ci, c + Vector2(-r * 0.3, -r * 0.2), Vector2(-r * 0.25, -r * 0.25), LEAF_C)
			leaf(ci, c + Vector2(r * 0.2, r * 0.3), Vector2(r * 0.25, r * 0.15), LEAF_C)
		"sunflower_turret":
			ci.draw_line(c + Vector2(0, r * 0.2), c + Vector2(0, r * 0.95), LEAF_D, w * 2.4)
			leaf(ci, c + Vector2(0, r * 0.65), Vector2(-r * 0.4, -r * 0.15), LEAF_C)
			for i in 12:
				var d := Vector2.from_angle(TAU * i / 12.0)
				ellipse_rot(ci, c + Vector2(0, -r * 0.15) + d * r * 0.5, r * 0.22, r * 0.1, d.angle(), SUN)
			ci.draw_circle(c + Vector2(0, -r * 0.15), r * 0.32, WOOD.darkened(0.2))
			ci.draw_circle(c + Vector2(0, -r * 0.15), r * 0.16, team)
		"seed_mortar":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.35), Vector2(r * 1.4, r * 0.45)), team)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.35), Vector2(r * 1.4, r * 0.45)), INK, false, w)
			var tube := PackedVector2Array([c + Vector2(-r * 0.35, r * 0.4), c + Vector2(r * 0.05, -r * 0.75),
				c + Vector2(r * 0.55, -r * 0.6), c + Vector2(r * 0.3, r * 0.4)])
			ci.draw_colored_polygon(tube, METAL)
			tube.append(tube[0])
			ci.draw_polyline(tube, INK, w, true)
			ellipse(ci, c + Vector2(r * 0.65, -r * 0.92), r * 0.16, r * 0.12, WOOD, w)
			leaf(ci, c + Vector2(r * 0.65, -r * 1.0), Vector2(r * 0.15, -r * 0.15), LEAF_C)
		"greenhouse":
			var house := PackedVector2Array([c + Vector2(-r * 0.8, r * 0.75), c + Vector2(-r * 0.8, -r * 0.1),
				c + Vector2(0, -r * 0.8), c + Vector2(r * 0.8, -r * 0.1), c + Vector2(r * 0.8, r * 0.75)])
			ci.draw_colored_polygon(house, Color(GLASS, 0.8))
			house.append(house[0])
			ci.draw_polyline(house, team.darkened(0.25), w * 1.8, true)
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.75), team.darkened(0.25), w)
			ci.draw_line(c + Vector2(-r * 0.8, r * 0.2), c + Vector2(r * 0.8, r * 0.2), team.darkened(0.25), w)
			ci.draw_line(c + Vector2(-r * 0.4, r * 0.7), c + Vector2(-r * 0.4, r * 0.35), LEAF_D, w * 1.4)
			leaf(ci, c + Vector2(-r * 0.4, r * 0.4), Vector2(-r * 0.25, -r * 0.2), LEAF_C)
			leaf(ci, c + Vector2(-r * 0.4, r * 0.45), Vector2(r * 0.25, -r * 0.15), LEAF_C)
			ci.draw_circle(c + Vector2(r * 0.4, r * 0.5), r * 0.16, PETAL)
		"windmill":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.9), c + Vector2(-r * 0.12, -r * 0.3),
				c + Vector2(r * 0.12, -r * 0.3), c + Vector2(r * 0.3, r * 0.9)]), CREAM())
			ci.draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.5), Vector2(r * 0.2, r * 0.4)), team)
			var hub := c + Vector2(0, -r * 0.35)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				var d := Vector2.from_angle(a)
				var n := d.orthogonal()
				var blade := PackedVector2Array([hub + n * r * 0.05, hub + d * r * 0.9 + n * r * 0.05,
					hub + d * r * 0.9 + n * r * 0.25, hub + d * r * 0.25 + n * r * 0.2])
				ci.draw_colored_polygon(blade, team.lightened(0.2))
				blade.append(blade[0])
				ci.draw_polyline(blade, INK, w, true)
			ci.draw_circle(hub, r * 0.12, SUN)
		"prism_lighthouse":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.1, -r * 0.4), c + Vector2(r * 1.0, -r * 0.95),
				c + Vector2(r * 1.0, r * 0.1)]), Color(SUN_L, 0.55))
			var tower := PackedVector2Array([c + Vector2(-r * 0.45, r * 0.9), c + Vector2(-r * 0.25, -r * 0.3),
				c + Vector2(r * 0.05, -r * 0.3), c + Vector2(r * 0.25, r * 0.9)])
			ci.draw_colored_polygon(tower, CREAM())
			ci.draw_rect(Rect2(c + Vector2(-r * 0.36, r * 0.1), Vector2(r * 0.54, r * 0.18)), team)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.55), Vector2(r * 0.6, r * 0.18)), team)
			tower.append(tower[0])
			ci.draw_polyline(tower, INK, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.3), c + Vector2(-r * 0.1, -r * 0.7),
				c + Vector2(r * 0.12, -r * 0.3)]), Color("b56cf0"))
			ci.draw_circle(c + Vector2(-r * 0.1, -r * 0.42), r * 0.1, SUN_L)
		"seed_bomb":
			ellipse(ci, c + Vector2(0, r * 0.15), r * 0.62, r * 0.72, WOOD, w)
			ci.draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.75), WOOD.darkened(0.35), w * 1.2)
			ci.draw_line(c + Vector2(0, -r * 0.55), c + Vector2(r * 0.1, -r * 0.85), LEAF_D, w * 1.6)
			leaf(ci, c + Vector2(r * 0.1, -r * 0.8), Vector2(-r * 0.35, -r * 0.15), LEAF_C)
			leaf(ci, c + Vector2(r * 0.1, -r * 0.8), Vector2(r * 0.4, -r * 0.05), team)
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0 + 0.3)
				ci.draw_line(c + d * r * 0.8, c + d * r * 0.98, SUN, w * 1.4)
		"static_bloom":
			flower(ci, c + Vector2(r * 0.35, r * 0.4), r * 0.35, team.lightened(0.25), SUN)
			var bolt := PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.95), c + Vector2(-r * 0.45, r * 0.05),
				c + Vector2(-r * 0.1, r * 0.05), c + Vector2(-r * 0.35, r * 0.9), c + Vector2(r * 0.35, -r * 0.2),
				c + Vector2(0, -r * 0.2), c + Vector2(r * 0.25, -r * 0.95)])
			ci.draw_colored_polygon(bolt, SUN_L)
			bolt.append(bolt[0])
			ci.draw_polyline(bolt, INK, w, true)
		"root_surge":
			for i in 3:
				var y := -r * 0.55 + i * r * 0.55
				var pts := PackedVector2Array()
				for k in 9:
					var x := -r * 0.9 + k * r * 0.225
					pts.append(c + Vector2(x, y + sin(k * 1.3 + i) * r * 0.12))
				ci.draw_polyline(pts, WOOD.darkened(0.1 * i), w * 3.0, true)
			leaf(ci, c + Vector2(r * 0.85, -r * 0.55), Vector2(r * 0.2, -r * 0.25), LEAF_C)
			leaf(ci, c + Vector2(r * 0.85, 0), Vector2(r * 0.25, -r * 0.2), team)
			leaf(ci, c + Vector2(r * 0.85, r * 0.55), Vector2(r * 0.2, -r * 0.25), LEAF_C)
		"rain_cloud":
			var cl := Color("e8f1f2")
			ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.2), r * 0.35, cl)
			ci.draw_circle(c + Vector2(0, -r * 0.38), r * 0.45, cl)
			ci.draw_circle(c + Vector2(r * 0.42, -r * 0.18), r * 0.36, cl)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.2), Vector2(r * 0.82, r * 0.35)), cl)
			for i in 4:
				var p := c + Vector2(-r * 0.45 + i * r * 0.3, r * 0.45 + (i % 2) * r * 0.2)
				drop(ci, p, r * 0.14, team)
		"solar_flare":
			for i in 10:
				var d := Vector2.from_angle(TAU * i / 10.0)
				var l := r * (0.95 if i % 2 == 0 else 0.7)
				ci.draw_colored_polygon(PackedVector2Array([c + d.orthogonal() * r * 0.15, c + d * l,
					c - d.orthogonal() * r * 0.15]), Color("ff9a3c"))
			ci.draw_circle(c, r * 0.5, SUN)
			ci.draw_circle(c, r * 0.32, SUN_L)
			ci.draw_circle(c, r * 0.14, team)
		"owl_scout":
			for s: float in [-1.0, 1.0]:
				poly(ci, [c + Vector2(s * r * 0.3, -r * 0.3), c + Vector2(s * r * 1.0, -r * 0.65),
					c + Vector2(s * r * 0.98, -r * 0.1), c + Vector2(s * r * 0.8, r * 0.35),
					c + Vector2(s * r * 0.3, r * 0.4)], team.darkened(0.25), w)
				ci.draw_line(c + Vector2(s * r * 0.45, -r * 0.1), c + Vector2(s * r * 0.85, -r * 0.15), INK, w)
				ci.draw_line(c + Vector2(s * r * 0.45, r * 0.12), c + Vector2(s * r * 0.8, r * 0.15), INK, w)
				poly(ci, [c + Vector2(s * r * 0.45, -r * 0.4), c + Vector2(s * r * 0.5, -r * 0.88),
					c + Vector2(s * r * 0.12, -r * 0.6)], team, w)
			ellipse(ci, c + Vector2(0, r * 0.12), r * 0.52, r * 0.66, team, w)
			ellipse(ci, c + Vector2(0, r * 0.34), r * 0.3, r * 0.38, CREAM(), 0.0)
			for s: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * r * 0.23, -r * 0.2), r * 0.25, INK)
				ci.draw_circle(c + Vector2(s * r * 0.23, -r * 0.2), r * 0.2, Color.WHITE)
				ci.draw_circle(c + Vector2(s * r * 0.21, -r * 0.18), r * 0.1, INK)
			poly(ci, [c + Vector2(-r * 0.1, -r * 0.02), c + Vector2(r * 0.1, -r * 0.02), c + Vector2(0, r * 0.2)], SUN, w)
		"ladybug_bombers":
			ladybug(ci, c + Vector2(0, -r * 0.32), r * 0.5, team, w)
			ladybug(ci, c + Vector2(-r * 0.45, r * 0.35), r * 0.5, team, w)
			ladybug(ci, c + Vector2(r * 0.45, r * 0.35), r * 0.5, team, w)
			# lit fuse
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.75), c + Vector2(r * 0.3, -r * 0.82),
				c + Vector2(r * 0.4, -r * 0.7)]), CREAM(), w * 1.8, true)
			star4(ci, c + Vector2(r * 0.48, -r * 0.8), r * 0.3, SUN_L)
			ci.draw_circle(c + Vector2(r * 0.48, -r * 0.8), r * 0.08, Color.WHITE)
		"mantis_mech":
			for s: float in [-1.0, 1.0]:
				# antennae and back legs
				ci.draw_line(c + Vector2(s * r * 0.15, -r * 0.6), c + Vector2(s * r * 0.35, -r * 0.98), INK, w * 1.6)
				ci.draw_line(c + Vector2(s * r * 0.2, r * 0.5), c + Vector2(s * r * 0.6, r * 0.95), INK, w * 3.2)
				# scythe arm: thick upper arm, then a wide curved blade
				ci.draw_line(c + Vector2(s * r * 0.2, -r * 0.05), c + Vector2(s * r * 0.58, -r * 0.45), INK, w * 5.0)
				ci.draw_line(c + Vector2(s * r * 0.2, -r * 0.05), c + Vector2(s * r * 0.58, -r * 0.45), LEAF_C, w * 3.0)
				poly(ci, [c + Vector2(s * r * 0.5, -r * 0.55), c + Vector2(s * r * 1.02, -r * 0.2),
					c + Vector2(s * r * 0.9, r * 0.55), c + Vector2(s * r * 0.66, r * 0.12),
					c + Vector2(s * r * 0.62, -r * 0.18)], METAL, w * 1.2)
			ellipse(ci, c + Vector2(0, r * 0.4), r * 0.38, r * 0.5, team, w * 1.2)
			ci.draw_line(c + Vector2(0, r * 0.12), c + Vector2(0, r * 0.85), INK, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.17, r * 0.22), Vector2(r * 0.34, r * 0.3)), SUN)
			poly(ci, [c + Vector2(-r * 0.26, -r * 0.2), c + Vector2(r * 0.26, -r * 0.2), c + Vector2(r * 0.2, r * 0.22),
				c + Vector2(-r * 0.2, r * 0.22)], LEAF_D, w)
			poly(ci, [c + Vector2(-r * 0.42, -r * 0.68), c + Vector2(r * 0.42, -r * 0.68), c + Vector2(0, -r * 0.14)],
				LEAF_C, w * 1.2)
			for s: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * r * 0.26, -r * 0.56), r * 0.15, SUN_L)
				ci.draw_arc(c + Vector2(s * r * 0.26, -r * 0.56), r * 0.15, 0, TAU, 10, INK, w)
		"hedgehog_roller":
			for i in 3:
				var ly := -r * 0.35 + i * r * 0.35
				ci.draw_line(c + Vector2(-r * 1.0, ly), c + Vector2(-r * 0.55 - i * r * 0.05, ly), Color(CREAM(), 0.7), w * 1.8)
			var spike := Color("5b3d24")
			for i in 14:
				var a := TAU * i / 14.0 + 0.2
				var d := Vector2.from_angle(a)
				var n := d.orthogonal()
				poly(ci, [c + d * r * 0.55 + n * r * 0.17, c + d * r * 0.98, c + d * r * 0.55 - n * r * 0.17], spike, w * 0.8)
			ci.draw_circle(c, r * 0.68, INK)
			ci.draw_circle(c, r * 0.62, Color("8a5e38"))
			ci.draw_arc(c, r * 0.42, PI * 0.85, PI * 1.9, 14, team, w * 2.6, true)
			# face peeking out on the right
			ellipse(ci, c + Vector2(r * 0.38, r * 0.2), r * 0.3, r * 0.26, Color("f0cfa0"), w)
			ci.draw_circle(c + Vector2(r * 0.62, r * 0.2), r * 0.1, INK)
			ci.draw_circle(c + Vector2(r * 0.34, r * 0.08), r * 0.08, INK)
		"thorn_lancer":
			var dir := Vector2(1, -0.8).normalized()
			var nrm := dir.orthogonal()
			# warrior sprite
			ellipse(ci, c + Vector2(-r * 0.42, r * 0.5), r * 0.38, r * 0.42, team, w)
			ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.18), r * 0.32, INK)
			ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.18), r * 0.26, Color("f0cfa0"))
			leaf(ci, c + Vector2(-r * 0.52, -r * 0.36), Vector2(-r * 0.3, -r * 0.34), LEAF_C)
			leaf(ci, c + Vector2(-r * 0.38, -r * 0.4), Vector2(r * 0.08, -r * 0.4), LEAF_C)
			ci.draw_circle(c + Vector2(-r * 0.52, -r * 0.18), r * 0.05, INK)
			ci.draw_circle(c + Vector2(-r * 0.34, -r * 0.18), r * 0.05, INK)
			# the long spear
			var s0 := c - dir * r * 1.0 + Vector2(r * 0.1, r * 0.3)
			var tb := c + dir * r * 0.2 + Vector2(r * 0.1, r * 0.25)
			ci.draw_line(s0, tb, INK, w * 5.0)
			ci.draw_line(s0, tb, WOOD, w * 3.0)
			for k in 3:
				var p := s0.lerp(tb, 0.3 + k * 0.22)
				var sgn := 1.0 if k % 2 == 0 else -1.0
				ci.draw_colored_polygon(PackedVector2Array([p + nrm * sgn * r * 0.05, p + nrm * sgn * r * 0.24 - dir * r * 0.05,
					p - nrm * sgn * r * 0.05 - dir * r * 0.04]), LEAF_D)
			ci.draw_circle(c + Vector2(-r * 0.12, r * 0.45), r * 0.12, Color("f0cfa0"))
			poly(ci, [tb - dir * r * 0.16 + nrm * r * 0.26, tb + dir * r * 0.75, tb - dir * r * 0.16 - nrm * r * 0.26,
				tb + dir * r * 0.0], METAL, w * 1.2)
			ci.draw_line(tb, tb + dir * r * 0.55, Color.WHITE, w * 0.9)
		"treant_guardian":
			ci.draw_circle(c + Vector2(0, -r * 0.1), r * 0.98, Color(SUN, 0.22))
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.94, 0, TAU, 28, Color(SUN, 0.8), w * 1.4, true)
			# arms
			for s: float in [-1.0, 1.0]:
				var arm := PackedVector2Array([c + Vector2(s * r * 0.25, r * 0.25), c + Vector2(s * r * 0.7, r * 0.1),
					c + Vector2(s * r * 0.82, -r * 0.2)])
				ci.draw_polyline(arm, INK, w * 4.4, true)
				ci.draw_polyline(arm, WOOD, w * 2.8, true)
				leaf(ci, c + Vector2(s * r * 0.82, -r * 0.2), Vector2(s * r * 0.12, -r * 0.3), LEAF_C)
				leaf(ci, c + Vector2(s * r * 0.82, -r * 0.2), Vector2(s * r * 0.3, -r * 0.1), LEAF_C)
			# trunk with roots
			poly(ci, [c + Vector2(-r * 0.58, r * 0.92), c + Vector2(-r * 0.32, r * 0.55), c + Vector2(-r * 0.28, -r * 0.2),
				c + Vector2(r * 0.28, -r * 0.2), c + Vector2(r * 0.32, r * 0.55), c + Vector2(r * 0.58, r * 0.92),
				c + Vector2(r * 0.26, r * 0.78), c + Vector2(0, r * 0.92), c + Vector2(-r * 0.26, r * 0.78)], WOOD, w * 1.2)
			ci.draw_line(c + Vector2(-r * 0.16, r * 0.55), c + Vector2(-r * 0.14, r * 0.8), WOOD.darkened(0.35), w)
			ci.draw_line(c + Vector2(r * 0.17, r * 0.5), c + Vector2(r * 0.15, r * 0.75), WOOD.darkened(0.35), w)
			# crown
			puff(ci, c + Vector2(-r * 0.52, -r * 0.4), r * 0.4, LEAF_D, w)
			puff(ci, c + Vector2(r * 0.52, -r * 0.4), r * 0.4, LEAF_D, w)
			puff(ci, c + Vector2(0, -r * 0.62), r * 0.5, LEAF_C, w)
			puff(ci, c + Vector2(-r * 0.22, -r * 0.36), r * 0.34, LEAF_C, w)
			puff(ci, c + Vector2(r * 0.24, -r * 0.34), r * 0.34, LEAF_D.lightened(0.15), w)
			ci.draw_circle(c + Vector2(-r * 0.15, -r * 0.82), r * 0.1, SUN)
			ci.draw_circle(c + Vector2(r * 0.4, -r * 0.62), r * 0.09, PETAL)
			ci.draw_circle(c + Vector2(-r * 0.62, -r * 0.45), r * 0.08, PETAL)
			# face
			for s: float in [-1.0, 1.0]:
				poly(ci, [c + Vector2(s * r * 0.19 - r * 0.1, r * 0.02), c + Vector2(s * r * 0.19 + r * 0.1, r * 0.02),
					c + Vector2(s * r * 0.19, r * 0.2)], SUN_L, w * 0.6)
			ci.draw_line(c + Vector2(-r * 0.14, r * 0.38), c + Vector2(r * 0.14, r * 0.38), INK, w * 1.4)
		"bramble_patch":
			ellipse(ci, c + Vector2(0, r * 0.38), r * 0.98, r * 0.5, LEAF_D, w)
			var vine := WOOD.darkened(0.25)
			for i in 3:
				var pts := PackedVector2Array()
				for k in 11:
					var x := -r * 0.9 + k * r * 0.18
					pts.append(c + Vector2(x, r * (0.45 - i * 0.28) + sin(k * 1.1 + i * 2.0) * r * 0.16))
				ci.draw_polyline(pts, INK, w * 4.4, true)
				ci.draw_polyline(pts, vine.lightened(0.08 * i), w * 2.8, true)
			for i in 2:
				var arc := PackedVector2Array()
				for k in 9:
					var t := k / 8.0
					arc.append(c + Vector2(lerpf(-r * 0.7, r * 0.7, t) + (i * 2 - 1) * r * 0.1 * sin(t * PI),
						r * 0.75 - sin(t * PI) * r * (1.05 - i * 0.2)))
				ci.draw_polyline(arc, INK, w * 3.8, true)
				ci.draw_polyline(arc, vine, w * 2.2, true)
			# thorns
			var thorn := Color("f1e6c0")
			for p: Vector2 in [Vector2(-0.7, 0.1), Vector2(-0.35, -0.2), Vector2(0.05, -0.45), Vector2(0.45, -0.2),
					Vector2(0.75, 0.15), Vector2(-0.15, 0.2), Vector2(0.3, 0.45), Vector2(-0.55, 0.55)]:
				var q: Vector2 = c + p * r
				var up: Vector2 = Vector2(p.x * 0.6, -1.0).normalized()
				ci.draw_colored_polygon(PackedVector2Array([q - up.orthogonal() * r * 0.07, q + up * r * 0.26,
					q + up.orthogonal() * r * 0.07]), thorn)
				ci.draw_line(q - up.orthogonal() * r * 0.07, q + up * r * 0.26, INK, w * 0.7)
			leaf(ci, c + Vector2(-r * 0.4, r * 0.55), Vector2(-r * 0.3, r * 0.1), LEAF_C)
			leaf(ci, c + Vector2(r * 0.55, r * 0.5), Vector2(r * 0.3, r * 0.15), LEAF_C)
			leaf(ci, c + Vector2(r * 0.05, -r * 0.35), Vector2(-r * 0.05, -r * 0.3), LEAF_C)
			ci.draw_circle(c + Vector2(r * 0.18, r * 0.05), r * 0.12, team)
			ci.draw_circle(c + Vector2(-r * 0.45, r * 0.0), r * 0.1, team)
		"bloom_fountain":
			# nectar spray
			var nectar := SUN
			for b: Vector2 in [Vector2(-0.62, -0.55), Vector2(0.0, -0.82), Vector2(0.62, -0.5)]:
				var from := c + Vector2(0, -r * 0.15)
				var to := c + b * r
				var mid := from.lerp(to, 0.5) + Vector2(0, -r * 0.12)
				ci.draw_polyline(PackedVector2Array([from, mid, to]), Color(nectar, 0.55), w * 2.4, true)
				ci.draw_circle(to, r * 0.25, INK)
				ci.draw_circle(to, r * 0.2, nectar)
				ci.draw_circle(to + Vector2(-r * 0.06, -r * 0.07), r * 0.06, Color.WHITE)
			# vase
			poly(ci, [c + Vector2(-r * 0.3, -r * 0.12), c + Vector2(r * 0.3, -r * 0.12), c + Vector2(r * 0.52, r * 0.7),
				c + Vector2(-r * 0.52, r * 0.7)], GLASS, w * 1.2)
			poly(ci, [c + Vector2(-r * 0.4, r * 0.25), c + Vector2(r * 0.4, r * 0.25), c + Vector2(r * 0.5, r * 0.68),
				c + Vector2(-r * 0.5, r * 0.68)], nectar, 0.0)
			ci.draw_line(c + Vector2(-r * 0.4, r * 0.25), c + Vector2(r * 0.4, r * 0.25), SUN_L, w * 1.2)
			ci.draw_circle(c + Vector2(-r * 0.13, r * 0.42), r * 0.06, INK)
			ci.draw_circle(c + Vector2(r * 0.13, r * 0.42), r * 0.06, INK)
			ci.draw_arc(c + Vector2(0, r * 0.45), r * 0.12, 0.2, PI - 0.2, 8, INK, w)
			ellipse(ci, c + Vector2(0, -r * 0.12), r * 0.3, r * 0.08, GLASS.darkened(0.2), w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.68, r * 0.7), Vector2(r * 1.36, r * 0.2)), team)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.68, r * 0.7), Vector2(r * 1.36, r * 0.2)), INK, false, w)
			ci.draw_line(c + Vector2(-r * 0.3, 0.0), c + Vector2(-r * 0.4, r * 0.15), Color(1, 1, 1, 0.7), w * 1.4)
		"mycelium_spread":
			var thread := Color("fffbea")
			var base_y := r * 0.52
			# branching fungal threads
			var net := [
				[Vector2(0, 0.52), Vector2(-0.4, 0.68), Vector2(-0.85, 0.6)],
				[Vector2(-0.4, 0.68), Vector2(-0.6, 0.92)],
				[Vector2(-0.4, 0.68), Vector2(-0.25, 0.95)],
				[Vector2(0, 0.52), Vector2(0.4, 0.72), Vector2(0.88, 0.62)],
				[Vector2(0.4, 0.72), Vector2(0.55, 0.95)],
				[Vector2(0.4, 0.72), Vector2(0.2, 0.95)],
				[Vector2(-0.85, 0.6), Vector2(-0.95, 0.4)],
				[Vector2(0.88, 0.62), Vector2(0.97, 0.42)]]
			for pass_i in 2:
				for seg: Array in net:
					var pts := PackedVector2Array()
					for v: Vector2 in seg:
						pts.append(c + v * r)
					ci.draw_polyline(pts, INK if pass_i == 0 else thread, w * (3.4 if pass_i == 0 else 1.8), true)
			for tip: Vector2 in [Vector2(-0.6, 0.92), Vector2(-0.25, 0.95), Vector2(0.55, 0.95), Vector2(0.2, 0.95),
					Vector2(-0.95, 0.4), Vector2(0.97, 0.42)]:
				ci.draw_circle(c + tip * r, r * 0.07, thread)
			# stalks
			for m: Array in [[-0.12, 0.0, 0.2], [0.58, 0.25, 0.14]]:
				var sx: float = m[0]
				var sy: float = m[1]
				var sw: float = m[2]
				poly(ci, [c + Vector2((sx - sw * 0.5) * r, (sy + 0.1) * r), c + Vector2((sx + sw * 0.5) * r, (sy + 0.1) * r),
					c + Vector2((sx + sw * 0.7) * r, base_y), c + Vector2((sx - sw * 0.7) * r, base_y)], CREAM(), w)
			cap(ci, c + Vector2(-r * 0.12, r * 0.05), r * 0.62, r * 0.55, team, w)
			for p: Vector2 in [Vector2(-0.35, -0.25), Vector2(0.0, -0.4), Vector2(0.12, -0.1), Vector2(-0.3, 0.0)]:
				ci.draw_circle(c + Vector2(-0.12, 0.05) * r + p * r * 0.9, r * 0.09, CREAM())
			cap(ci, c + Vector2(r * 0.58, r * 0.3), r * 0.36, r * 0.32, PETAL, w)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.15), r * 0.05, CREAM())
			ci.draw_circle(c + Vector2(r * 0.7, r * 0.2), r * 0.05, CREAM())
		"sunlit_renewal":
			poly(ci, [c + Vector2(-r * 0.2, -r * 0.85), c + Vector2(r * 0.3, -r * 0.85), c + Vector2(r * 0.95, r * 0.95),
				c + Vector2(-r * 0.85, r * 0.95)], Color("fff2b0", 0.6), 0.0)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(c + Vector2(r * 0.05, -r * 0.8) + d * r * 0.38, c + Vector2(r * 0.05, -r * 0.8) + d * r * 0.55, SUN, w * 1.6)
			ci.draw_circle(c + Vector2(r * 0.05, -r * 0.8), r * 0.3, INK)
			ci.draw_circle(c + Vector2(r * 0.05, -r * 0.8), r * 0.25, SUN)
			ci.draw_circle(c + Vector2(r * 0.05, -r * 0.8), r * 0.13, SUN_L)
			var t := 0.15
			var a := 0.46
			var plus: Array = []
			for v: Vector2 in [Vector2(-t, -a), Vector2(t, -a), Vector2(t, -t), Vector2(a, -t), Vector2(a, t), Vector2(t, t),
					Vector2(t, a), Vector2(-t, a), Vector2(-t, t), Vector2(-a, t), Vector2(-a, -t), Vector2(-t, -t)]:
				plus.append(c + Vector2(0.0, r * 0.28) + v * r)
			poly(ci, plus, LEAF_C, w * 1.4)
			ci.draw_circle(c + Vector2(0, r * 0.28), r * 0.1, team.lightened(0.3))
			star4(ci, c + Vector2(-r * 0.62, r * 0.05), r * 0.22, SUN_L)
			star4(ci, c + Vector2(r * 0.68, r * 0.05), r * 0.26, Color.WHITE)
			star4(ci, c + Vector2(r * 0.55, r * 0.78), r * 0.2, SUN_L)
			star4(ci, c + Vector2(-r * 0.55, r * 0.7), r * 0.16, Color.WHITE)
		_:
			blob(ci, c, r * 0.7, team, w)


# ------------------------------------------------------------------ primitives

static func CREAM() -> Color:
	return Color("f6efd9")


static func leaf(ci: CanvasItem, base: Vector2, tip_off: Vector2, col: Color) -> void:
	var tip := base + tip_off
	var n := tip_off.orthogonal() * 0.35
	var mid := base + tip_off * 0.5
	ci.draw_colored_polygon(PackedVector2Array([base, mid + n, tip, mid - n]), col)
	ci.draw_line(base, tip, col.darkened(0.3), maxf(1.0, tip_off.length() * 0.06))


static func blob(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_circle(c, r, col)
	ci.draw_arc(c, r, 0, TAU, 24, INK, w * 1.4, true)
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.3))


static func eyes(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(-r * 0.3, 0), r * 0.16, Color.WHITE)
	ci.draw_circle(c + Vector2(r * 0.3, 0), r * 0.16, Color.WHITE)
	ci.draw_circle(c + Vector2(-r * 0.27, r * 0.03), r * 0.08, INK)
	ci.draw_circle(c + Vector2(r * 0.33, r * 0.03), r * 0.08, INK)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float = 0.0) -> void:
	ellipse_rot(ci, c, rx, ry, 0.0, col, w)


static func ellipse_rot(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color, w: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, col)
	if w > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, w, true)


static func flower(ci: CanvasItem, c: Vector2, r: float, petal: Color, center: Color) -> void:
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
		ci.draw_circle(c + d * r * 0.55, r * 0.42, petal)
	ci.draw_circle(c, r * 0.38, center)


static func bee(ci: CanvasItem, c: Vector2, r: float, team: Color, _w: float) -> void:
	# Stroke widths follow the bee's own size (the card-wide width made it all black).
	var bw := maxf(0.8, r * 0.09)
	ellipse(ci, c + Vector2(-r * 0.15, -r * 0.5), r * 0.38, r * 0.24, Color(GLASS, 0.9), bw * 0.6)
	ellipse(ci, c + Vector2(r * 0.25, -r * 0.5), r * 0.38, r * 0.24, Color(GLASS, 0.9), bw * 0.6)
	ellipse(ci, c, r * 0.68, r * 0.46, SUN, bw * 0.8)
	ci.draw_line(c + Vector2(-r * 0.12, -r * 0.4), c + Vector2(-r * 0.12, r * 0.4), INK, bw * 1.3)
	ci.draw_line(c + Vector2(r * 0.22, -r * 0.38), c + Vector2(r * 0.22, r * 0.38), INK, bw * 1.3)
	ci.draw_circle(c + Vector2(-r * 0.66, 0), r * 0.2, team)


static func drop(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.3), c + Vector2(0, -r * 2.0),
		c + Vector2(r * 0.9, -r * 0.3)]), col)


## Filled polygon with an INK outline (w <= 0 skips the outline). pts is any array of Vector2.
static func poly(ci: CanvasItem, pts: Array, col: Color, w: float) -> void:
	var pv := PackedVector2Array()
	for p: Vector2 in pts:
		pv.append(p)
	ci.draw_colored_polygon(pv, col)
	if w > 0.0:
		pv.append(pv[0])
		ci.draw_polyline(pv, INK, w, true)


## Outlined circle ("bush puff").
static func puff(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_circle(c, r + w * 0.9, INK)
	ci.draw_circle(c, r, col)


## Four-point sparkle.
static func star4(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var k := 0.28
	var pv := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * k, -r * k), c + Vector2(r, 0), c + Vector2(r * k, r * k),
		c + Vector2(0, r), c + Vector2(-r * k, r * k), c + Vector2(-r, 0), c + Vector2(-r * k, -r * k)])
	ci.draw_colored_polygon(pv, col)


## Mushroom cap: dome with flat underside. c is the center of the underside line.
static func cap(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
	var rim := PackedVector2Array(pts)
	rim.append(rim[0])
	ci.draw_polyline(rim, INK, w * 1.2, true)


## Small ladybug seen from above; s is its radius.
static func ladybug(ci: CanvasItem, c: Vector2, s: float, shell: Color, w: float) -> void:
	ci.draw_circle(c + Vector2(0, -s * 0.78), s * 0.34, INK)
	ellipse(ci, c, s * 0.82, s * 0.9, shell, w * 1.2)
	ci.draw_line(c + Vector2(0, -s * 0.85), c + Vector2(0, s * 0.88), INK, w * 1.2)
	for p: Vector2 in [Vector2(-0.4, -0.25), Vector2(0.4, -0.25), Vector2(-0.42, 0.35), Vector2(0.42, 0.35)]:
		ci.draw_circle(c + p * s, s * 0.17, INK)


static func snowflake(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	for i in 3:
		var d := Vector2.from_angle(PI * i / 3.0)
		ci.draw_line(c - d * r, c + d * r, col, w * 1.4)
