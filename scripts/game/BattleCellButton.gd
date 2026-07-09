extends Button

const TERRAIN_NORMAL := "normal"
const TERRAIN_SPIRIT := "spirit"
const TERRAIN_ROCK := "rock"
const PIECE_NONE := ""
const PIECE_PLAYER := "player"
const PIECE_PLAYER_TEMP := "player_temp"
const PIECE_ENEMY := "enemy"
const MARK_NONE := ""
const MARK_SEALED := "sealed"
const MARK_SKILL_TARGET := "skill_target"
const MARK_WARNING := "warning"

var terrain_kind := TERRAIN_NORMAL
var piece_kind := PIECE_NONE
var marker_kind := MARK_NONE
var is_winning_cell := false
var is_last_move_cell := false
var feedback_kind := ""


func set_visual_state(terrain: String, piece: String, marker: String, winning: bool, last_move: bool, feedback: String) -> void:
	terrain_kind = terrain
	piece_kind = piece
	marker_kind = marker
	is_winning_cell = winning
	is_last_move_cell = last_move
	feedback_kind = feedback
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_draw_cell_bevel(rect)

	match terrain_kind:
		TERRAIN_SPIRIT:
			_draw_spirit(rect)
		TERRAIN_ROCK:
			_draw_rock(rect)

	match marker_kind:
		MARK_SEALED:
			_draw_seal(rect)
		MARK_SKILL_TARGET:
			_draw_skill_target(rect)
		MARK_WARNING:
			_draw_warning(rect)

	match piece_kind:
		PIECE_PLAYER:
			_draw_player_piece(rect, false)
		PIECE_PLAYER_TEMP:
			_draw_player_piece(rect, true)
		PIECE_ENEMY:
			_draw_enemy_piece(rect)

	if is_winning_cell:
		_draw_win_rim(rect)
	elif is_last_move_cell:
		_draw_last_move_rim(rect)

	if not feedback_kind.is_empty():
		_draw_feedback_glow(rect)


func _draw_cell_bevel(rect: Rect2) -> void:
	var tl := rect.position + Vector2(5, 5)
	var tr := rect.position + Vector2(rect.size.x - 5, 5)
	var bl := rect.position + Vector2(5, rect.size.y - 5)
	var br := rect.position + rect.size - Vector2(5, 5)
	draw_line(tl, tr, Color(1, 0.91, 0.62, 0.28), 2.0)
	draw_line(tl, bl, Color(1, 0.91, 0.62, 0.18), 1.5)
	draw_line(bl, br, Color(0.18, 0.09, 0.02, 0.34), 2.0)
	draw_line(tr, br, Color(0.18, 0.09, 0.02, 0.26), 1.5)


func _draw_spirit(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_circle(center, rect.size.x * 0.28, Color(0.14, 0.78, 0.63, 0.20))
	draw_circle(center, rect.size.x * 0.18, Color(0.35, 0.98, 0.79, 0.35))
	var star := PackedVector2Array([
		center + Vector2(0, -13),
		center + Vector2(5, -4),
		center + Vector2(13, 0),
		center + Vector2(5, 4),
		center + Vector2(0, 13),
		center + Vector2(-5, 4),
		center + Vector2(-13, 0),
		center + Vector2(-5, -4),
	])
	draw_colored_polygon(star, Color("#dfffee"))
	draw_polyline(star, Color("#2e8c7e"), 2.0, true)
	draw_circle(center, 3.0, Color("#1f4e45"))


func _draw_rock(rect: Rect2) -> void:
	var center := rect.get_center()
	var shadow := PackedVector2Array([
		center + Vector2(-15, -7),
		center + Vector2(2, -17),
		center + Vector2(17, -6),
		center + Vector2(16, 11),
		center + Vector2(1, 18),
		center + Vector2(-17, 9),
	])
	var shadow_offset := PackedVector2Array()
	for point in shadow:
		shadow_offset.append(point + Vector2(3, 4))
	draw_colored_polygon(shadow_offset, Color(0.03, 0.025, 0.02, 0.45))
	draw_colored_polygon(shadow, Color("#4e4037"))

	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-15, -7),
		center + Vector2(2, -17),
		center + Vector2(1, 1),
		center + Vector2(-7, 6),
	]), Color("#726153"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(2, -17),
		center + Vector2(17, -6),
		center + Vector2(1, 1),
	]), Color("#8a7562"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(17, -6),
		center + Vector2(16, 11),
		center + Vector2(1, 1),
	]), Color("#3c322c"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(16, 11),
		center + Vector2(1, 18),
		center + Vector2(1, 1),
	]), Color("#302822"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(1, 18),
		center + Vector2(-17, 9),
		center + Vector2(-7, 6),
		center + Vector2(1, 1),
	]), Color("#5a493d"))
	draw_polyline(shadow, Color("#211915"), 2.4, true)
	draw_line(center + Vector2(-7, 6), center + Vector2(1, 1), Color("#241b16"), 1.3)
	draw_line(center + Vector2(1, 1), center + Vector2(9, -8), Color(1, 0.86, 0.61, 0.20), 1.2)
	draw_line(center + Vector2(-8, -7), center + Vector2(1, -12), Color(1, 0.86, 0.61, 0.18), 1.2)


