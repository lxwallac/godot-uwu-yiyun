## HUD：时间轴 / 状态 / 读条 / 统计（全部代码创建，无需 .tscn）
class_name YiyunHud
extends CanvasLayer

var _clock: Label
var _state: Label
var _stats: Label
var _hint: Label
var _bars := {}          # key -> {root:Control, name:Label, fill:ColorRect, bg:ColorRect}
var _camera: Camera3D

const BAR_W := 120.0
const BAR_H := 6.0


func _ready() -> void:
	layer = 10

	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.08, 0.11, 0.72)
	panel.position = Vector2(16, 12)
	panel.size = Vector2(420, 74)
	add_child(panel)

	_clock = Label.new()
	_clock.position = Vector2(28, 18)
	_clock.add_theme_font_size_override("font_size", 26)
	_clock.text = "0.00"
	add_child(_clock)

	_state = Label.new()
	_state.position = Vector2(120, 22)
	_state.add_theme_font_size_override("font_size", 15)
	_state.text = "按 空格 开始一运"
	add_child(_state)

	_hint = Label.new()
	_hint.position = Vector2(28, 56)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = Color(0.6, 0.66, 0.75)
	_hint.text = "WASD 走位 · Shift 疾跑 · R 重试 · 空格 开始/暂停"
	add_child(_hint)

	_stats = Label.new()
	_stats.position = Vector2(16, 96)
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.modulate = Color(0.75, 0.8, 0.88)
	_stats.text = "通过 0 / 0"
	add_child(_stats)

	# 四个 Boss 的读条容器
	for key in ["garuda", "ifrit", "titan", "ultima"]:
		var root := Control.new()
		root.size = Vector2(BAR_W, 26)
		root.visible = false
		add_child(root)

		var nm := Label.new()
		nm.position = Vector2(0, 0)
		nm.size = Vector2(BAR_W, 14)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 11)
		root.add_child(nm)

		var bg := ColorRect.new()
		bg.position = Vector2(0, 16)
		bg.size = Vector2(BAR_W, BAR_H)
		bg.color = Color(0, 0, 0, 0.65)
		root.add_child(bg)

		var fill := ColorRect.new()
		fill.position = Vector2(1, 17)
		fill.size = Vector2(0, BAR_H - 2)
		fill.color = Color(0.86, 0.7, 0.23)
		root.add_child(fill)

		_bars[key] = {"root": root, "name": nm, "fill": fill, "bg": bg}


func bind_camera(cam: Camera3D) -> void:
	_camera = cam


func set_clock(t: float) -> void:
	_clock.text = "%.2f" % t


func set_state(text: String) -> void:
	_state.text = text


func set_stats(clear_count: int, total: int, streak: int, last_cause: String) -> void:
	var s := "通过 %d / %d　连胜 %d" % [clear_count, total, streak]
	if last_cause != "":
		s += "　上次死于：" + last_cause
	_stats.text = s


## 更新某个 Boss 的头顶读条
func set_cast(key: String, display_name: String, progress: float, world_pos: Vector3, color: Color, show: bool) -> void:
	if not _bars.has(key):
		return
	var b: Dictionary = _bars[key]
	var root: Control = b.root
	if not show or _camera == null:
		root.visible = false
		return
	var sp := _camera.unproject_position(world_pos)
	root.visible = true
	root.position = sp - Vector2(BAR_W * 0.5, 34.0)
	(b.name as Label).text = display_name
	var f: ColorRect = b.fill
	f.color = color
	f.size = Vector2(maxf(0.0, (BAR_W - 2.0) * clampf(progress, 0.0, 1.0)), BAR_H - 2.0)


func hide_all_casts() -> void:
	for key in _bars:
		(_bars[key].root as Control).visible = false


## 应用中文字体（Godot 默认字体不含 CJK，不设会显示成方框）
func apply_font(f: Font) -> void:
	if f == null:
		return
	for n in find_children("*", "Label", true, false):
		(n as Label).add_theme_font_override("font", f)

