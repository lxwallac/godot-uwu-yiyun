## 一运机制数据（纯逻辑，不碰渲染）
## 对应 fru_sim 的 sequences + position_coords 分层：
##   Sequence 只管“什么时候发生什么”，站位/安全区由 Pos 与 Aoe 决定
class_name YiyunData
extends RefCounted

const PATH := "res://data/yiyun.json"

var raw: Dictionary = {}
var timeline: Dictionary = {}
var geo: Dictionary = {}
var hit: Dictionary = {}
var move: Dictionary = {}
var marks: Array = []
var bosses: Dictionary = {}
var arena: float = 20.0
var wall_x: float = 19.3


func load_data() -> bool:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("读不到 " + PATH)
		return false
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("yiyun.json 解析失败")
		return false
	raw = parsed
	timeline = parsed.get("timeline", {})
	geo = parsed.get("geo", {})
	hit = parsed.get("hit", {})
	move = parsed.get("move", {})
	marks = parsed.get("marks", [])
	bosses = parsed.get("bosses", {})
	arena = float(parsed.get("arena", 20.0))
	wall_x = float(parsed.get("wall_x", 19.3))
	return true


## 极坐标 → 世界坐标（Godot：X 向东、Z 向南，北 = -Z）
static func pol(r: float, deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(r * sin(a), 0.0, -r * cos(a))


## 角度差（0~180）
static func ang_dist(a: float, b: float) -> float:
	var d := absf(fmod(a - b, 360.0))
	return 360.0 - d if d > 180.0 else d


## 离朝向最远的两个正点
static func near_cards(face_deg: float) -> Array:
	var cards := [
		{"k": "A", "deg": 0.0},
		{"k": "B", "deg": 90.0},
		{"k": "C", "deg": 180.0},
		{"k": "D", "deg": 270.0},
	]
	cards.sort_custom(func(x, y): return ang_dist(face_deg, x.deg) > ang_dist(face_deg, y.deg))
	return [cards[0].k, cards[1].k]


## 安全正点 = 该侧两点 − 泰坦压的那个
static func safe_cards(face_deg: float, titan_card: String) -> Array:
	var out := []
	for k in near_cards(face_deg):
		if k != titan_card:
			out.append(k)
	return out


## 生成一局布局
static func gen_layout(rng: RandomNumberGenerator) -> Dictionary:
	var g: float = [45.0, 135.0, 225.0, 315.0][rng.randi_range(0, 3)]
	var card_deg: float = [0.0, 90.0, 180.0, 270.0][rng.randi_range(0, 3)]
	var side: int = 1 if rng.randf() < 0.5 else -1
	var inter := [45.0, 135.0, 225.0, 315.0]
	var a: int = rng.randi_range(0, 3)
	var b: int = (a + 1 + rng.randi_range(0, 2)) % 4
	var titan_deg: float = fposmod(card_deg + side * 10.0, 360.0)
	return {
		"garuda_deg": g,
		"garuda_face_deg": fposmod(g + 180.0, 360.0),
		"titan_card_deg": card_deg,
		"titan_card": ["A", "B", "C", "D"][int(card_deg / 90.0)],
		"titan_deg": titan_deg,
		"ultima_deg": inter[a],
		"ifrit_deg": inter[b],
		# 五路地裂扇形基准角：泰坦朝向的反方向（空档落在这一侧）
		"fan1": fposmod(titan_deg + 180.0, 360.0),
		"fan2": fposmod(titan_deg + 270.0, 360.0),
	}
