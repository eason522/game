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
const MATERIAL_TIER := "single_board_v3"

var terrain_kind := TERRAIN_NORMAL
var piece_kind := PIECE_NONE
var marker_kind := MARK_NONE
var is_winning_cell := false
var is_last_move_cell := false
var feedback_kind := ""
var board_position := Vector2i.ZERO
var material_tier := MATERIAL_TIER


func set_board_position(pos: Vector2i) -> void:
	board_position = pos
	queue_redraw()


func get_material_tier() -> String:
	return material_tier


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
	_draw_board_cell(rect)

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


func _draw_board_cell(rect: Rect2) -> void:
	var tone: float = _seeded_variation(0, 0.045)
	var base := Color("#c99f55").lightened(max(tone, 0.0)).darkened(max(-tone, 0.0))
	var grain := Color("#805b2a")
	draw_rect(rect, base, true)

	if board_position.x == 0:
		draw_line(Vector2(0, 0), Vector2(0, rect.size.y), Color("#4a2d14"), 1.6)
	if board_position.y == 0:
		draw_line(Vector2(0, 0), Vector2(rect.size.x, 0), Color("#4a2d14"), 1.6)

	draw_line(Vector2(rect.size.x - 1, 0), rect.size - Vector2(1, 0), Color(0.21, 0.12, 0.04, 0.45), 1.0)
	draw_line(Vector2(0, rect.size.y - 1), rect.size - Vector2(0, 1), Color(0.21, 0.12, 0.04, 0.45), 1.0)
	draw_line(Vector2(rect.size.x - 2, 0), rect.size - Vector2(2, 0), Color(1.0, 0.82, 0.44, 0.08), 0.7)
	draw_line(Vector2(0, rect.size.y - 2), rect.size - Vector2(0, 2), Color(1.0, 0.82, 0.44, 0.06), 0.7)
	_draw_cell_grain(rect.grow(-8), grain)


func _draw_cell_grain(face: Rect2, grain_color: Color) -> void:
	for index in range(3):
		var start_x: float = face.position.x + 4.0 + float(index) * 8.0 + _seeded_variation(index, 2.0)
		var y: float = face.position.y + 8.0 + _seeded_variation(index + 3, 4.0)
		var end_x: float = min(face.position.x + face.size.x - 4.0, start_x + 11.0 + _seeded_variation(index + 6, 3.0))
		draw_line(Vector2(start_x, y), Vector2(end_x, y + _seeded_variation(index + 9, 1.5)), Color(grain_color.r, grain_color.g, grain_color.b, 0.22), 0.8)


func _seeded_variation(index: int, span: float) -> float:
	var raw: int = (board_position.x * 31 + board_position.y * 47 + index * 17) % 100
	return (float(raw) / 99.0 - 0.5) * span


func _draw_spirit(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(1, 2), rect.size.x * 0.37, Color(0.02, 0.12, 0.10, 0.24))
	draw_circle(center, rect.size.x * 0.34, Color(0.08, 0.62, 0.50, 0.26))
	draw_circle(center, rect.size.x * 0.24, Color(0.42, 0.96, 0.78, 0.30))
	var star := PackedVector2Array([
		center + Vector2(0, -16),
		center + Vector2(6, -6),
		center + Vector2(16, 0),
		center + Vector2(6, 6),
		center + Vector2(0, 16),
		center + Vector2(-6, 6),
		center + Vector2(-16, 0),
		center + Vector2(-6, -6),
	])
	draw_colored_polygon(star, Color("#dbfff0"))
	draw_polyline(star, Color("#146f62"), 2.0, true)
	draw_circle(center, 4.0, Color("#f6fff7"))
	draw_circle(center, 2.2, Color("#1f4e45"))


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
		shadow_offset.append(point + Vector2(4, 5))
	draw_colored_polygon(shadow_offset, Color(0.03, 0.025, 0.02, 0.42))
	draw_colored_polygon(shadow, Color("#46382f"))

	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-15, -7),
		center + Vector2(2, -17),
		center + Vector2(1, 1),
		center + Vector2(-7, 6),
	]), Color("#837160"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(2, -17),
		center + Vector2(17, -6),
		center + Vector2(1, 1),
	]), Color("#9a836b"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(17, -6),
		center + Vector2(16, 11),
		center + Vector2(1, 1),
	]), Color("#3a3029"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(16, 11),
		center + Vector2(1, 18),
		center + Vector2(1, 1),
	]), Color("#2a221d"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(1, 18),
		center + Vector2(-17, 9),
		center + Vector2(-7, 6),
		center + Vector2(1, 1),
	]), Color("#604f42"))
	draw_polyline(shadow, Color("#1c1512"), 2.6, true)
	draw_line(center + Vector2(-7, 6), center + Vector2(1, 1), Color("#241b16"), 1.3)
	draw_line(center + Vector2(1, 1), center + Vector2(10, -8), Color(1, 0.86, 0.61, 0.24), 1.3)
	draw_line(center + Vector2(-8, -7), center + Vector2(1, -12), Color(1, 0.86, 0.61, 0.22), 1.3)


func _draw_player_piece(rect: Rect2, temporary: bool) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.29
	draw_circle(center + Vector2(3, 4), radius, Color(0.04, 0.03, 0.02, 0.42))
	draw_circle(center + Vector2(0, 1), radius, Color("#a98b54") if temporary else Color("#b6a174"))
	draw_circle(center, radius - 2.0, Color("#efe4cf") if not temporary else Color("#d3bd83"))
	draw_circle(center + Vector2(-4, -4), radius * 0.58, Color(1, 0.97, 0.84, 0.34))
	draw_arc(center, radius - 1, -PI * 0.08, PI * 1.16, 42, Color("#435a63"), 2.0)
	draw_arc(center + Vector2(1, 1), radius - 5, PI * 0.35, PI * 1.20, 28, Color(0.26, 0.19, 0.10, 0.22), 1.4)
	draw_circle(center + Vector2(-6, -7), radius * 0.28, Color(1, 1, 1, 0.58))
	draw_circle(center + Vector2(1, 1), radius * 0.14, Color("#243844"))


func _draw_enemy_piece(rect: Rect2) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array()
	for index in range(8):
		var angle := -PI * 0.5 + float(index) * TAU / 8.0
		var radius := 15.0 if index % 2 == 0 else 13.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0.02, 0.02, 0.03, 0.45))
	draw_colored_polygon(points, Color("#222b36"))
	draw_colored_polygon(PackedVector2Array([points[0], points[1], points[2], center]), Color("#536170"))
	draw_colored_polygon(PackedVector2Array([points[2], points[3], points[4], center]), Color("#1b2430"))
	draw_colored_polygon(PackedVector2Array([points[4], points[5], points[6], center]), Color("#101722"))
	draw_colored_polygon(PackedVector2Array([points[6], points[7], points[0], center]), Color("#394657"))
	draw_polyline(points, Color("#cad7dc"), 1.7, true)
	draw_circle(center + Vector2(-4, -6), 3.2, Color("#e8f1f2"))
	draw_circle(center + Vector2(2, 3), 4.0, Color(0.02, 0.02, 0.03, 0.24))


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
	draw_rect(Rect2(Vector2(3, 3), rect.size - Vector2(6, 6)), Color("#fff0bd"), false, 3.0)


func _draw_last_move_rim(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(4, 4), rect.size - Vector2(8, 8)), Color("#8fd3c4"), false, 2.0)


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
	draw_rect(Rect2(Vector2(3, 3), rect.size - Vector2(6, 6)), Color(glow.r, glow.g, glow.b, 0.68), false, 3.0)
