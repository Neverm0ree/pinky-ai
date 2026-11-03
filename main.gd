extends Control

@onready var chat_history: RichTextLabel = $VBoxContainer/ChatHistory
@onready var message_input: LineEdit = $VBoxContainer/HBoxContainer/MessageInput
@onready var send_button: Button = $VBoxContainer/HBoxContainer/SendButton

var avatar_scene: Node3D = null
var avatar: Node3D = null
var world_env: WorldEnvironment = null
var scene_camera: Camera3D = null

var ai_chat: NobodyWhoChat

# --- Настройки Модели ИИ (LLM) ---
#var model_path: String = "res://models/qwen2.5-7b-instruct-q3_k_m.gguf"
var model_path: String = "Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-IQ3_M.gguf"
var llm_gpu_layers: int = 22
var llm_context_size: int = 1024
var available_models: Array[String] = []
var avatar_model_path: String = "default"
var available_avatars: Array[String] = ["default"]
var avatar_dropdown: OptionButton = null
var avatar_file_dialog: FileDialog = null

# --- Настройки Характера, Голоса, Окон, Фона и Нод ---
const SETTINGS_FILE: String = "user://settings.json"
const MEMORY_FILE: String = "user://chat_memory.json"
const WORKFLOW_FILE: String = "user://workflows.json"

var custom_persona: String = "Ты — живая, эмоциональная и остроумная девушка-компаньон по имени Ария. Отвечай на русском языке, коротко (1-2 предложения) и естественно, без списков и звёздочек."
var voice_pitch: float = 1.12
var voice_speed: float = 0.92
var tts_enabled: bool = true
var tts_engine: int = 0 # 0 = Piper TTS, 1 = Kyutai Pocket-TTS
var mouse_track_enabled: bool = true
var camera_zoom: float = 1.35
var ui_hidden: bool = false

var avatar_offset_x: float = 0.0
var avatar_offset_y: float = 0.0
var avatar_rot_y: float = 0.0
var base_avatar_pos: Vector3 = Vector3.ZERO
var is_dragging_avatar: bool = false

# Голосовой ввод
var is_recording: bool = false
var auto_voice_call: bool = false
var is_busy_generating: bool = false

# Фоны: 0=Прозрачный, 1=Тёмный Grok, 2=Киберпанк, 3=Уютный закат, 4=3D Небо, 5=Хромакей, 6=Свой цвет, 7=Матовое стекло (Блюр)
var bg_mode: int = 7
var blur_strength: float = 0.55
var custom_bg_color: Color = Color(0.10, 0.12, 0.18, 1.0)
var avatar_window_open: bool = false
var avatar_always_on_top: bool = true
var avatar_borderless: bool = true

var saved_messages: Array = []

var avatar_window: Window = null
var top_bar: HBoxContainer = null
var popout_btn: Button = null
var hide_ui_btn: Button = null
var mic_btn: Button = null
var call_btn: Button = null
var move_hud: PanelContainer = null
var settings_panel: PanelContainer

# Элементы шейдера блюра (Glassmorphism)
var glass_shader_mat: ShaderMaterial = null
var glass_rects: Array[ColorRect] = []
var blur_slider: HSlider = null
var blur_val_lbl: Label = null

# --- Визуальный редактор сценариев (GraphEdit) ---
var workflow_panel: PanelContainer = null
var graph_edit: GraphEdit = null
var workflow_log: RichTextLabel = null
var node_counter: int = 1
var is_running_workflow: bool = false

var persona_edit: TextEdit
var model_dropdown: OptionButton
var tts_engine_dropdown: OptionButton
var bg_dropdown: OptionButton
var bg_color_picker: ColorPickerButton
var gpu_slider: HSlider
var gpu_val_lbl: Label
var ctx_slider: HSlider
var ctx_val_lbl: Label
var pitch_slider: HSlider
var pitch_val_lbl: Label
var speed_slider: HSlider
var speed_val_lbl: Label
var zoom_slider: HSlider
var zoom_val_lbl: Label
var pos_label: Label
var tts_check: CheckButton
var track_check: CheckButton
var on_top_check: CheckButton
var borderless_check: CheckButton

var audio_player: AudioStreamPlayer
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var skeleton: Skeleton3D = null
var left_arm_idx: int = -1
var right_arm_idx: int = -1
var head_idx: int = -1
var left_eye_idx: int = -1
var right_eye_idx: int = -1
var smooth_mouse: Vector2 = Vector2.ZERO

var face_mesh: MeshInstance3D = null
var blink_shape_idx: int = -1
var vowels: Dictionary = {}
var emotions: Dictionary = {}
var current_emotion: String = "neutral"

var time_passed: float = 0.0
var blink_timer: float = 0.0
var is_speaking: bool = false
var current_vowel: String = "A"

# --- ВЕКТОРНЫЕ SVG-ИКОНКИ ---
const SVG_PATHS: Dictionary = {
	"eye": "<path d='M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z'/><circle cx='12' cy='12' r='3'/>",
	"eye_off": "<path d='M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24'/><line x1='1' y1='1' x2='23' y2='23'/>",
	"move": "<polyline points='5 9 2 12 5 15'/><polyline points='9 5 12 2 15 5'/><polyline points='15 19 12 22 9 19'/><polyline points='19 9 22 12 19 15'/><line x1='2' y1='12' x2='22' y2='12'/><line x1='12' y1='2' x2='12' y2='22'/>",
	"window": "<rect x='3' y='3' width='18' height='18' rx='2'/><line x1='3' y1='9' x2='21' y2='9'/><line x1='9' y1='21' x2='9' y2='9'/>",
	"mute": "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/><line x1='23' y1='9' x2='17' y2='15'/><line x1='17' y1='9' x2='23' y2='15'/>",
	"volume": "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/><path d='M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07'/>",
	"trash": "<polyline points='3 6 5 6 21 6'/><path d='M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'/>",
	"settings": "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'/>",
	"mic": "<path d='M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z'/><path d='M19 10v2a7 7 0 0 1-14 0v-2'/><line x1='12' y1='19' x2='12' y2='23'/><line x1='8' y1='23' x2='16' y2='23'/>",
	"phone": "<path d='M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z'/>",
	"send": "<line x1='22' y1='2' x2='11' y2='13'/><polygon points='22 2 15 22 11 13 2 9 22 2'/>",
	"left": "<line x1='19' y1='12' x2='5' y2='12'/><polyline points='12 19 5 12 12 5'/>",
	"right": "<line x1='5' y1='12' x2='19' y2='12'/><polyline points='12 5 19 12 12 19'/>",
	"up": "<line x1='12' y1='19' x2='12' y2='5'/><polyline points='5 12 12 5 19 12'/>",
	"down": "<line x1='12' y1='5' x2='12' y2='19'/><polyline points='19 12 12 19 5 12'/>",
	"rot_l": "<polyline points='1 4 1 10 7 10'/><path d='M3.51 15a9 9 0 1 0 2.13-9.36L1 10'/>",
	"rot_r": "<polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/>",
	"reset": "<circle cx='12' cy='12' r='9'/><circle cx='12' cy='12' r='3'/><line x1='12' y1='1' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='23'/><line x1='1' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='23' y2='12'/>",
	"close": "<line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/>",
	"user": "<path d='M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>",
	"cpu": "<rect x='4' y='4' width='16' height='16' rx='2'/><rect x='9' y='9' width='6' height='6'/><line x1='9' y1='1' x2='9' y2='4'/><line x1='15' y1='1' x2='15' y2='4'/><line x1='9' y1='20' x2='9' y2='23'/><line x1='15' y1='20' x2='15' y2='23'/><line x1='20' y1='9' x2='23' y2='9'/><line x1='20' y1='14' x2='23' y2='14'/><line x1='1' y1='9' x2='4' y2='9'/><line x1='1' y1='14' x2='4' y2='14'/>",
	"nodes": "<rect x='2' y='2' width='6' height='6' rx='1'/><rect x='16' y='2' width='6' height='6' rx='1'/><rect x='9' y='16' width='6' height='6' rx='1'/><path d='M5 8v3a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8'/><line x1='12' y1='13' x2='12' y2='16'/>",
	"play": "<polygon points='5 3 19 12 5 21 5 3'/>",
	"terminal": "<polyline points='4 17 10 11 4 5'/><line x1='12' y1='19' x2='20' y2='19'/>",
	"branch": "<line x1='6' y1='3' x2='6' y2='15'/><circle cx='18' cy='6' r='3'/><circle cx='6' cy='18' r='3'/><path d='M18 9a9 9 0 0 1-9 9'/>",
	"clock": "<circle cx='12' cy='12' r='10'/><polyline points='12 6 12 12 16 14'/>"
}

func _make_svg_icon(icon_name: String, color_hex: String = "#e6eef8", size_px: int = 18) -> Texture2D:
	if not SVG_PATHS.has(icon_name):
		return null
	var svg_xml: String = (
		"<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 24 24' fill='none' stroke='%s' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>"
		% [size_px, size_px, color_hex, SVG_PATHS[icon_name]]
	)
	var img := Image.new()
	if img.load_svg_from_string(svg_xml) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _style_icon_button(btn: Button, icon_name: String, color_hex: String = "#e6eef8") -> void:
	if icon_name != "":
		btn.icon = _make_svg_icon(icon_name, color_hex, 18)
	btn.add_theme_constant_override("h_separation", 7)
	
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.12, 0.14, 0.20, 0.85)
	normal_box.border_color = Color(0.32, 0.38, 0.52, 0.45)
	normal_box.set_border_width_all(1)
	normal_box.set_corner_radius_all(8)
	normal_box.content_margin_left = 10
	normal_box.content_margin_right = 10
	normal_box.content_margin_top = 6
	normal_box.content_margin_bottom = 6
	
	var hover_box: StyleBoxFlat = normal_box.duplicate()
	hover_box.bg_color = Color(0.19, 0.23, 0.33, 0.95)
	hover_box.border_color = Color(0.52, 0.68, 0.98, 0.85)
	
	var pressed_box: StyleBoxFlat = normal_box.duplicate()
	pressed_box.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", pressed_box)

