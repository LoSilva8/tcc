extends Node

const BG = Color(0.0, 0.0, 0.0, 0.08)
const PANEL = Color(0.09, 0.105, 0.13, 0.96)
const PANEL_ALT = Color(0.12, 0.135, 0.16, 0.98)
const STROKE = Color(0.32, 0.63, 0.72, 0.55)
const TEXT = Color(0.88, 0.94, 0.96)
const MUTED = Color(0.48, 0.58, 0.62)
const ACCENT = Color(0.27, 0.82, 0.7)
const WARNING = Color(1.0, 0.77, 0.28)
const DANGER = Color(0.95, 0.25, 0.32)

func _ready():
	call_deferred("_apply")

func _apply():
	var ui = get_parent().get_node_or_null("UI")
	if ui == null:
		return
	
	_add_screen_background(ui)
	_style_command_panel(ui.get_node_or_null("PanelContainer"))
	_style_tutorial(ui.get_node_or_null("TutorialBox"))

func _add_screen_background(ui: CanvasLayer):
	if ui.has_node("ScreenWash"):
		return
	
	var wash = ColorRect.new()
	wash.name = "ScreenWash"
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = BG
	wash.z_index = -100
	ui.add_child(wash)
	ui.move_child(wash, 0)

func _style_command_panel(panel: PanelContainer):
	if panel == null:
		return
	
	panel.custom_minimum_size = Vector2(0, 156)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, STROKE, 8))
	panel.add_theme_constant_override("margin_left", 18)
	panel.add_theme_constant_override("margin_right", 18)
	panel.add_theme_constant_override("margin_top", 14)
	panel.add_theme_constant_override("margin_bottom", 14)
	
	var input = panel.get_node_or_null("VBoxContainer/InputLine")
	if input:
		input.placeholder_text = "Digite um comando Python...  exemplo: mover('direita')"
		input.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.045, 0.06, 1), Color(0.24, 0.32, 0.38), 6))
		input.add_theme_stylebox_override("focus", _panel_style(Color(0.045, 0.06, 0.075, 1), ACCENT, 6))
		input.add_theme_color_override("font_color", TEXT)
		input.add_theme_color_override("font_placeholder_color", MUTED)
		input.add_theme_color_override("caret_color", ACCENT)
		input.add_theme_font_size_override("font_size", 18)
	
	var hp_icon = panel.get_node_or_null("VBoxContainer/HPContainer/HPIcon")
	if hp_icon:
		hp_icon.text = "HP"
		hp_icon.add_theme_color_override("font_color", DANGER)
		hp_icon.add_theme_font_size_override("font_size", 16)
	
	var hp_text = panel.get_node_or_null("VBoxContainer/HPContainer/HPTexto")
	if hp_text:
		hp_text.add_theme_color_override("font_color", TEXT)
		hp_text.add_theme_font_size_override("font_size", 15)
	
	var hp_bar = panel.get_node_or_null("VBoxContainer/HPContainer/HPBar")
	if hp_bar:
		hp_bar.custom_minimum_size = Vector2(0, 18)
		hp_bar.add_theme_stylebox_override("background", _panel_style(Color(0.16, 0.065, 0.085, 1), Color(0.34, 0.12, 0.15), 6))
		hp_bar.add_theme_stylebox_override("fill", _panel_style(DANGER, Color(1.0, 0.5, 0.55, 0.6), 6))
	
	var output = panel.get_node_or_null("VBoxContainer/ScrollContainer/OutputLabel")
	if output:
		output.add_theme_color_override("font_color", Color(0.72, 0.86, 0.84))
		output.add_theme_font_size_override("font_size", 15)
	
	var scroll = panel.get_node_or_null("VBoxContainer/ScrollContainer")
	if scroll:
		scroll.custom_minimum_size = Vector2(0, 72)

func _style_tutorial(panel: PanelContainer):
	if panel == null:
		return
	
	panel.custom_minimum_size = Vector2(390, 238)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, Color(0.68, 0.53, 0.24, 0.72), 8))
	panel.add_theme_constant_override("margin_left", 18)
	panel.add_theme_constant_override("margin_right", 18)
	panel.add_theme_constant_override("margin_top", 16)
	panel.add_theme_constant_override("margin_bottom", 16)
	
	var title = panel.get_node_or_null("VBoxContainer/TutorialTitulo")
	if title:
		title.text = "Tutorial"
		title.add_theme_color_override("font_color", WARNING)
		title.add_theme_font_size_override("font_size", 22)
	
	var text = panel.get_node_or_null("VBoxContainer/TutorialTexto")
	if text:
		text.add_theme_color_override("font_color", TEXT)
		text.add_theme_font_size_override("font_size", 16)
	
	var hint = panel.get_node_or_null("VBoxContainer/TutorialDica")
	if hint:
		hint.add_theme_color_override("font_color", ACCENT)
		hint.add_theme_font_size_override("font_size", 15)
	
	var command = panel.get_node_or_null("VBoxContainer/TutorialComando")
	if command:
		command.add_theme_color_override("font_color", WARNING)
		command.add_theme_font_size_override("font_size", 15)

func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