func _draw_player_piece(rect: Rect2, temporary: bool) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.27
	draw_circle(center + Vector2(2, 3), radius, Color(0.04, 0.03, 0.02, 0.38))
	draw_circle(center, radius, Color("#f2ead9") if not temporary else Color("#d5c28d"))
	draw_arc(center, radius - 1, -PI * 0.1, PI * 1.16, 40, Color("#425d67"), 2.0)
	draw_circle(center + Vector2(-6, -6), radius * 0.36, Color(1, 1, 1, 0.50))
	draw_circle(center + Vector2(1, 1), radius * 0.18, Color("#253844"))


func _draw_enemy_piece(rect: Rect2) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array([
		center + Vector2(0, -15),
		center + Vector2(14, -2),
		center + Vector2(4, 15),
		center + Vector2(-14, 3),
	])
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0.02, 0.02, 0.03, 0.45))
	draw_colored_polygon(points, Color("#283446"))
	draw_colored_polygon(PackedVector2Array([points[0], points[1], center]), Color("#59687a"))
	draw_colored_polygon(PackedVector2Array([points[1], points[2], center]), Color("#1f2938"))
	draw_colored_polygon(PackedVector2Array([points[2], points[3], center]), Color("#111925"))
	draw_colored_polygon(PackedVector2Array([points[3], points[0], center]), Color("#3e4d62"))
	draw_polyline(points, Color("#d7e2e6"), 1.7, true)
	draw_circle(center + Vector2(-2, -5), 3.2, Color("#e9f4f7"))


func _draw_seal(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_arc(center, 15, PI * 0.12, PI * 1.86, 40, Color("#f0c65a"), 2.0)
	draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), Color("#f0c65a"), 1.5)


func _draw_skill_target(rect: Rect2) -> void:
	var center := rect.get_center()
	var target := PackedVector2Array([
		center + Vector2(0, -14),
		center + Vector2(14, 0),
		center + Vector2(0, 14),
		center + Vector2(-14, 0),
	])
	draw_polyline(target, Color("#fff0a8"), 2.0, true)
	draw_circle(center, 3.0, Color("#fff0a8"))


func _draw_warning(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_line(center + Vector2(0, -12), center + Vector2(0, 4), Color("#fff0bf"), 3.0)
	draw_circle(center + Vector2(0, 12), 2.4, Color("#fff0bf"))


func _draw_win_rim(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(5, 5), rect.size - Vector2(10, 10)), Color("#fff0bd"), false, 3.0)


func _draw_last_move_rim(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(6, 6), rect.size - Vector2(12, 12)), Color("#8fd3c4"), false, 2.0)


func _draw_feedback_glow(rect: Rect2) -> void:
	var glow := Color("#fff0a8")
	match feedback_kind:
		"player":
			glow = Color("#85d8ff")
		"enemy":
			glow = Color("#ff8b78")
		"rock":
			glow = Color("#f2b35e")
		"energy":
			glow = Color("#9affdf")
		"skill":
			glow = Color("#d4c4ff")
	draw_rect(Rect2(Vector2(4, 4), rect.size - Vector2(8, 8)), Color(glow.r, glow.g, glow.b, 0.68), false, 3.0)