# --- ШЕЙДЕР МАТОВОГО СТЕКЛА И СИСТЕМНЫЙ БЛЮР LINUX ---
func _init_glass_blur_shader() -> void:
	if glass_shader_mat != null:
		return
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur_radius : hint_range(0.0, 6.0) = 2.8;
uniform vec4 glass_tint : source_color = vec4(0.08, 0.11, 0.18, 0.42);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb * 0.20;
	col += texture(screen_tex, SCREEN_UV + vec2(ps.x, 0.0)).rgb * 0.12;
	col += texture(screen_tex, SCREEN_UV - vec2(ps.x, 0.0)).rgb * 0.12;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0, ps.y)).rgb * 0.12;
	col += texture(screen_tex, SCREEN_UV - vec2(0.0, ps.y)).rgb * 0.12;
	col += texture(screen_tex, SCREEN_UV + vec2(ps.x, ps.y)).rgb * 0.08;
	col += texture(screen_tex, SCREEN_UV + vec2(-ps.x, ps.y)).rgb * 0.08;
	col += texture(screen_tex, SCREEN_UV + vec2(ps.x, -ps.y)).rgb * 0.08;
	col += texture(screen_tex, SCREEN_UV + vec2(-ps.x, -ps.y)).rgb * 0.08;

	// Лёгкий диагональный стеклянный блик
	float sheen = clamp(1.0 - (UV.x * 0.6 + UV.y * 0.8), 0.0, 1.0) * 0.07;
	vec3 final_rgb = mix(col, glass_tint.rgb + vec3(sheen), glass_tint.a);
	COLOR = vec4(final_rgb, 0.92);
}
"""
	glass_shader_mat = ShaderMaterial.new()
	glass_shader_mat.shader = sh
	_update_glass_shader_params()

func _attach_glass_blur_backdrop(target: Control) -> void:
	_init_glass_blur_shader()
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	rect.material = glass_shader_mat
	rect.visible = (bg_mode == 7)
	target.add_child(rect)
	glass_rects.append(rect)

func _update_glass_shader_params() -> void:
	if glass_shader_mat != null:
		glass_shader_mat.set_shader_parameter("blur_radius", blur_strength * 4.5)
		glass_shader_mat.set_shader_parameter("glass_tint", Color(0.08, 0.11, 0.18, clamp(blur_strength * 0.65, 0.15, 0.78)))
	for r in glass_rects:
		if is_instance_valid(r):
			r.visible = (bg_mode == 7)

# Включает или выключает аппаратное размытие фона окна на уровне композитора Linux (KDE KWin / Hyprland)
func _set_linux_compositor_blur(enable: bool) -> void:
	var pid: int = OS.get_process_id()
	var cmd: String = ""
	if enable:
		cmd = (
			"if command -v hyprctl >/dev/null 2>&1; then " +
			"hyprctl keyword windowrulev2 'blur,class:^(.*)$' >/dev/null 2>&1; " +
			"hyprctl keyword windowrulev2 'ignorealpha 0.02,class:^(.*)$' >/dev/null 2>&1; " +
			"fi; " +
			"if command -v xdotool >/dev/null 2>&1 && command -v xprop >/dev/null 2>&1; then " +
			"for wid in $(xdotool search --pid " + str(pid) + " 2>/dev/null); do " +
			"xprop -id $wid -f _KDE_NET_WM_BLUR_BEHIND_REGION 32c -set _KDE_NET_WM_BLUR_BEHIND_REGION 0 >/dev/null 2>&1; " +
			"done; fi"
		)
	else:
		cmd = (
			"if command -v xdotool >/dev/null 2>&1 && command -v xprop >/dev/null 2>&1; then " +
			"for wid in $(xdotool search --pid " + str(pid) + " 2>/dev/null); do " +
			"xprop -id $wid -remove _KDE_NET_WM_BLUR_BEHIND_REGION >/dev/null 2>&1; " +
			"done; fi"
		)
	OS.create_process("sh", ["-c", cmd])

func _create_section_card(parent: Control, title_text: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.11, 0.13, 0.19, 0.72)
	card_style.border_color = Color(0.25, 0.30, 0.42, 0.40)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)
	
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	
	if title_text != "":
		var lbl := Label.new()
		lbl.text = title_text
		lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
		lbl.add_theme_font_size_override("font_size", 14)
		box.add_child(lbl)
	return box

func _resolve_ext_path(res_path: String) -> String:
	var rel: String = res_path.replace("res://", "")
	var exe_adj: String = OS.get_executable_path().get_base_dir().path_join(rel)
	if FileAccess.file_exists(exe_adj) or DirAccess.dir_exists_absolute(exe_adj):
		return exe_adj
	return ProjectSettings.globalize_path(res_path)

func _ensure_pocket_tts_running() -> void:
	var py_bin: String = _resolve_ext_path("res://tts/venv_pocket/bin/python")
	var script_path: String = _resolve_ext_path("res://tts/pocket_server.py")
	if not FileAccess.file_exists(py_bin) or not FileAccess.file_exists(script_path):
		return
	var cmd: String = (
		"if ! ss -tln | grep -q ':8021 '; then " +
		"nohup '" + py_bin + "' '" + script_path + "' >/tmp/pocket_tts.log 2>&1 & " +
		"fi"
	)
	OS.execute("sh", ["-c", cmd], [], false)

func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false
	
	avatar_scene = get_node_or_null("AvatarScene")
	_find_camera_and_env(self)
	_scan_models_folder()
	_scan_avatars_folder()
	_load_settings_and_memory()
	_setup_grok_theme()
	_setup_audio_and_lipsync()
	_create_settings_ui()
	_create_workflow_ui()
	
	_ensure_pocket_tts_running()
	
	chat_history.bbcode_enabled = true
	send_button.disabled = true
	message_input.editable = false
	
	if avatar_scene != null:
		for child in avatar_scene.get_children():
			if child is Node3D and not (child is Camera3D) and not (child is DirectionalLight3D) and not (child is WorldEnvironment):
				avatar = child
				break
				
	if avatar != null:
		base_avatar_pos = avatar.position
		_inspect_and_setup_avatar(avatar)
		_apply_avatar_transform()
	if avatar_model_path != "default" and avatar_model_path != "":
		_load_custom_avatar_model(avatar_model_path)
		
	if scene_camera != null:
		scene_camera.position.z = camera_zoom
		
	_apply_background_mode()
	if avatar_window_open:
		_toggle_avatar_window(true)
	
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_text_submitted)
	
	if saved_messages.size() > 0:
		chat_history.append_text("[color=gray][i]--- История прошлых бесед загружена ---[/i][/color]\n")
		for msg in saved_messages:
			if msg["role"] == "user":
				chat_history.append_text("[color=skyblue][b]Ты:[/b][/color] " + msg["text"] + "\n")
			else:
				chat_history.append_text("[color=lightgreen][b]Аватар:[/b][/color] " + msg["text"] + "\n\n")
	
	await _init_ai_model(false)

func _find_camera_and_env(node: Node) -> void:
	if node is Camera3D and scene_camera == null:
		scene_camera = node
		camera_zoom = scene_camera.position.z
	elif node is WorldEnvironment and world_env == null:
		world_env = node
	for child in node.get_children():
		_find_camera_and_env(child)

# ==============================================================================
# ВИЗУАЛЬНОЕ ПРОГРАММИРОВАНИЕ НОД (GraphEdit + GraphNode)
# ==============================================================================
func _create_workflow_ui() -> void:
	workflow_panel = PanelContainer.new()
	workflow_panel.visible = false
	workflow_panel.custom_minimum_size = Vector2(820, 560)
	workflow_panel.position = Vector2(24, 58)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.11, 0.86)
	style.border_color = Color(0.32, 0.45, 0.68, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	workflow_panel.add_theme_stylebox_override("panel", style)
	add_child(workflow_panel)
	_attach_glass_blur_backdrop(workflow_panel)
	
	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 8)
	workflow_panel.add_child(root_vbox)
	
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	root_vbox.add_child(toolbar)
	
	var title_lbl := Label.new()
	title_lbl.text = "Сценарии терминала:"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	toolbar.add_child(title_lbl)
	
	var btn_add_start := Button.new()
	btn_add_start.text = "+ Старт"
	_style_icon_button(btn_add_start, "play", "#7bf1a8")
	btn_add_start.pressed.connect(func(): _spawn_workflow_node("start", Vector2(40, 80)))
	toolbar.add_child(btn_add_start)
	
	var btn_add_cmd := Button.new()
	btn_add_cmd.text = "+ Команда ZSH"
	_style_icon_button(btn_add_cmd, "terminal", "#9ec5ff")
	btn_add_cmd.pressed.connect(func(): _spawn_workflow_node("cmd", Vector2(280, 80)))
	toolbar.add_child(btn_add_cmd)
	
	var btn_add_cond := Button.new()
	btn_add_cond.text = "+ Условие"
	_style_icon_button(btn_add_cond, "branch", "#ffe299")
	btn_add_cond.pressed.connect(func(): _spawn_workflow_node("cond", Vector2(540, 80)))
	toolbar.add_child(btn_add_cond)
	
	var btn_add_delay := Button.new()
	btn_add_delay.text = "+ Пауза"
	_style_icon_button(btn_add_delay, "clock", "#d4b5ff")
	btn_add_delay.pressed.connect(func(): _spawn_workflow_node("delay", Vector2(420, 240)))
	toolbar.add_child(btn_add_delay)
	
	var btn_add_aria := Button.new()
	btn_add_aria.text = "+ Ария"
	_style_icon_button(btn_add_aria, "user", "#ffb4a2")
	btn_add_aria.pressed.connect(func(): _spawn_workflow_node("aria", Vector2(560, 120)))
	toolbar.add_child(btn_add_aria)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	var btn_run := Button.new()
	btn_run.text = "Запустить"
	_style_icon_button(btn_run, "play", "#7bf1a8")
	btn_run.pressed.connect(func(): _execute_workflow(""))
	toolbar.add_child(btn_run)
	
	var btn_clear := Button.new()
	btn_clear.text = "Сброс"
	_style_icon_button(btn_clear, "trash", "#ff9e9e")
	btn_clear.pressed.connect(_clear_workflow_graph)
	toolbar.add_child(btn_clear)
	
	var btn_close := Button.new()
	btn_close.text = ""
	_style_icon_button(btn_close, "close", "#ff9e9e")
	btn_close.pressed.connect(func():
		_save_workflows()
		workflow_panel.visible = false
	)
	toolbar.add_child(btn_close)
	
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.custom_minimum_size = Vector2(790, 360)
	graph_edit.right_disconnects = true
	graph_edit.connection_request.connect(_on_graph_connection_request)
	graph_edit.disconnection_request.connect(_on_graph_disconnection_request)
	root_vbox.add_child(graph_edit)
	
	var log_header := HBoxContainer.new()
	root_vbox.add_child(log_header)
	var log_lbl := Label.new()
	log_lbl.text = "Консоль выполнения сценария (переменная $PREV_OUT передаёт вывод между блоками):"
	log_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_lbl.add_theme_font_size_override("font_size", 12)
	log_lbl.add_theme_color_override("font_color", Color(0.60, 0.72, 0.88))
	log_header.add_child(log_lbl)
	
	workflow_log = RichTextLabel.new()
	workflow_log.bbcode_enabled = true
	workflow_log.scroll_following = true
	workflow_log.custom_minimum_size = Vector2(0, 110)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.03, 0.04, 0.06, 0.92)
	log_style.set_corner_radius_all(8)
	log_style.set_content_margin_all(8)
	workflow_log.add_theme_stylebox_override("normal", log_style)
	root_vbox.add_child(workflow_log)
	
	_load_or_create_default_workflow()

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node:
		return
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_save_workflows()

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_save_workflows()

func _spawn_workflow_node(n_type: String, pos: Vector2, saved_data: Dictionary = {}) -> GraphNode:
	var gnode := GraphNode.new()
	var n_id: String = str(saved_data.get("name", n_type + "_" + str(node_counter)))
	node_counter += 1
	gnode.name = n_id
	gnode.position_offset = pos
	gnode.set_meta("node_type", n_type)
	gnode.custom_minimum_size = Vector2(220, 0)
	
	var top_row := HBoxContainer.new()
	var type_lbl := Label.new()
	type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(type_lbl)
	
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.flat = true
	del_btn.tooltip_text = "Удалить этот блок"
	del_btn.pressed.connect(func():
		_remove_graph_node(gnode)
	)
	top_row.add_child(del_btn)
	gnode.add_child(top_row)
	
	match n_type:
		"start":
			gnode.title = "🟢 Старт сценария"
			type_lbl.text = "Голосовой/текстовый триггер:"
			var trig_edit := LineEdit.new()
			trig_edit.name = "Param1"
			trig_edit.placeholder_text = "напр.: проверь систему"
			trig_edit.text = str(saved_data.get("param1", "проверь систему"))
			trig_edit.text_changed.connect(func(_t): _save_workflows())
			gnode.add_child(trig_edit)
			gnode.set_slot(0, false, 0, Color.WHITE, true, 0, Color(0.45, 0.95, 0.65))
			
		"cmd":
			gnode.title = "⚡ Команда ZSH"
			type_lbl.text = "Команда (доступен $PREV_OUT):"
			var cmd_edit := LineEdit.new()
			cmd_edit.name = "Param1"
			cmd_edit.placeholder_text = "uname -sr && uptime -p"
			cmd_edit.text = str(saved_data.get("param1", "uname -sr && free -h | awk '/Mem:/ {print $3 \" / \" $2}'"))
			cmd_edit.custom_minimum_size = Vector2(210, 0)
			cmd_edit.text_changed.connect(func(_t): _save_workflows())
			gnode.add_child(cmd_edit)
			gnode.set_slot(0, true, 0, Color(0.45, 0.95, 0.65), true, 0, Color(0.55, 0.78, 1.0))
			
		"cond":
			gnode.title = "🔍 Условие (If / Else)"
			type_lbl.text = "Ветка ДА (если содержит):"
			var cond_edit := LineEdit.new()
			cond_edit.name = "Param1"
			cond_edit.placeholder_text = "Текст или EXIT_0"
			cond_edit.text = str(saved_data.get("param1", "Linux"))
			cond_edit.text_changed.connect(func(_t): _save_workflows())
			gnode.add_child(cond_edit)
			
			var false_lbl := Label.new()
			false_lbl.text = "Ветка ИНАЧЕ (если нет) ➡"
			false_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			false_lbl.add_theme_color_override("font_color", Color(1.0, 0.60, 0.60))
			gnode.add_child(false_lbl)
			
			gnode.set_slot(0, true, 0, Color(0.55, 0.78, 1.0), true, 0, Color(0.45, 0.95, 0.65))
			gnode.set_slot(2, false, 0, Color.WHITE, true, 0, Color(1.0, 0.45, 0.45))
			
		"delay":
			gnode.title = "⏱ Пауза"
			type_lbl.text = "Ждать секунд:"
			var spin := SpinBox.new()
			spin.name = "Param1"
			spin.min_value = 0.2
			spin.max_value = 300.0
			spin.step = 0.5
			spin.value = float(saved_data.get("param1", 2.0))
			spin.value_changed.connect(func(_v): _save_workflows())
			gnode.add_child(spin)
			gnode.set_slot(0, true, 0, Color(0.55, 0.78, 1.0), true, 0, Color(0.82, 0.70, 1.0))
			
		"aria":
			gnode.title = "🤖 Действие Арии"
			type_lbl.text = "Режим реакции на $PREV_OUT:"
			var mode_drop := OptionButton.new()
			mode_drop.name = "Mode"
			mode_drop.add_item("Проанализировать через ИИ", 0)
			mode_drop.add_item("Озвучить текст напрямую", 1)
			mode_drop.selected = int(saved_data.get("mode", 0))
			mode_drop.item_selected.connect(func(_i): _save_workflows())
			gnode.add_child(mode_drop)
			
			var prompt_edit := LineEdit.new()
			prompt_edit.name = "Param1"
			prompt_edit.placeholder_text = "Шаблон с $PREV_OUT"
			prompt_edit.text = str(saved_data.get("param1", "Прокомментируй вывод терминала коротко: $PREV_OUT"))
			prompt_edit.text_changed.connect(func(_t): _save_workflows())
			gnode.add_child(prompt_edit)
			gnode.set_slot(0, true, 0, Color(0.55, 0.78, 1.0), true, 0, Color(1.0, 0.70, 0.65))
			
	gnode.position_offset_changed.connect(func(): _save_workflows())
	graph_edit.add_child(gnode)
	_save_workflows()
	return gnode

func _remove_graph_node(gnode: GraphNode) -> void:
	var target_name: StringName = gnode.name
	for conn in graph_edit.get_connection_list():
		var f_node: StringName = conn.get("from_node", conn.get("from", ""))
		var t_node: StringName = conn.get("to_node", conn.get("to", ""))
		if f_node == target_name or t_node == target_name:
			graph_edit.disconnect_node(f_node, int(conn["from_port"]), t_node, int(conn["to_port"]))
	gnode.queue_free()
	await get_tree().process_frame
	_save_workflows()

func _clear_workflow_graph() -> void:
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	workflow_log.clear()
	await get_tree().process_frame
	_save_workflows()

func _run_shell_async(cmd_str: String, prev_out: String) -> Dictionary:
	var pid_id: String = str(Time.get_ticks_usec())
	var out_file: String = "/tmp/aria_wf_out_" + pid_id + ".txt"
	var code_file: String = "/tmp/aria_wf_code_" + pid_id + ".txt"
	var env_file: String = "/tmp/aria_wf_env_" + pid_id + ".txt"
	
	var f_env := FileAccess.open(env_file, FileAccess.WRITE)
	if f_env:
		f_env.store_string(prev_out)
		f_env.close()
		
	var wrapped_cmd: String = (
		"export PREV_OUT=\"$(cat '" + env_file + "' 2>/dev/null)\"; " +
		"(" + cmd_str + ") >'" + out_file + "' 2>&1; " +
		"echo $? >'" + code_file + "'"
	)
	OS.create_process("zsh", ["-c", wrapped_cmd])
	
	while not FileAccess.file_exists(code_file):
		await get_tree().create_timer(0.1).timeout
		
	var out_text: String = ""
	if FileAccess.file_exists(out_file):
		out_text = FileAccess.get_file_as_string(out_file).strip_edges()
		DirAccess.remove_absolute(out_file)
		
	var exit_code: int = 0
	if FileAccess.file_exists(code_file):
		exit_code = int(FileAccess.get_file_as_string(code_file).strip_edges())
		DirAccess.remove_absolute(code_file)
		
	if FileAccess.file_exists(env_file):
		DirAccess.remove_absolute(env_file)
		
	return {"output": out_text, "exit_code": exit_code}

func _execute_workflow(trigger_phrase: String = "") -> bool:
	if is_running_workflow or graph_edit == null:
		return false
		
	var start_node: GraphNode = null
	var clean_trig: String = trigger_phrase.to_lower().strip_edges()
	
	for child in graph_edit.get_children():
		if child is GraphNode and child.get_meta("node_type", "") == "start":
			var p1: LineEdit = child.get_node_or_null("Param1")
			var node_trig: String = p1.text.to_lower().strip_edges() if p1 != null else ""
			if clean_trig == "":
				start_node = child
				break
			elif node_trig != "" and node_trig in clean_trig:
				start_node = child
				break
				
	if start_node == null:
		if clean_trig == "" and workflow_log != null:
			workflow_log.append_text("[color=salmon]Добавь хотя бы один блок «🟢 Старт» на схему![/color]\n")
		return false
		
	is_running_workflow = true
	if workflow_log != null:
		workflow_log.append_text("[color=lightgreen][b]▶ Запуск сценария...[/b][/color]\n")
		
	var current_node: GraphNode = start_node
	var prev_output: String = ""
	var prev_exit_code: int = 0
	var steps: int = 0
	
	while current_node != null and steps < 40:
		steps += 1
		var n_type: String = current_node.get_meta("node_type", "")
		var next_port: int = 0
		current_node.modulate = Color(1.25, 1.35, 1.0)
		
		match n_type:
			"start":
				workflow_log.append_text("[color=gray]• Старт: " + current_node.name + "[/color]\n")
				await get_tree().create_timer(0.15).timeout
				
			"cmd":
				var cmd_edit: LineEdit = current_node.get_node_or_null("Param1")
				var raw_cmd: String = cmd_edit.text.strip_edges() if cmd_edit != null else ""
				workflow_log.append_text("[color=skyblue]$ " + raw_cmd + "[/color]\n")
				var res: Dictionary = await _run_shell_async(raw_cmd, prev_output)
				prev_output = res["output"]
				prev_exit_code = res["exit_code"]
				if prev_output != "":
					workflow_log.append_text(prev_output + "\n")
				workflow_log.append_text("[color=gray](Код возврата: " + str(prev_exit_code) + ")[/color]\n")
				
			"cond":
				var cond_edit: LineEdit = current_node.get_node_or_null("Param1")
				var pattern: String = cond_edit.text.strip_edges() if cond_edit != null else ""
				var matched: bool = false
				if pattern == "EXIT_0":
					matched = (prev_exit_code == 0)
				else:
					matched = (pattern.to_lower() in prev_output.to_lower())
				next_port = 0 if matched else 1
				workflow_log.append_text(
					"[color=yellow]? Условие («" + pattern + "»): " +
					("ДА (порт 0)" if matched else "ИНАЧЕ (порт 1)") + "[/color]\n"
				)
				await get_tree().create_timer(0.15).timeout
				
			"delay":
				var spin: SpinBox = current_node.get_node_or_null("Param1")
				var wait_sec: float = spin.value if spin != null else 1.0
				workflow_log.append_text("[color=plum]⏱ Пауза " + str(wait_sec) + " сек...[/color]\n")
				await get_tree().create_timer(wait_sec).timeout
				
			"aria":
				var mode_drop: OptionButton = current_node.get_node_or_null("Mode")
				var prompt_edit: LineEdit = current_node.get_node_or_null("Param1")
				var mode_idx: int = mode_drop.selected if mode_drop != null else 0
				var tpl: String = prompt_edit.text if prompt_edit != null else "$PREV_OUT"
				var final_text: String = tpl.replace("$PREV_OUT", prev_output).strip_edges()
				
				if mode_idx == 1:
					await _speak_and_print_direct(final_text)
				else:
					message_input.text = final_text
					await _on_send_pressed()
					
		current_node.modulate = Color(1.0, 1.0, 1.0)
		
		var next_node: GraphNode = null
		for conn in graph_edit.get_connection_list():
			var f_node: StringName = conn.get("from_node", conn.get("from", ""))
			var f_port: int = int(conn.get("from_port", 0))
			if f_node == current_node.name and f_port == next_port:
				var t_node: String = str(conn.get("to_node", conn.get("to", "")))
				next_node = graph_edit.get_node_or_null(t_node) as GraphNode
				break
		current_node = next_node
		
	workflow_log.append_text("[color=lightgreen][b]✔ Сценарий завершён.[/b][/color]\n\n")
	is_running_workflow = false
	return true

func _speak_and_print_direct(text_msg: String) -> void:
	if text_msg == "":
		return
	chat_history.append_text("[color=lightgreen][b]Аватар (Сценарий):[/b][/color] " + text_msg + "\n\n")
	var wav_res: String = _generate_tts_wav(text_msg)
	if wav_res != "":
		var wav_stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(wav_res))
		if wav_stream != null:
			audio_player.stream = wav_stream
			audio_player.play()
			while audio_player.playing:
				await get_tree().process_frame

func _save_workflows() -> void:
	if graph_edit == null:
		return
	var nodes_arr: Array = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			var n_type: String = child.get_meta("node_type", "")
			var p1_val = ""
			var p1_node = child.get_node_or_null("Param1")
			if p1_node is LineEdit:
				p1_val = p1_node.text
			elif p1_node is SpinBox:
				p1_val = p1_node.value
			var mode_val: int = 0
			var mode_node = child.get_node_or_null("Mode")
			if mode_node is OptionButton:
				mode_val = mode_node.selected
			nodes_arr.append({
				"name": String(child.name),
				"type": n_type,
				"x": child.position_offset.x,
				"y": child.position_offset.y,
				"param1": p1_val,
				"mode": mode_val
			})
	var conns_arr: Array = []
	for conn in graph_edit.get_connection_list():
		conns_arr.append({
			"from_node": str(conn.get("from_node", conn.get("from", ""))),
			"from_port": int(conn.get("from_port", 0)),
			"to_node": str(conn.get("to_node", conn.get("to", ""))),
			"to_port": int(conn.get("to_port", 0))
		})
	var f := FileAccess.open(WORKFLOW_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"nodes": nodes_arr, "connections": conns_arr, "counter": node_counter}, "\t"))
		f.close()

func _load_or_create_default_workflow() -> void:
	if FileAccess.file_exists(WORKFLOW_FILE):
		var f := FileAccess.open(WORKFLOW_FILE, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(data) == TYPE_DICTIONARY and data.get("nodes", []).size() > 0:
			node_counter = int(data.get("counter", 10))
			for n_info in data.get("nodes", []):
				_spawn_workflow_node(
					str(n_info.get("type", "cmd")),
					Vector2(float(n_info.get("x", 60)), float(n_info.get("y", 60))),
					n_info
				)
			for c_info in data.get("connections", []):
				graph_edit.connect_node(
					str(c_info["from_node"]),
					int(c_info["from_port"]),
					str(c_info["to_node"]),
					int(c_info["to_port"])
				)
			return
			
	var n1 := _spawn_workflow_node("start", Vector2(20, 70), {"name": "start_1", "param1": "проверь систему"})
	var n2 := _spawn_workflow_node("cmd", Vector2(260, 70), {"name": "cmd_2", "param1": "uname -sr && free -h | awk '/Mem:/ {print \"ОЗУ: \" $3 \" из \" $2}'"})
	var n3 := _spawn_workflow_node("aria", Vector2(540, 70), {"name": "aria_3", "mode": 0, "param1": "Скажи пользователю данные его системы: $PREV_OUT"})
	graph_edit.connect_node(n1.name, 0, n2.name, 0)
	graph_edit.connect_node(n2.name, 0, n3.name, 0)
	_save_workflows()

# --- ПЕРЕМЕЩЕНИЕ И ПОВОРОТ ПЕРСОНАЖА ---
func _move_avatar(dx: float, dy: float, drot: float = 0.0) -> void:
	avatar_offset_x = clamp(avatar_offset_x + dx, -1.8, 1.8)
	avatar_offset_y = clamp(avatar_offset_y + dy, -1.5, 1.5)
	avatar_rot_y = wrapf(avatar_rot_y + drot, -180.0, 180.0)
	_apply_avatar_transform()
	_save_settings()

func _reset_avatar_pos() -> void:
	avatar_offset_x = 0.0
	avatar_offset_y = 0.0
	avatar_rot_y = 0.0
	_apply_avatar_transform()
	_save_settings()

func _apply_avatar_transform() -> void:
	if avatar != null:
		avatar.position.x = base_avatar_pos.x + avatar_offset_x
		avatar.position.y = base_avatar_pos.y + avatar_offset_y
		avatar.rotation_degrees.y = avatar_rot_y
	if pos_label != null:
		pos_label.text = (
			"X: " + str(snapped(avatar_offset_x, 0.05)) +
			"  |  Y: " + str(snapped(avatar_offset_y, 0.05)) +
			"  |  Угол: " + str(int(avatar_rot_y)) + "° (или зажми ПКМ)"
		)

func _create_dpad_controls() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var btns: Array = [
		["", "left", func(): _move_avatar(-0.08, 0.0, 0.0), "Сдвинуть влево"],
		["", "up", func(): _move_avatar(0.0, 0.08, 0.0), "Сдвинуть вверх"],
		["", "down", func(): _move_avatar(0.0, -0.08, 0.0), "Сдвинуть вниз"],
		["", "right", func(): _move_avatar(0.08, 0.0, 0.0), "Сдвинуть вправо"],
		["", "rot_l", func(): _move_avatar(0.0, 0.0, -12.0), "Повернуть влево"],
		["", "rot_r", func(): _move_avatar(0.0, 0.0, 12.0), "Повернуть вправо"],
		["Сброс", "reset", func(): _reset_avatar_pos(), "Вернуть в центр"]
	]
	for b_info in btns:
		var btn := Button.new()
		btn.text = b_info[0]
		btn.tooltip_text = b_info[3]
		btn.custom_minimum_size = Vector2(38, 34)
		_style_icon_button(btn, b_info[1], "#9ec5ff")
		btn.pressed.connect(b_info[2])
		bar.add_child(btn)
	return bar

func _gui_input(event: InputEvent) -> void:
	_handle_avatar_mouse_drag(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if workflow_panel != null and workflow_panel.visible:
			_save_workflows()
			workflow_panel.visible = false
			return
		if settings_panel != null and settings_panel.visible:
			settings_panel.visible = false
			return
	_handle_avatar_mouse_drag(event)

func _handle_avatar_mouse_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_dragging_avatar = event.pressed
		if not event.pressed:
			_save_settings()
	elif event is InputEventMouseMotion and is_dragging_avatar:
		avatar_offset_x = clamp(avatar_offset_x + event.relative.x * 0.0025, -1.8, 1.8)
		avatar_offset_y = clamp(avatar_offset_y - event.relative.y * 0.0025, -1.5, 1.5)
		_apply_avatar_transform()

# --- ГОЛОСОВОЙ ЧАТ ---
func _toggle_voice_recording() -> void:
	if is_busy_generating:
		return
		
	if not is_recording:
		var http := HTTPRequest.new()
		add_child(http)
		var err := http.request("http://127.0.0.1:8022/start")
		if err != OK:
			http.queue_free()
			chat_history.append_text("[color=salmon][b]Ошибка:[/b] Не удалось подключиться к stt_server.py![/color]\n")
			return
		var res = await http.request_completed
		http.queue_free()
		if res[1] != 200:
			chat_history.append_text("[color=salmon][b]Ошибка STT:[/b] Перезапусти stt_server.py в терминале![/color]\n")
			return
			
		is_recording = true
		mic_btn.text = "Стоп"
		mic_btn.modulate = Color(1.0, 0.45, 0.45)
	else:
		is_recording = false
		mic_btn.text = "Жду..."
		mic_btn.modulate = Color(1.0, 1.0, 1.0)
		
		var http := HTTPRequest.new()
		add_child(http)
		var err := http.request("http://127.0.0.1:8022/stop")
		if err != OK:
			http.queue_free()
			mic_btn.text = "Голос"
			return
			
		var res = await http.request_completed
		http.queue_free()
		mic_btn.text = "Голос"
		
		var result_code: int = res[1]
		var body: PackedByteArray = res[3]
		if result_code == 200:
			var spoken_text: String = body.get_string_from_utf8().strip_edges()
			if spoken_text != "":
				message_input.text = spoken_text
				await _on_send_pressed()
			else:
				chat_history.append_text("[color=yellow][i]Голос не расслышан (проверь громкость микрофона в терминале stt_server.py).[/i][/color]\n")
		else:
			chat_history.append_text("[color=salmon][b]Ошибка STT:[/b] Проверь терминал с stt_server.py![/color]\n")

func _toggle_auto_call() -> void:
	auto_voice_call = not auto_voice_call
	if auto_voice_call:
		call_btn.text = "Завершить"
		call_btn.modulate = Color(0.45, 1.0, 0.55)
		chat_history.append_text("[color=lightgreen][i]Режим живого звонка включён — просто говори в микрофон![/i][/color]\n")
		_run_auto_call_loop()
	else:
		call_btn.text = "Звонок"
		call_btn.modulate = Color(1.0, 1.0, 1.0)
		chat_history.append_text("[color=yellow][i]Режим звонка отключён.[/i][/color]\n")

func _run_auto_call_loop() -> void:
	while auto_voice_call:
		if is_busy_generating or is_recording or (audio_player != null and audio_player.playing):
			await get_tree().create_timer(0.2).timeout
			continue
			
		call_btn.text = "Слушаю..."
		var http := HTTPRequest.new()
		add_child(http)
		var err := http.request("http://127.0.0.1:8022/listen")
		if err != OK:
			http.queue_free()
			auto_voice_call = false
			call_btn.text = "Звонок"
			call_btn.modulate = Color(1.0, 1.0, 1.0)
			break
			
		var res = await http.request_completed
		http.queue_free()
		
		if not auto_voice_call:
			break
			
		var result_code: int = res[1]
		var body: PackedByteArray = res[3]
		if result_code == 200:
			var spoken_text: String = body.get_string_from_utf8().strip_edges()
			if spoken_text != "":
				call_btn.text = "Отвечаю..."
				message_input.text = spoken_text
				await _on_send_pressed()
		else:
			chat_history.append_text("[color=salmon][b]Ошибка звонка:[/b] Сервер stt_server.py (8022) не запущен![/color]\n")
			auto_voice_call = false
			call_btn.text = "Звонок"
			call_btn.modulate = Color(1.0, 1.0, 1.0)
			break
			
		await get_tree().create_timer(0.15).timeout

# --- СКРЫТИЕ ИНТЕРФЕЙСА ---
func _toggle_ui_visibility() -> void:
	ui_hidden = not ui_hidden
	if top_bar != null:
		for child in top_bar.get_children():
			if child != hide_ui_btn:
				child.visible = not ui_hidden
	var vbox_chat := get_node_or_null("VBoxContainer")
	if vbox_chat != null:
		vbox_chat.visible = not ui_hidden
	if move_hud != null:
		move_hud.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if workflow_panel != null:
		workflow_panel.visible = false
	if hide_ui_btn != null:
		hide_ui_btn.text = "Показать" if ui_hidden else "Скрыть"
		hide_ui_btn.icon = _make_svg_icon("eye_off" if ui_hidden else "eye", "#9ec5ff")

# --- ОТДЕЛЬНОЕ ОКНО ПЕРСОНАЖА И ФОНЫ ---
func _toggle_avatar_window(enable: bool) -> void:
	if avatar_scene == null:
		return
		
	if enable and avatar_window == null:
		avatar_window = Window.new()
		avatar_window.title = "Ария — Аватар"
		avatar_window.size = Vector2i(480, 680)
		avatar_window.position = DisplayServer.window_get_position() + Vector2i(520, 60)
		avatar_window.transparent = true
		avatar_window.transparent_bg = (bg_mode == 0 or bg_mode == 7)
		avatar_window.always_on_top = avatar_always_on_top
		avatar_window.borderless = avatar_borderless
		
		avatar_window.close_requested.connect(func(): _toggle_avatar_window(false))
		avatar_window.window_input.connect(_on_avatar_window_input)
		add_child(avatar_window)
		
		avatar_scene.reparent(avatar_window)
		if move_hud != null:
			move_hud.reparent(avatar_window)
		avatar_window_open = true
		if popout_btn != null:
			popout_btn.text = "Вернуть"
	elif not enable and avatar_window != null:
		if move_hud != null:
			move_hud.reparent(self)
		avatar_scene.reparent(self)
		move_child(avatar_scene, 0)
		avatar_window.queue_free()
		avatar_window = null
		avatar_window_open = false
		if popout_btn != null:
			popout_btn.text = "Окно"
			
	_apply_background_mode()
	_save_settings()

func _on_avatar_window_input(event: InputEvent) -> void:
	if avatar_window == null:
		return
	_handle_avatar_mouse_drag(event)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_dragging_avatar:
			avatar_window.start_drag()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = clamp(camera_zoom - 0.08, 0.65, 2.40)
			if scene_camera != null: scene_camera.position.z = camera_zoom
			if zoom_slider != null: zoom_slider.value = camera_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = clamp(camera_zoom + 0.08, 0.65, 2.40)
			if scene_camera != null: scene_camera.position.z = camera_zoom
			if zoom_slider != null: zoom_slider.value = camera_zoom

func _apply_background_mode() -> void:
	if world_env == null and avatar_scene != null:
		world_env = WorldEnvironment.new()
		avatar_scene.add_child(world_env)
	if world_env == null:
		return
	if world_env.environment == null:
		world_env.environment = Environment.new()
		
	var env: Environment = world_env.environment
	var is_trans: bool = (bg_mode == 0 or bg_mode == 7)
	
	if avatar_window != null:
		avatar_window.transparent = true
		avatar_window.transparent_bg = is_trans
		get_tree().root.transparent_bg = is_trans
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, is_trans, 0)
	else:
		get_tree().root.transparent_bg = is_trans
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, is_trans, 0)
		
	if bg_color_picker != null:
		bg_color_picker.visible = (bg_mode == 6)
		
	_update_glass_shader_params()
	_set_linux_compositor_blur(bg_mode == 7)
		
	match bg_mode:
		0: # Полностью прозрачный оверлей
			RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))
			env.background_mode = Environment.BG_CLEAR_COLOR
		1:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.07, 0.08, 0.11)
		2:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.12, 0.04, 0.20)
		3:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.18, 0.10, 0.09)
		4:
			env.background_mode = Environment.BG_SKY
			if env.sky == null:
				var sky := Sky.new()
				var mat := ProceduralSkyMaterial.new()
				mat.sky_top_color = Color(0.22, 0.45, 0.78)
				mat.sky_horizon_color = Color(0.65, 0.78, 0.92)
				sky.sky_material = mat
				env.sky = sky
		5:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.0, 0.85, 0.0)
		6:
			env.background_mode = Environment.BG_COLOR
			env.background_color = custom_bg_color
		7: # Матовое стекло (Прозрачный фон за персонажем + Блюр окон)
			var glass_alpha: float = clamp(blur_strength * 0.22, 0.04, 0.35)
			RenderingServer.set_default_clear_color(Color(0.05, 0.07, 0.12, glass_alpha))
			env.background_mode = Environment.BG_CLEAR_COLOR

func _scan_models_folder() -> void:
	available_models.clear()
	var models_dir_path: String = _resolve_ext_path("res://models")
	var dir := DirAccess.open(models_dir_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".gguf"):
				available_models.append(models_dir_path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		
	if available_models.size() == 0:
		available_models.append(model_path)
	elif not (model_path in available_models):
		model_path = available_models[0]

func _init_ai_model(force_reload: bool = false) -> void:
	send_button.disabled = true
	message_input.editable = false
	
	if force_reload and ai_chat != null:
		chat_history.append_text("[color=yellow][i]Выгружаю старую модель из видеопамяти...[/i][/color]\n")
		ai_chat = null
		await get_tree().create_timer(0.8).timeout
	
	if ai_chat == null:
		chat_history.append_text(
			"[color=gray][i]Загружаю ИИ (" + model_path.get_file() + 
			" | Контекст: " + str(llm_context_size) + ")...[/i][/color]\n\n"
		)
		
		var memory_context: String = ""
		if saved_messages.size() > 0:
			memory_context = "\nВот краткая история ваших прошлых сообщений для контекста:\n"
			var start_idx: int = max(0, saved_messages.size() - 8)
			for i in range(start_idx, saved_messages.size()):
				var m = saved_messages[i]
				var who: String = "Пользователь" if m["role"] == "user" else "Ты"
				memory_context += who + ": " + m["text"] + "\n"
				
		var full_sys_prompt: String = (
			custom_persona + " " +
			"ОБЯЗАТЕЛЬНО начинай каждый свой ответ ровно с одного тега эмоции в квадратных скобках: " +
			"[neutral], [joy], [fun], [angry], [sorrow] или [surprised]. " +
			"Например: [fun] Ого, звучит как отличный план!" +
			memory_context
		)
		
		var llm_options: Dictionary = {
			"system_prompt": full_sys_prompt,
			"n_ctx": llm_context_size,
			"use_gpu": llm_gpu_layers > 0
		}
		
		ai_chat = await NobodyWhoChat.create(_resolve_ext_path(model_path), llm_options)
		
		if ai_chat == null:
			chat_history.append_text("[color=salmon][b]Ошибка:[/b] Не удалось загрузить модель (проверь наличие файла в res://models/).[/color]\n")
			return
			
		chat_history.append_text("[b]Система:[/b] Модель успешно загружена и готова к общению!\n\n")
	
	send_button.disabled = false
	message_input.editable = true
	message_input.grab_focus()

func _load_settings_and_memory() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var f := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(data) == TYPE_DICTIONARY:
			custom_persona = data.get("persona", custom_persona)
			voice_pitch = float(data.get("pitch", voice_pitch))
			voice_speed = float(data.get("speed", voice_speed))
			tts_enabled = bool(data.get("tts_enabled", tts_enabled))
			tts_engine = int(data.get("tts_engine", tts_engine))
			mouse_track_enabled = bool(data.get("mouse_track", mouse_track_enabled))
			camera_zoom = float(data.get("camera_zoom", camera_zoom))
			model_path = str(data.get("model_path", model_path))
			avatar_model_path = str(data.get("avatar_model_path", avatar_model_path))
			llm_gpu_layers = int(data.get("llm_gpu_layers", llm_gpu_layers))
			llm_context_size = int(data.get("llm_context_size", llm_context_size))
			bg_mode = int(data.get("bg_mode", bg_mode))
			blur_strength = float(data.get("blur_strength", blur_strength))
			custom_bg_color = Color.html(str(data.get("custom_bg_color", custom_bg_color.to_html())))
			avatar_window_open = bool(data.get("avatar_window_open", avatar_window_open))
			avatar_always_on_top = bool(data.get("avatar_always_on_top", avatar_always_on_top))
			avatar_borderless = bool(data.get("avatar_borderless", avatar_borderless))
			avatar_offset_x = float(data.get("avatar_offset_x", avatar_offset_x))
			avatar_offset_y = float(data.get("avatar_offset_y", avatar_offset_y))
			avatar_rot_y = float(data.get("avatar_rot_y", avatar_rot_y))
			
	if FileAccess.file_exists(MEMORY_FILE):
		var f := FileAccess.open(MEMORY_FILE, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(data) == TYPE_ARRAY:
			saved_messages = data

func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f:
		var dict := {
			"persona": custom_persona,
			"pitch": voice_pitch,
			"speed": voice_speed,
			"tts_enabled": tts_enabled,
			"tts_engine": tts_engine,
			"mouse_track": mouse_track_enabled,
			"camera_zoom": camera_zoom,
			"model_path": model_path,
			"avatar_model_path": avatar_model_path,
			"llm_gpu_layers": llm_gpu_layers,
			"llm_context_size": llm_context_size,
			"bg_mode": bg_mode,
			"blur_strength": blur_strength,
			"custom_bg_color": custom_bg_color.to_html(),
			"avatar_window_open": avatar_window_open,
			"avatar_always_on_top": avatar_always_on_top,
			"avatar_borderless": avatar_borderless,
			"avatar_offset_x": avatar_offset_x,
			"avatar_offset_y": avatar_offset_y,
			"avatar_rot_y": avatar_rot_y
		}
		f.store_string(JSON.stringify(dict, "\t"))
		f.close()

func _save_memory() -> void:
	if saved_messages.size() > 20:
		saved_messages = saved_messages.slice(saved_messages.size() - 20)
	var f := FileAccess.open(MEMORY_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(saved_messages, "\t"))
		f.close()

func _setup_grok_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0) # Полностью прозрачный фон, чтобы не закрывать Арию
	panel_style.set_content_margin_all(10)
	chat_history.add_theme_stylebox_override("normal", panel_style)
	chat_history.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	chat_history.add_theme_constant_override("shadow_offset_x", 1)
	chat_history.add_theme_constant_override("shadow_offset_y", 1)
	
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.11, 0.14, 0.20, 0.48)
	input_style.border_color = Color(0.45, 0.62, 0.90, 0.35)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(10)
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	message_input.add_theme_stylebox_override("normal", input_style)
	message_input.add_theme_stylebox_override("focus", input_style)
	chat_history.add_theme_color_override("default_color", Color(0.92, 0.95, 0.98))

func _setup_audio_and_lipsync() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.pitch_scale = voice_pitch
	add_child(audio_player)
	
	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.buffer_length = 0.1
	effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, effect, 0)
	spectrum_analyzer = AudioServer.get_bus_effect_instance(0, 0)

# --- ПАНЕЛЬ НАСТРОЕК С ВКЛАДКАМИ И ТЕМОЙ БЛЮРА ---
func _create_settings_ui() -> void:
	top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_bar.position = Vector2(-860, 16)
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)
	
	hide_ui_btn = Button.new()
	hide_ui_btn.text = "Скрыть"
	_style_icon_button(hide_ui_btn, "eye", "#9ec5ff")
	hide_ui_btn.pressed.connect(_toggle_ui_visibility)
	top_bar.add_child(hide_ui_btn)
	
	var nodes_btn := Button.new()
	nodes_btn.text = "Ноды"
	nodes_btn.tooltip_text = "Визуальный редактор сценариев и команд терминала"
	_style_icon_button(nodes_btn, "nodes", "#7bf1a8")
	nodes_btn.pressed.connect(func():
		if workflow_panel != null:
			workflow_panel.visible = not workflow_panel.visible
			if workflow_panel.visible and settings_panel != null:
				settings_panel.visible = false
	)
	top_bar.add_child(nodes_btn)
	
	var move_btn := Button.new()
	move_btn.text = "Двигать"
	_style_icon_button(move_btn, "move", "#a8f0c6")
	move_btn.pressed.connect(func():
		if move_hud != null:
			move_hud.visible = not move_hud.visible
	)
	top_bar.add_child(move_btn)
	
	popout_btn = Button.new()
	popout_btn.text = "Окно"
	_style_icon_button(popout_btn, "window", "#d4b5ff")
	popout_btn.pressed.connect(func(): _toggle_avatar_window(not avatar_window_open))
	top_bar.add_child(popout_btn)
	
	var stop_voice_btn := Button.new()
	stop_voice_btn.text = "Стоп"
	_style_icon_button(stop_voice_btn, "mute", "#ffb4a2")
	stop_voice_btn.pressed.connect(func():
		if audio_player != null and audio_player.playing:
			audio_player.stop()
	)
	top_bar.add_child(stop_voice_btn)
	
	var clear_btn := Button.new()
	clear_btn.text = "Очистить"
	_style_icon_button(clear_btn, "trash", "#ff9e9e")
	clear_btn.pressed.connect(_on_clear_memory_pressed)
	top_bar.add_child(clear_btn)
	
	var settings_btn := Button.new()
	settings_btn.text = "Настройки"
	_style_icon_button(settings_btn, "settings", "#ffe299")
	settings_btn.pressed.connect(func():
		settings_panel.visible = not settings_panel.visible
		if settings_panel.visible and workflow_panel != null:
			workflow_panel.visible = false
	)
	top_bar.add_child(settings_btn)
	
	_style_icon_button(send_button, "send", "#9ec5ff")
	var input_parent = message_input.get_parent()
	if input_parent is HBoxContainer:
		call_btn = Button.new()
		call_btn.text = "Звонок"
		call_btn.tooltip_text = "Режим непрерывного голосового разговора без нажатия кнопок"
		_style_icon_button(call_btn, "phone", "#a8f0c6")
		call_btn.pressed.connect(_toggle_auto_call)
		input_parent.add_child(call_btn)
		input_parent.move_child(call_btn, 0)
		
		mic_btn = Button.new()
		mic_btn.text = "Голос"
		mic_btn.tooltip_text = "Нажми, скажи фразу и нажми ещё раз для отправки"
		_style_icon_button(mic_btn, "mic", "#ffb4a2")
		mic_btn.pressed.connect(_toggle_voice_recording)
		input_parent.add_child(mic_btn)
		input_parent.move_child(mic_btn, 0)
	
	move_hud = PanelContainer.new()
	move_hud.visible = false
	move_hud.position = Vector2(20, 60)
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.08, 0.09, 0.13, 0.72)
	hud_style.set_corner_radius_all(10)
	hud_style.set_content_margin_all(8)
	move_hud.add_theme_stylebox_override("panel", hud_style)
	move_hud.add_child(_create_dpad_controls())
	add_child(move_hud)
	_attach_glass_blur_backdrop(move_hud)
	
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.custom_minimum_size = Vector2(540, 490)
	settings_panel.position = Vector2(24, 58)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.84)
	style.border_color = Color(0.35, 0.48, 0.72, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)
	_attach_glass_blur_backdrop(settings_panel)
	
	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	settings_panel.add_child(root_vbox)
	
	var header_bar := HBoxContainer.new()
	root_vbox.add_child(header_bar)
	
	var header_title := Label.new()
	header_title.text = "Настройки компаньона Арии"
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.add_theme_font_size_override("font_size", 16)
	header_title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	header_bar.add_child(header_title)
	
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.tooltip_text = "Закрыть окно настроек (Esc)"
	_style_icon_button(close_btn, "close", "#ff9e9e")
	close_btn.pressed.connect(func(): settings_panel.visible = false)
	header_bar.add_child(close_btn)
	
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(tabs)
	
	# ВКЛАДКА 1: ВИД И 3D
	var tab_view := VBoxContainer.new()
	tab_view.name = "Вид и 3D"
	tab_view.add_theme_constant_override("separation", 10)
	tabs.add_child(tab_view)
	tabs.set_tab_icon(0, _make_svg_icon("window", "#d4b5ff", 16))
	
	var card_bg := _create_section_card(tab_view, "Тема окна и размытие фона (Blur)")
	var bg_hbox := HBoxContainer.new()
	bg_hbox.add_theme_constant_override("separation", 8)
	card_bg.add_child(bg_hbox)
	
	bg_dropdown = OptionButton.new()
	bg_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_dropdown.add_item("0. Прозрачный фон (Чистый оверлей без блюра)", 0)
	bg_dropdown.add_item("1. Тёмный Grok (Стандартный)", 1)
	bg_dropdown.add_item("2. Киберпанк Неон (Фиолетовый)", 2)
	bg_dropdown.add_item("3. Уютный Вечер (Тёплый)", 3)
	bg_dropdown.add_item("4. Дневное 3D-небо с горизонтом", 4)
	bg_dropdown.add_item("5. Зелёный Хромакей (Для стримов / OBS)", 5)
	bg_dropdown.add_item("6. Свой цвет фона (Выбрать из палитры)", 6)
	bg_dropdown.add_item("7. Матовое стекло (Прозрачный фон + Блюр)", 7)
	bg_dropdown.selected = clamp(bg_mode, 0, 7)
	bg_dropdown.item_selected.connect(func(idx: int):
		bg_mode = idx
		_apply_background_mode()
		_save_settings()
	)
	bg_hbox.add_child(bg_dropdown)
	
	bg_color_picker = ColorPickerButton.new()
	bg_color_picker.custom_minimum_size = Vector2(44, 30)
	bg_color_picker.color = custom_bg_color
	bg_color_picker.visible = (bg_mode == 6)
	bg_color_picker.color_changed.connect(func(col: Color):
		custom_bg_color = col
		_apply_background_mode()
		_save_settings()
	)
	bg_hbox.add_child(bg_color_picker)
	
	# Ползунок регулировки силы блюра и матовости стекла
	var blur_row := HBoxContainer.new()
	blur_row.add_theme_constant_override("separation", 10)
	card_bg.add_child(blur_row)
	
	var blur_title := Label.new()
	blur_title.text = "Сила блюра и матовости:"
	blur_row.add_child(blur_title)
	
	blur_slider = HSlider.new()
	blur_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blur_slider.min_value = 0.15
	blur_slider.max_value = 1.00
	blur_slider.step = 0.05
	blur_slider.value = blur_strength
	blur_row.add_child(blur_slider)
	
	blur_val_lbl = Label.new()
	blur_val_lbl.text = str(int(blur_strength * 100)) + "%"
	blur_val_lbl.custom_minimum_size = Vector2(44, 0)
	blur_row.add_child(blur_val_lbl)
	
	blur_slider.value_changed.connect(func(val: float):
		blur_strength = val
		blur_val_lbl.text = str(int(val * 100)) + "%"
		_apply_background_mode()
		_save_settings()
	)
	
	var win_checks := HBoxContainer.new()
	win_checks.add_theme_constant_override("separation", 14)
	card_bg.add_child(win_checks)
	
	on_top_check = CheckButton.new()
	on_top_check.text = "Поверх всех окон"
	on_top_check.button_pressed = avatar_always_on_top
	on_top_check.toggled.connect(func(val: bool):
		avatar_always_on_top = val
		if avatar_window != null:
			avatar_window.always_on_top = val
		_save_settings()
	)
	win_checks.add_child(on_top_check)
	
	borderless_check = CheckButton.new()
	borderless_check.text = "Без рамки (тащить ЛКМ)"
	borderless_check.button_pressed = avatar_borderless
	borderless_check.toggled.connect(func(val: bool):
		avatar_borderless = val
		if avatar_window != null:
			avatar_window.borderless = val
		_save_settings()
	)
	win_checks.add_child(borderless_check)
	
	var card_av := _create_section_card(tab_view, "3D Модель персонажа (.vrm / .glb)")
	var av_hbox := HBoxContainer.new()
	av_hbox.add_theme_constant_override("separation", 8)
	card_av.add_child(av_hbox)
	
	avatar_dropdown = OptionButton.new()
	avatar_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_avatar_dropdown()
	avatar_dropdown.item_selected.connect(func(idx: int):
		var chosen: String = available_avatars[idx]
		_load_custom_avatar_model(chosen)
	)
	av_hbox.add_child(avatar_dropdown)
	
	var browse_av_btn := Button.new()
	browse_av_btn.text = "Файл..."
	browse_av_btn.tooltip_text = "Выбрать .vrm или .glb модель с диска"
	_style_icon_button(browse_av_btn, "user", "#a8f0c6")
	browse_av_btn.pressed.connect(func():
		if avatar_file_dialog == null:
			avatar_file_dialog = FileDialog.new()
			avatar_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			avatar_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			avatar_file_dialog.filters = PackedStringArray(["*.vrm, *.glb, *.gltf ; 3D Avatars (VRM / GLB)"])
			avatar_file_dialog.size = Vector2i(720, 480)
			avatar_file_dialog.file_selected.connect(func(f_path: String):
				if not (f_path in available_avatars):
					available_avatars.append(f_path)
				_populate_avatar_dropdown()
				_load_custom_avatar_model(f_path)
			)
			add_child(avatar_file_dialog)
		avatar_file_dialog.popup_centered()
	)
	av_hbox.add_child(browse_av_btn)
	
	var card_pos := _create_section_card(tab_view, "Позиция персонажа и камера")
	pos_label = Label.new()
	pos_label.text = (
		"X: " + str(snapped(avatar_offset_x, 0.05)) +
		"  |  Y: " + str(snapped(avatar_offset_y, 0.05)) +
		"  |  Угол: " + str(int(avatar_rot_y)) + "° (или зажми ПКМ)"
	)
	card_pos.add_child(pos_label)
	card_pos.add_child(_create_dpad_controls())
	
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 10)
	card_pos.add_child(zoom_row)
	
	var zoom_title := Label.new()
	zoom_title.text = "Дистанция камеры:"
	zoom_row.add_child(zoom_title)
	
	zoom_slider = HSlider.new()
	zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_slider.min_value = 0.65
	zoom_slider.max_value = 2.40
	zoom_slider.step = 0.05
	zoom_slider.value = camera_zoom
	zoom_row.add_child(zoom_slider)
	
	zoom_val_lbl = Label.new()
	zoom_val_lbl.text = str(snapped(camera_zoom, 0.05))
	zoom_val_lbl.custom_minimum_size = Vector2(40, 0)
	zoom_row.add_child(zoom_val_lbl)
	
	zoom_slider.value_changed.connect(func(val: float):
		camera_zoom = val
		if scene_camera != null:
			scene_camera.position.z = val
		zoom_val_lbl.text = str(snapped(val, 0.05))
		_save_settings()
	)
	
	track_check = CheckButton.new()
	track_check.text = "Следить глазами и головой за курсором мыши"
	track_check.button_pressed = mouse_track_enabled
	track_check.toggled.connect(func(val: bool):
		mouse_track_enabled = val
		_save_settings()
	)
	card_pos.add_child(track_check)
	
	var card_emo := _create_section_card(tab_view, "Быстрый тест эмоций")
	var emo_box := HBoxContainer.new()
	emo_box.add_theme_constant_override("separation", 6)
	card_emo.add_child(emo_box)
	
	var emo_names_ru: Dictionary = {
		"neutral": "Спокойствие",
		"joy": "Радость",
		"fun": "Веселье",
		"angry": "Злость",
		"sorrow": "Грусть",
		"surprised": "Удивление"
	}
	for emo in emo_names_ru.keys():
		var e_btn := Button.new()
		e_btn.text = emo_names_ru[emo]
		e_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_icon_button(e_btn, "", "#9ec5ff")
		e_btn.pressed.connect(func(): current_emotion = emo)
		emo_box.add_child(e_btn)
		
	# ВКЛАДКА 2: ХАРАКТЕР
	var tab_persona := VBoxContainer.new()
	tab_persona.name = "Характер"
	tab_persona.add_theme_constant_override("separation", 10)
	tabs.add_child(tab_persona)
	tabs.set_tab_icon(1, _make_svg_icon("user", "#a8f0c6", 16))
	
	var card_presets := _create_section_card(tab_persona, "Готовые шаблоны личности")
	var presets_box := HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", 8)
	card_presets.add_child(presets_box)
	
	var presets: Dictionary = {
		"Милая Ария": "Ты — нежная, заботливая и милая девушка-компаньон Ария. Говори ласково, поддерживай собеседника, отвечай коротко (1-2 предложения) на русском.",
		"Хакерша Никс": "Ты — дерзкая и саркастичная киберпанк-хакерша Никс, обожающая Arch Linux и CachyOS. Шути остроумно, используй сленг, отвечай коротко (1-2 предложения).",
		"Леди Эвелин": "Ты — строгая, интеллектуальная и элегантная ассистентка Эвелин. Говори вежливо, с лёгкой иронией и безупречным стилем, коротко (1-2 предложения).",
		"Изобретательница": "Ты — эксцентричная, гиперактивная девушка-изобретательница! Постоянно восхищайся безумными идеями и отвечай коротко (1-2 предложения)."
	}
	for p_name in presets.keys():
		var p_btn := Button.new()
		p_btn.text = p_name
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_icon_button(p_btn, "", "#a8f0c6")
		p_btn.pressed.connect(func(): persona_edit.text = presets[p_name])
		presets_box.add_child(p_btn)
		
	var card_prompt := _create_section_card(tab_persona, "Системная инструкция (System Prompt)")
	persona_edit = TextEdit.new()
	persona_edit.text = custom_persona
	persona_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	persona_edit.custom_minimum_size = Vector2(0, 140)
	card_prompt.add_child(persona_edit)
	
	var save_btn := Button.new()
	save_btn.text = "Применить новый характер на лету (без перезагрузки VRAM)"
	_style_icon_button(save_btn, "send", "#a8f0c6")
	save_btn.pressed.connect(_on_save_settings_pressed)
	card_prompt.add_child(save_btn)
	
	# ВКЛАДКА 3: ГОЛОС
	var tab_voice := VBoxContainer.new()
	tab_voice.name = "Голос"
	tab_voice.add_theme_constant_override("separation", 10)
	tabs.add_child(tab_voice)
	tabs.set_tab_icon(2, _make_svg_icon("volume", "#ffb4a2", 16))
	
	var card_tts := _create_section_card(tab_voice, "Движок синтеза речи (TTS)")
	tts_check = CheckButton.new()
	tts_check.text = "Озвучивать ответы Арии голосом"
	tts_check.button_pressed = tts_enabled
	tts_check.toggled.connect(func(val: bool):
		tts_enabled = val
		_save_settings()
	)
	card_tts.add_child(tts_check)
	
	tts_engine_dropdown = OptionButton.new()
	tts_engine_dropdown.add_item("Piper TTS (Локальный русский голос — мгновенный)", 0)
	tts_engine_dropdown.add_item("Kyutai Pocket-TTS (Нейросеть 127.0.0.1:8021)", 1)
	tts_engine_dropdown.selected = clamp(tts_engine, 0, 1)
	tts_engine_dropdown.item_selected.connect(func(idx: int):
		tts_engine = idx
		if tts_engine == 1:
			_ensure_pocket_tts_running()
		_save_settings()
	)
	card_tts.add_child(tts_engine_dropdown)
	
	var card_voice_tune := _create_section_card(tab_voice, "Тонкая настройка тембра и скорости")
	
	var pitch_row := HBoxContainer.new()
	pitch_row.add_theme_constant_override("separation", 10)
	card_voice_tune.add_child(pitch_row)
	var pitch_title := Label.new()
	pitch_title.text = "Высота голоса (Pitch):"
	pitch_title.custom_minimum_size = Vector2(170, 0)
	pitch_row.add_child(pitch_title)
	pitch_slider = HSlider.new()
	pitch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_slider.min_value = 0.85
	pitch_slider.max_value = 1.35
	pitch_slider.step = 0.01
	pitch_slider.value = voice_pitch
	pitch_row.add_child(pitch_slider)
	pitch_val_lbl = Label.new()
	pitch_val_lbl.text = str(snapped(voice_pitch, 0.01))
	pitch_val_lbl.custom_minimum_size = Vector2(45, 0)
	pitch_row.add_child(pitch_val_lbl)
	pitch_slider.value_changed.connect(func(val: float):
		voice_pitch = val
		audio_player.pitch_scale = val
		pitch_val_lbl.text = str(snapped(val, 0.01))
		_save_settings()
	)
	
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	card_voice_tune.add_child(speed_row)
	var speed_title := Label.new()
	speed_title.text = "Длительность слогов:"
	speed_title.custom_minimum_size = Vector2(170, 0)
	speed_row.add_child(speed_title)
	speed_slider = HSlider.new()
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.min_value = 0.65
	speed_slider.max_value = 1.40
	speed_slider.step = 0.05
	speed_slider.value = voice_speed
	speed_row.add_child(speed_slider)
	speed_val_lbl = Label.new()
	speed_val_lbl.text = str(snapped(voice_speed, 0.01))
	speed_val_lbl.custom_minimum_size = Vector2(45, 0)
	speed_row.add_child(speed_val_lbl)
	speed_slider.value_changed.connect(func(val: float):
		voice_speed = val
		speed_val_lbl.text = str(snapped(val, 0.01))
		_save_settings()
	)
	
	var test_voice_btn := Button.new()
	test_voice_btn.text = "Прослушать тестовую фразу"
	_style_icon_button(test_voice_btn, "volume", "#ffb4a2")
	test_voice_btn.pressed.connect(func():
		var sample_wav: String = _generate_tts_wav("Привет! Так звучит мой голос с текущими настройками.")
		if sample_wav != "":
			var wav_stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(sample_wav))
			if wav_stream != null:
				audio_player.stream = wav_stream
				audio_player.play()
	)
	card_voice_tune.add_child(test_voice_btn)
	
	# ВКЛАДКА 4: МОДЕЛЬ ИИ
	var tab_llm := VBoxContainer.new()
	tab_llm.name = "Модель ИИ"
	tab_llm.add_theme_constant_override("separation", 10)
	tabs.add_child(tab_llm)
	tabs.set_tab_icon(3, _make_svg_icon("cpu", "#ffe299", 16))
	
	var card_llm := _create_section_card(tab_llm, "Локальная языковая модель (GGUF)")
	model_dropdown = OptionButton.new()
	for i in range(available_models.size()):
		var m_path: String = available_models[i]
		model_dropdown.add_item(m_path.get_file(), i)
		if m_path == model_path:
			model_dropdown.selected = i
	model_dropdown.item_selected.connect(func(idx: int):
		model_path = available_models[idx]
		_save_settings()
	)
	card_llm.add_child(model_dropdown)
	
	var gpu_row := HBoxContainer.new()
	gpu_row.add_theme_constant_override("separation", 10)
	card_llm.add_child(gpu_row)
	var gpu_title := Label.new()
	gpu_title.text = "Слои на GPU (VRAM):"
	gpu_title.custom_minimum_size = Vector2(165, 0)
	gpu_row.add_child(gpu_title)
	gpu_slider = HSlider.new()
	gpu_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gpu_slider.min_value = 0
	gpu_slider.max_value = 40
	gpu_slider.step = 1
	gpu_slider.value = llm_gpu_layers
	gpu_row.add_child(gpu_slider)
	gpu_val_lbl = Label.new()
	gpu_val_lbl.text = str(llm_gpu_layers)
	gpu_val_lbl.custom_minimum_size = Vector2(50, 0)
	gpu_row.add_child(gpu_val_lbl)
	gpu_slider.value_changed.connect(func(val: float):
		llm_gpu_layers = int(val)
		gpu_val_lbl.text = str(llm_gpu_layers)
		_save_settings()
	)
	
	var ctx_row := HBoxContainer.new()
	ctx_row.add_theme_constant_override("separation", 10)
	card_llm.add_child(ctx_row)
	var ctx_title := Label.new()
	ctx_title.text = "Память контекста:"
	ctx_title.custom_minimum_size = Vector2(165, 0)
	ctx_row.add_child(ctx_title)
	ctx_slider = HSlider.new()
	ctx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctx_slider.min_value = 512
	ctx_slider.max_value = 8192
	ctx_slider.step = 512
	ctx_slider.value = llm_context_size
	ctx_row.add_child(ctx_slider)
	ctx_val_lbl = Label.new()
	ctx_val_lbl.text = str(llm_context_size)
	ctx_val_lbl.custom_minimum_size = Vector2(50, 0)
	ctx_row.add_child(ctx_val_lbl)
	ctx_slider.value_changed.connect(func(val: float):
		llm_context_size = int(val)
		ctx_val_lbl.text = str(llm_context_size)
		_save_settings()
	)
	
	var reload_llm_btn := Button.new()
	reload_llm_btn.text = "Перезагрузить модель ИИ с новыми параметрами"
	_style_icon_button(reload_llm_btn, "rot_r", "#ffe299")
	reload_llm_btn.pressed.connect(func():
		settings_panel.visible = false
		await _init_ai_model(true)
	)
	card_llm.add_child(reload_llm_btn)

func _on_save_settings_pressed() -> void:
	custom_persona = persona_edit.text.strip_edges()
	_save_settings()
	settings_panel.visible = false
	
	send_button.disabled = true
	message_input.editable = false
	chat_history.append_text("[color=yellow][i]Обновляю характер на лету...[/i][/color]\n")
	
	if ai_chat != null:
		var update_msg: String = (
			"[СИСТЕМНАЯ ИНСТРУКЦИЯ: Твой характер изменён пользователем. Теперь следуй новому описанию: " +
			custom_persona +
			" Продолжай начинать каждый ответ с тега эмоции в квадратных скобках, например [joy] или [fun].]"
		)
		var stream = ai_chat.ask(update_msg)
		await stream.completed()
		
	chat_history.append_text("[color=lightgreen][i]Характер успешно применён![/i][/color]\n\n")
	send_button.disabled = false
	message_input.editable = true
	message_input.grab_focus()

func _on_clear_memory_pressed() -> void:
	saved_messages.clear()
	_save_memory()
	chat_history.clear()
	
	if ai_chat != null:
		if ai_chat.has_method("reset"):
			ai_chat.call("reset")
		else:
			var stream = ai_chat.ask("[СИСТЕМНАЯ ИНСТРУКЦИЯ: Забудь всю предыдущую историю беседы. Начинаем новый диалог с чистого листа.]")
			await stream.completed()
			
	chat_history.append_text("[color=yellow][i]Память диалогов очищена![/i][/color]\n\n")
	message_input.grab_focus()

# --- СКАНИРОВАНИЕ И ГОРЯЧАЯ ЗАМЕНА 3D-МОДЕЛЕЙ (.VRM / .GLB) ---
func _scan_avatars_folder() -> void:
	available_avatars = ["default"]
	var av_dir_path: String = _resolve_ext_path("res://avatars")
	var dir := DirAccess.open(av_dir_path)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			var low: String = fname.to_lower()
			if not dir.current_is_dir() and (low.ends_with(".vrm") or low.ends_with(".glb") or low.ends_with(".gltf")):
				available_avatars.append(av_dir_path.path_join(fname))
			fname = dir.get_next()
		dir.list_dir_end()
	# Также проверяем корневую папку на случай дополнительных .vrm/.glb
	var root_dir := DirAccess.open(_resolve_ext_path("res://"))
	if root_dir != null:
		root_dir.list_dir_begin()
		var rname: String = root_dir.get_next()
		while rname != "":
			var rlow: String = rname.to_lower()
			if not root_dir.current_is_dir() and (rlow.ends_with(".vrm") or rlow.ends_with(".glb")) and rlow != "avatar.glb":
				var full_p: String = _resolve_ext_path("res://").path_join(rname)
				if not (full_p in available_avatars):
					available_avatars.append(full_p)
			rname = root_dir.get_next()
		root_dir.list_dir_end()
	if avatar_model_path != "default" and FileAccess.file_exists(avatar_model_path) and not (avatar_model_path in available_avatars):
		available_avatars.append(avatar_model_path)

func _populate_avatar_dropdown() -> void:
	if avatar_dropdown == null:
		return
	avatar_dropdown.clear()
	for i in range(available_avatars.size()):
		var p: String = available_avatars[i]
		var label_txt: String = "Стандартный аватар (avatar.glb)" if p == "default" else p.get_file()
		avatar_dropdown.add_item(label_txt, i)
		if p == avatar_model_path:
			avatar_dropdown.selected = i

func _load_custom_avatar_model(path_str: String) -> void:
	if avatar_scene == null:
		return
	var new_instance: Node3D = null
	
	if path_str == "default":
		var packed := load("res://avatar.glb") as PackedScene
		if packed != null:
			new_instance = packed.instantiate()
	else:
		var real_path: String = _resolve_ext_path(path_str)
		if not FileAccess.file_exists(real_path):
			chat_history.append_text("[color=salmon][b]Ошибка 3D:[/b] Файл модели не найден: " + real_path + "[/color]\n")
			return
		# Загружаем .vrm / .glb / .gltf напрямую через встроенный GLTFDocument
		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		var err: int = gltf_doc.append_from_file(real_path, gltf_state)
		if err == OK:
			var generated_node: Node = gltf_doc.generate_scene(gltf_state)
			if generated_node is Node3D:
				new_instance = generated_node
		else:
			chat_history.append_text("[color=salmon][b]Ошибка загрузки VRM/GLB:[/b] Код " + str(err) + "[/color]\n")
			return
			
	if new_instance == null:
		return
		
	# Удаляем предыдущую модель со сцены
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()
		
	# Сбрасываем индексы костей и морфов лица перед сканированием новой модели
	skeleton = null
	left_arm_idx = -1
	right_arm_idx = -1
	head_idx = -1
	left_eye_idx = -1
	right_eye_idx = -1
	face_mesh = null
	blink_shape_idx = -1
	vowels.clear()
	emotions.clear()
	
	avatar_scene.add_child(new_instance)
	avatar = new_instance
	avatar.position = base_avatar_pos
	
	# В VRM 0.x модели по умолчанию повернуты лицом по +Z (спиной к камере Godot), разворачиваем при необходимости
	if path_str.to_lower().ends_with(".vrm") and abs(avatar_rot_y) < 1.0:
		avatar_rot_y = 180.0
	elif path_str == "default" and abs(avatar_rot_y - 180.0) < 1.0:
		avatar_rot_y = 0.0
		
	_inspect_and_setup_avatar(avatar)
	_apply_avatar_transform()
	
	avatar_model_path = path_str
	_populate_avatar_dropdown()
	_save_settings()
	chat_history.append_text("[color=lightgreen][i]3D-модель переключена: " + ("avatar.glb" if path_str == "default" else path_str.get_file()) + "[/i][/color]\n")

func _inspect_and_setup_avatar(node: Node) -> void:
	if node is Skeleton3D and skeleton == null:
		skeleton = node
		for i in range(skeleton.get_bone_count()):
			var bname: String = skeleton.get_bone_name(i).to_lower()
			if ("upperarm" in bname or "upper_arm" in bname or "arm" in bname) and not ("fore" in bname or "lower" in bname or "hand" in bname):
				if "l" in bname or "left" in bname:
					if left_arm_idx == -1: left_arm_idx = i
				elif "r" in bname or "right" in bname:
					if right_arm_idx == -1: right_arm_idx = i
			elif "head" in bname and head_idx == -1:
				head_idx = i
			elif "eye" in bname:
				if "l" in bname or "left" in bname:
					if left_eye_idx == -1: left_eye_idx = i
				elif "r" in bname or "right" in bname:
					if right_eye_idx == -1: right_eye_idx = i

	if node is MeshInstance3D and node.mesh and node.mesh.get_blend_shape_count() > 0:
		for i in range(node.mesh.get_blend_shape_count()):
			var raw_name: String = node.mesh.get_blend_shape_name(i)
			var low_bs: String = raw_name.to_lower()
			if raw_name in ["Fcl_EYE_Close", "Blink", "blink", "eyeBlinkLeft", "Fcl_EYE_Close_R"]:
				if blink_shape_idx == -1 or raw_name == "Fcl_EYE_Close":
					face_mesh = node
					blink_shape_idx = i
			elif raw_name in ["Fcl_MTH_A", "A", "aa", "vrc.v_aa", "mouthOpen"]:
				face_mesh = node
				vowels["A"] = i
			elif raw_name in ["Fcl_MTH_I", "I", "ih", "vrc.v_ih"]:
				vowels["I"] = i
			elif raw_name in ["Fcl_MTH_U", "U", "ou", "vrc.v_ou"]:
				vowels["U"] = i
			elif raw_name in ["Fcl_MTH_E", "E", "ee", "vrc.v_e"]:
				vowels["E"] = i
			elif raw_name in ["Fcl_MTH_O", "O", "oh", "vrc.v_oh"]:
				vowels["O"] = i
			elif raw_name in ["Fcl_ALL_Joy", "Joy", "happy", "Happy"]:
				emotions["joy"] = i
			elif raw_name in ["Fcl_ALL_Fun", "Fun", "relaxed", "Relaxed"]:
				emotions["fun"] = i
			elif raw_name in ["Fcl_ALL_Angry", "Angry", "angry"]:
				emotions["angry"] = i
			elif raw_name in ["Fcl_ALL_Sorrow", "Sorrow", "sad", "Sad"]:
				emotions["sorrow"] = i
			elif raw_name in ["Fcl_ALL_Surprised", "Surprised", "surprised"]:
				emotions["surprised"] = i

	for child in node.get_children():
		_inspect_and_setup_avatar(child)

func _process(delta: float) -> void:
	if avatar == null:
		return
		
	time_passed += delta
	avatar.position.x = base_avatar_pos.x + avatar_offset_x
	avatar.position.y = base_avatar_pos.y + avatar_offset_y + sin(time_passed * 2.2) * 0.003
	avatar.rotation_degrees.y = avatar_rot_y
	
	var voice_playing: bool = audio_player != null and audio_player.playing
	var active_speech: bool = voice_playing or is_speaking
	
	if skeleton != null:
		var target_mouse := Vector2.ZERO
		if mouse_track_enabled:
			var active_vp: Viewport = avatar.get_viewport()
			var vp_size: Vector2 = active_vp.get_visible_rect().size
			var mouse_pos: Vector2 = active_vp.get_mouse_position()
			target_mouse = Vector2(
				clamp((mouse_pos.x / max(vp_size.x, 1.0) - 0.5) * 2.0, -1.0, 1.0),
				clamp((mouse_pos.y / max(vp_size.y, 1.0) - 0.5) * 2.0, -1.0, 1.0)
			)
		smooth_mouse = smooth_mouse.lerp(target_mouse, delta * 5.0)
		
		var arm_breathe: float = sin(time_passed * 2.2) * 1.5
		if left_arm_idx != -1:
			var base_rot := skeleton.get_bone_rest(left_arm_idx).basis.get_rotation_quaternion()
			var down_rot := Quaternion.from_euler(Vector3(0, 0, deg_to_rad(-68.0 + arm_breathe)))
			skeleton.set_bone_pose_rotation(left_arm_idx, base_rot * down_rot)
		if right_arm_idx != -1:
			var base_rot := skeleton.get_bone_rest(right_arm_idx).basis.get_rotation_quaternion()
			var down_rot := Quaternion.from_euler(Vector3(0, 0, deg_to_rad(68.0 - arm_breathe)))
			skeleton.set_bone_pose_rotation(right_arm_idx, base_rot * down_rot)
			
		if head_idx != -1:
			var base_rot := skeleton.get_bone_rest(head_idx).basis.get_rotation_quaternion()
			var nod_speed: float = 4.5 if active_speech else 1.1
			var nod_amp: float = 3.5 if active_speech else 2.0
			
			var pitch_deg: float = sin(time_passed * nod_speed) * nod_amp - smooth_mouse.y * -10.0
			var yaw_deg: float = sin(time_passed * 0.7) * 2.5 + smooth_mouse.x * 16.0
			var roll_deg: float = sin(time_passed * 0.9) * 1.5 - smooth_mouse.x * -4.0
			
			var head_tilt := Quaternion.from_euler(Vector3(
				deg_to_rad(pitch_deg),
				deg_to_rad(yaw_deg),
				deg_to_rad(roll_deg)
			))
			skeleton.set_bone_pose_rotation(head_idx, base_rot * head_tilt)
			
		var eye_rot := Quaternion.from_euler(Vector3(
			deg_to_rad(-smooth_mouse.y * -6.0),
			deg_to_rad(smooth_mouse.x * 9.0),
			0.0
		))
		if left_eye_idx != -1:
			var base_eye_l := skeleton.get_bone_rest(left_eye_idx).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(left_eye_idx, base_eye_l * eye_rot)
		if right_eye_idx != -1:
			var base_eye_r := skeleton.get_bone_rest(right_eye_idx).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(right_eye_idx, base_eye_r * eye_rot)

	if face_mesh == null:
		return
		
	for emo_name in emotions.keys():
		var idx: int = emotions[emo_name]
		var target_val: float = 0.75 if emo_name == current_emotion else 0.0
		var cur_val: float = face_mesh.get_blend_shape_value(idx)
		face_mesh.set_blend_shape_value(idx, move_toward(cur_val, target_val, delta * 3.5))

	if blink_shape_idx != -1 and current_emotion != "joy":
		blink_timer += delta
		if blink_timer > 3.8:
			var blink_weight: float = sin((blink_timer - 3.8) * 18.0)
			if blink_weight >= 0.0:
				face_mesh.set_blend_shape_value(blink_shape_idx, blink_weight)
			else:
				face_mesh.set_blend_shape_value(blink_shape_idx, 0.0)
				blink_timer = randf_range(0.0, 1.5)
				
	if voice_playing and spectrum_analyzer != null:
		var low_mag: float = spectrum_analyzer.get_magnitude_for_frequency_range(200, 700).length()
		var mid_mag: float = spectrum_analyzer.get_magnitude_for_frequency_range(700, 1800).length()
		var high_mag: float = spectrum_analyzer.get_magnitude_for_frequency_range(1800, 3500).length()
		
		var target_a: float = clamp(low_mag * 16.0, 0.0, 0.95)
		var target_o: float = clamp(mid_mag * 12.0, 0.0, 0.7)
		var target_i: float = clamp(high_mag * 18.0, 0.0, 0.65)
		
		if vowels.has("A"):
			face_mesh.set_blend_shape_value(vowels["A"], move_toward(face_mesh.get_blend_shape_value(vowels["A"]), target_a, delta * 18.0))
		if vowels.has("O"):
			face_mesh.set_blend_shape_value(vowels["O"], move_toward(face_mesh.get_blend_shape_value(vowels["O"]), target_o, delta * 15.0))
		if vowels.has("I"):
			face_mesh.set_blend_shape_value(vowels["I"], move_toward(face_mesh.get_blend_shape_value(vowels["I"]), target_i, delta * 15.0))
	else:
		for v_key in vowels.keys():
			var idx: int = vowels[v_key]
			var target_mouth: float = 0.0
			if is_speaking and v_key == current_vowel:
				target_mouth = (sin(time_passed * 28.0) * 0.4 + 0.5) * 0.85
			var cur_mouth: float = face_mesh.get_blend_shape_value(idx)
			face_mesh.set_blend_shape_value(idx, move_toward(cur_mouth, target_mouth, delta * 12.0))

func _update_vowel_from_char(ch: String) -> void:
	var c: String = ch.to_lower()
	if c in ["а", "я"]: current_vowel = "A"
	elif c in ["о", "ё"]: current_vowel = "O"
	elif c in ["у", "ю"]: current_vowel = "U"
	elif c in ["э", "е"]: current_vowel = "E"
	elif c in ["и", "ы"]: current_vowel = "I"

func _extract_emotion_and_clean_text(raw_reply: String) -> String:
	var text: String = raw_reply.strip_edges()
	# Отрезаем блок размышлений LFM3 / Qwen3 / DeepSeek (всё до закрывающего </think>)
	if "</think>" in text:
		text = text.split("</think>")[-1].strip_edges()
	elif "<|think|>" in text and "<|/think|>" in text:
		text = text.split("<|/think|>")[-1].strip_edges()
	var lower: String = text.to_lower()
	
	var emo_aliases: Dictionary = {
		"neutral": ["[neutral", "[нейтрал", "[спокойн"],
		"joy": ["[joy", "[happy", "[smile", "[радост", "[улыб", "[счаст"],
		"fun": ["[fun", "[laugh", "[excited", "[playful", "[весел", "[смех", "[шут"],
		"angry": ["[angry", "[mad", "[annoyed", "[злост", "[гнев", "[сердит"],
		"sorrow": ["[sorrow", "[sad", "[cry", "[груст", "[печал", "[вздох"],
		"surprised": ["[surprised", "[shock", "[wow", "[удив", "[шок"]
	}
	
	for emo_key in emo_aliases.keys():
		for alias in emo_aliases[emo_key]:
			if alias in lower:
				current_emotion = emo_key
				break
				
	var regex := RegEx.new()
	regex.compile("\\[[^\\]]*\\]|\\*[^\\*]*\\*|\\([a-zA-Z_ ]+\\)")
	text = regex.sub(text, "", true).strip_edges()
	
	while "  " in text:
		text = text.replace("  ", " ")
		
	return text

func _generate_tts_wav(text_to_speak: String) -> String:
	if not tts_enabled or text_to_speak == "":
		return ""
		
	var in_txt: String = ProjectSettings.globalize_path("user://speech.txt")
	var out_wav: String = ProjectSettings.globalize_path("user://speech.wav")
	
	if FileAccess.file_exists("user://speech.wav"):
		DirAccess.remove_absolute(out_wav)
		
	var f := FileAccess.open("user://speech.txt", FileAccess.WRITE)
	if f:
		f.store_string(text_to_speak.replace("\n", " ").strip_edges() + "\n")
		f.close()
		
	if tts_engine == 1:
		_ensure_pocket_tts_running()
		var pocket_cmd: String = "curl -s -f -X POST http://127.0.0.1:8021 --data-binary @'" + in_txt + "' -o '" + out_wav + "'"
		var p_out: Array = []
		var p_code: int = OS.execute("sh", ["-c", pocket_cmd], p_out, true)
		if p_code == 0 and FileAccess.file_exists("user://speech.wav") and FileAccess.get_file_as_bytes("user://speech.wav").size() > 100:
			return "user://speech.wav"
		print(">>> Сервер Pocket-TTS (8021) ещё загружается, использую Piper TTS...")
		
	var piper_dir: String = _resolve_ext_path("res://tts/piper")
	var piper_bin: String = piper_dir + "/piper"
	var voice_model: String = _resolve_ext_path("res://tts/voice.onnx")
	
	var cmd: String = (
		"LD_LIBRARY_PATH='" + piper_dir + "' '" + piper_bin + "' --model '" + voice_model + 
		"' --length_scale " + str(voice_speed) + 
		" --noise_scale 0.35 --noise_w 0.6 --output_file '" + out_wav + "' < '" + in_txt + "' 2>&1"
	)
	var output: Array = []
	var exit_code: int = OS.execute("sh", ["-c", cmd], output, true)
	if exit_code == 0 and FileAccess.file_exists("user://speech.wav"):
		return "user://speech.wav"
	return ""

func _on_text_submitted(_new_text: String) -> void:
	_on_send_pressed()

func _on_send_pressed() -> void:
	var user_text: String = message_input.text.strip_edges()
	if user_text == "" or is_busy_generating or ai_chat == null:
		return
		
	if not is_running_workflow:
		var triggered: bool = await _execute_workflow(user_text)
		if triggered:
			message_input.clear()
			return
			
	is_busy_generating = true
	chat_history.append_text("[color=skyblue][b]Ты:[/b][/color] " + user_text + "\n")
	message_input.clear()
	
	send_button.disabled = true
	message_input.editable = false
	chat_history.append_text("[color=lightgreen][b]Аватар:[/b][/color] ")
	
	var stream = ai_chat.ask(user_text)
	var full_reply: String = await stream.completed()
	var clean_reply: String = _extract_emotion_and_clean_text(full_reply)
	
	saved_messages.append({"role": "user", "text": user_text})
	saved_messages.append({"role": "assistant", "text": clean_reply})
	_save_memory()
	
	var wav_res_path: String = _generate_tts_wav(clean_reply)
	
	if wav_res_path != "":
		var global_wav: String = ProjectSettings.globalize_path(wav_res_path)
		var wav_stream := AudioStreamWAV.load_from_file(global_wav)
		if wav_stream != null:
			audio_player.stream = wav_stream
			audio_player.play()
			
			var duration: float = max(wav_stream.get_length(), 0.5)
			var char_delay: float = clamp(duration / float(max(clean_reply.length(), 1)), 0.02, 0.07)
			for letter in clean_reply:
				chat_history.append_text(letter)
				await get_tree().create_timer(char_delay).timeout
				
			while audio_player.playing:
				await get_tree().process_frame
	else:
		is_speaking = true
		for letter in clean_reply:
			_update_vowel_from_char(letter)
			chat_history.append_text(letter)
			await get_tree().create_timer(0.03).timeout
		is_speaking = false
	
	chat_history.append_text("\n\n")
	
	send_button.disabled = false
	message_input.editable = true
	is_busy_generating = false
	message_input.grab_focus()
