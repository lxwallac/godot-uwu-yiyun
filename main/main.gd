## 入口：搭场景 + 跑一运
extends Node3D

var D: YiyunData
var hud: YiyunHud
var seq: YiyunSequence
var player: PlayerController
var cam: Camera3D
var rng := RandomNumberGenerator.new()
var ui_font: Font = null

var total_runs := 0
var total_clear := 0
var streak := 0
var last_cause := ""

const CAM_HEIGHT := 26.0
const CAM_BACK := 22.0

const FONT_DIR := "res://assets/fonts"


## 扫描 assets/fonts 下的字体文件（中文必需）
func _load_font() -> void:
	var dir := DirAccess.open(FONT_DIR)
	if dir == null:
		push_warning("没有 assets/fonts 目录，中文会显示成方框。把 msyh.ttc 放进去即可。")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext := fname.get_extension().to_lower()
			if ext in ["ttf", "otf", "ttc", "woff", "woff2"]:
				ui_font = load(FONT_DIR + "/" + fname)
				if ui_font != null:
					print("已加载字体: ", fname)
					break
		fname = dir.get_next()
	dir.list_dir_end()


func _ready() -> void:
	D = YiyunData.new()
	if not D.load_data():
		push_error("数据加载失败")
		return

	_load_font()
	_build_environment()
	_build_arena()
	_build_marks()

	player = PlayerController.new()
	player.walk_speed = float(D.move.get("walk", 6.0))
	player.sprint_mul = float(D.move.get("sprint_mul", 1.5))
	player.wall_x = D.wall_x
	player.body_r = float(D.hit.get("body_r", 0.45))
	add_child(player)
	player.died.connect(_on_player_died)

	hud = YiyunHud.new()
	add_child(hud)
	hud.bind_camera(cam)
	hud.apply_font(ui_font)

	seq = YiyunSequence.new()
	add_child(seq)
	seq.ui_font = ui_font
	seq.setup(D, hud, cam, player)
	seq.finished_clear.connect(_on_clear)
	seq.finished_dead.connect(_on_dead)

	rng.randomize()
	_update_stats_label()
	hud.set_state("按 空格 开始一运")


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.36, 0.45)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.06, 0.09)
	e.fog_density = 0.006
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

	cam = Camera3D.new()
	cam.fov = 45.0
	cam.position = Vector3(0, CAM_HEIGHT, CAM_BACK)
	add_child(cam)
	cam.look_at(Vector3.ZERO)


func _build_arena() -> void:
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = D.arena
	disc.bottom_radius = D.arena
	disc.height = 0.2
	disc.radial_segments = 96
	floor_mesh.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.09, 0.11, 0.15)
	fm.roughness = 0.95
	floor_mesh.material_override = fm
	floor_mesh.position.y = -0.1
	add_child(floor_mesh)

	# 同心环 + 外圈
	for r in [5.0, 10.0, 15.0]:
		var ring := AoeFactory.ring(Vector3.ZERO, r - 0.06, r, Color(0.35, 0.42, 0.55, 0.5), 96)
		add_child(ring)
	var rim := AoeFactory.ring(Vector3.ZERO, D.arena - 0.3, D.arena, Color(0.45, 0.55, 0.7, 0.75), 96)
	add_child(rim)


func _build_marks() -> void:
	for m in D.marks:
		var label: String = String(m.get("label", "?"))
		var r: float = float(m.get("r", 0.0))
		var deg: float = float(m.get("deg", 0.0))
		var p := YiyunData.pol(r, deg)

		var lb := Label3D.new()
		lb.text = label
		lb.font_size = 64
		lb.pixel_size = 0.008
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = p + Vector3(0, 0.6, 0)
		lb.modulate = Color(0.62, 0.7, 0.82)
		if ui_font != null:
			lb.font = ui_font
		add_child(lb)

		var dot := AoeFactory.circle(p, 0.9, Color(0.55, 0.62, 0.75, 0.25))
		add_child(dot)


func _process(_delta: float) -> void:
	# 相机跟随玩家（FF14 副本视角：高俯角、绕角色）
	if player == null or cam == null:
		return
	var target := player.position
	var want := Vector3(target.x, CAM_HEIGHT, target.z + CAM_BACK)
	cam.position = cam.position.lerp(want, 0.12)
	cam.look_at(Vector3(target.x, 1.5, target.z))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_start_run(false)
			KEY_R:
				_start_run(true)


func _start_run(keep_layout: bool) -> void:
	if seq == null:
		return
	seq.speed = 1.0
	seq.start(rng, keep_layout)
	hud.set_state("一运开始")


func _on_clear() -> void:
	total_runs += 1
	total_clear += 1
	streak += 1
	last_cause = ""
	hud.set_state("一运通过　连胜 %d" % streak)
	_update_stats_label()


func _on_dead(why: String) -> void:
	total_runs += 1
	streak = 0
	last_cause = why
	hud.set_state("死于：「%s」　T+%.2fs" % [why, seq.t])
	_update_stats_label()


func _on_player_died(_cause: String) -> void:
	pass


func _update_stats_label() -> void:
	hud.set_stats(total_clear, total_runs, streak, last_cause)
