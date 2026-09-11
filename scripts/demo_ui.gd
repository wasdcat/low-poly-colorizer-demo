extends Control

## The demo's side panel and everything drawn over the 3D view: move count,
## success, the help and about windows, the studio link. It only wires
## controls to CubeLooks (everything LPC) and PuzzleCube (the puzzle) --
## cube_looks.gd is the file worth reading. The texts are English message ids,
## see translations.gd.

const Translations := preload("res://scripts/translations.gd")

const ACCENT := Color(1.0, 0.8, 0.4)
const TEXT := Color(1.0, 1.0, 1.0, 0.86)
const DIM := Color(1.0, 1.0, 1.0, 0.62)
## Seconds the success message stays up before it fades.
const SUCCESS_TIME := 3.0
## Both logos are imported with mipmaps: they are shown far smaller than they are.
const LPC_LOGO: Texture2D = preload("res://assets/logos/lpc_logo_small.png")
const STUDIO_LOGO: Texture2D = preload("res://assets/logos/wasdcat_logo.svg")
const STUDIO_URL := "https://www.wasdcat.com/"
const LPC_URL := "https://github.com/wasdcat/low-poly-colorizer"
const GAME_URL := "https://github.com/wasdcat/low-poly-colorizer-demo"
## The help window's rows: the keys of an input, and what it does.
const CONTROLS := [
	[["Wheel"], "Turn the column under the cursor"],
	[["Shift", "Wheel"], "Turn the row under the cursor"],
	[["Alt", "Wheel"], "Turn the face under the cursor"],
	[["Middle mouse button", "Drag"], "Orbit the view"],
	[["Ctrl", "Wheel"], "Zoom"],
	[["Ctrl", "Z"], "Undo the last turn"],
	[["Esc"], "Close window · quit the game"],
]
## The about window's facts on how the game is made. No renderer named: a web
## export runs on another one.
const GAME_FACTS := [
	"Made with Godot 4.8 and Low Poly Colorizer's export for Godot 4. The cube is built at runtime from just two meshes – body and sticker – in any size from 2 to 7.",
	"Bodies and stickers are colored with the lpc_singlecolor material, which LPC ships with its export from Blender.",
	"One look per mesh: a whole mesh – or a single surface of it – gets one color from the LPC palette and one LPC preset. That's why every sticker here is a node of its own.",
	"What it's good for: consistency. lpc_singlecolor uses the same palette and presets as lpc_multicolor – so all your own assets are colored from one shared palette, whichever of the two materials they use.",
]

@export var cube: PuzzleCube
@export var looks: CubeLooks
## main.gd, for its camera rig, which is told where the free part of the screen is.
@export var controller: Node

var _panel: PanelContainer
var _moves: Control
var _moves_count: Label
var _success: Control
var _success_moves: Label
var _success_tween: Tween
var _help: Dialog
var _about: Dialog
## The top bar's window buttons. At most one is pressed, so at most one window is open.
var _dialog_buttons := ButtonGroup.new()


## A window over the view. Its dimmed backdrop keeps the mouse off the cube.
## It is open while its [member button] in the top bar is pressed -- that
## button is its only switch: to close the window, release the button.
class Dialog:
	var backdrop: Control
	var content: VBoxContainer
	var button: Button
	var tween: Tween


func _ready() -> void:
	Translations.install()
	TranslationServer.set_locale(Translations.current())
	# Stacked in this order: the overlays of the view, the windows over them,
	# the panel on top -- it stays usable while a window is open.
	_build_moves()
	_build_success()
	_build_studio_link()
	_help = _build_dialog("Controls", 480.0)
	_fill_help(_help.content)
	_about = _build_dialog("About", 700.0)
	_fill_about(_about.content)
	var box := _build_panel()
	_top_bar(box)
	_title_section(box)
	_puzzle_section(box)
	_looks_section(box)

	cube.game_changed.connect(_on_game_changed)
	cube.solved.connect(_on_solved)
	_panel.item_rect_changed.connect(_update_view_area)
	_update_view_area.call_deferred()  # once the panel has its final place
	_on_game_changed()


## Esc closes the open window, or else quits.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	var open := _dialog_buttons.get_pressed_button()
	if open:
		open.button_pressed = false
	elif not OS.has_feature("web"):  # a browser tab has nothing to quit to
		get_tree().quit()


## Above the title, set off in a box of its own: the languages, help and about.
func _top_bar(box: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(5)
	bar.add_theme_stylebox_override(&"panel", style)
	box.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	bar.add_child(row)
	var languages := ButtonGroup.new()
	for language in Translations.LANGUAGES:
		_flag_button(row, language).button_group = languages
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_dialog_buttons.allow_unpress = true
	_dialog_button(row, "?", "Help", _help)
	_dialog_button(row, "!", "About", _about)


## One language: its flag, pressed while it is the one showing.
func _flag_button(row: HBoxContainer, language: Dictionary) -> Button:
	var button := Button.new()
	button.icon = language.flag
	button.tooltip_text = language.name
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # a language's name is its own
	button.toggle_mode = true
	button.button_pressed = language.code == Translations.current()
	button.pressed.connect(TranslationServer.set_locale.bind(language.code))
	button.add_theme_constant_override(&"icon_max_width", 24)
	var chosen := _button_box(Color(1.0, 1.0, 1.0, 0.1))
	chosen.border_color = ACCENT
	chosen.set_border_width_all(1)
	button.add_theme_stylebox_override(&"normal", _button_box(Color.TRANSPARENT))
	button.add_theme_stylebox_override(&"hover", _button_box(Color(1.0, 1.0, 1.0, 0.06)))
	button.add_theme_stylebox_override(&"pressed", chosen)
	button.add_theme_stylebox_override(&"hover_pressed", chosen)
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.add_theme_color_override(&"icon_normal_color", Color(1.0, 1.0, 1.0, 0.5))
	button.add_theme_color_override(&"icon_hover_color", Color.WHITE)
	button.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	button.add_theme_color_override(&"icon_hover_pressed_color", Color.WHITE)
	row.add_child(button)
	return button


## A round button that opens [param dialog] and stays pressed while it is open.
func _dialog_button(row: HBoxContainer, text: String, tooltip: String, dialog: Dialog) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.button_group = _dialog_buttons
	button.custom_minimum_size = Vector2(26.0, 26.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip := _button_box(Color(1.0, 1.0, 1.0, 0.08))
	chip.set_corner_radius_all(13)
	chip.border_color = Color(1.0, 1.0, 1.0, 0.22)
	chip.set_border_width_all(1)
	var hover := chip.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.16)
	var open := hover.duplicate() as StyleBoxFlat
	open.border_color = ACCENT
	button.add_theme_stylebox_override(&"normal", chip)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", open)
	button.add_theme_stylebox_override(&"hover_pressed", open)
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.add_theme_color_override(&"font_pressed_color", ACCENT)
	button.add_theme_color_override(&"font_hover_pressed_color", ACCENT)
	# Fires as well when the group releases it because the other window opens.
	button.toggled.connect(_show_dialog.bind(dialog))
	row.add_child(button)
	dialog.button = button


func _title_section(box: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	box.add_child(header)
	var logo := TextureRect.new()
	logo.texture = LPC_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.custom_minimum_size = Vector2(56.0, 56.0)
	header.add_child(logo)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override(&"separation", -2)
	header.add_child(titles)
	var title := Label.new()
	title.text = "Low Poly Colorizer"
	title.add_theme_font_size_override(&"font_size", 22)
	titles.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Demo Game"
	subtitle.add_theme_color_override(&"font_color", ACCENT)
	subtitle.add_theme_font_size_override(&"font_size", 15)
	titles.add_child(subtitle)


func _puzzle_section(box: VBoxContainer) -> void:
	_heading(box, "Puzzle")
	_slider(box, "Size", PuzzleCube.MIN_SIZE, PuzzleCube.MAX_SIZE, 1, cube.size, _format_size,
			func(value: float) -> void: cube.size = int(value))
	_slider(box, "Gap", 0.0, 0.6, 0.01, cube.gap, _format_float,
			func(value: float) -> void: cube.gap = value)
	var play := _button(box, "Scramble to Play", func() -> void: cube.scramble())
	play.custom_minimum_size.y = 38.0
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, "Undo", cube.undo)
	_button(row, "Reset", cube.reset)


func _looks_section(box: VBoxContainer) -> void:
	_heading(box, "Material/Colors")
	var scheme_names: Array[String] = []
	for scheme in looks.schemes:
		scheme_names.append(scheme.resource_name)
	scheme_names.append("Random")
	_option(_row(box, "Stickers"), scheme_names, _on_scheme_selected)

	var body_names: Array[String] = []
	for look in looks.body_looks:
		body_names.append(look.resource_name)
	_option(_row(box, "Body"), body_names,
			func(index: int) -> void: looks.body_look = looks.body_looks[index])


func _on_scheme_selected(index: int) -> void:
	looks.scheme = looks.schemes[index] if index < looks.schemes.size() else looks.random_scheme()


func _on_game_changed() -> void:
	_moves.visible = cube.is_playing()
	_moves_count.text = str(cube.moves)
	if cube.is_playing() and _success_tween:  # a new game clears the last success
		_success_tween.kill()
		_success.modulate.a = 0.0


func _on_solved() -> void:
	_success_moves.text = (tr("in %d move") if cube.moves == 1 else tr("in %d moves")) % cube.moves
	if _success_tween:
		_success_tween.kill()
	_success.modulate.a = 0.0
	_success.scale = Vector2(0.6, 0.6)
	_success_tween = create_tween()
	_success_tween.tween_property(_success, ^"modulate:a", 1.0, 0.2)
	_success_tween.parallel().tween_property(_success, ^"scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_success_tween.tween_interval(SUCCESS_TIME)
	_success_tween.tween_property(_success, ^"modulate:a", 0.0, 1.0)


## Fades [param dialog] in or out -- connected to its button, see [Dialog].
func _show_dialog(on: bool, dialog: Dialog) -> void:
	if dialog.tween:
		dialog.tween.kill()
	dialog.backdrop.show()
	dialog.tween = create_tween()
	dialog.tween.tween_property(dialog.backdrop, ^"modulate:a", 1.0 if on else 0.0, 0.15)
	if not on:
		dialog.tween.tween_callback(dialog.backdrop.hide)


## Centers the cube in the part of the screen the panel leaves free, instead of
## in the middle of the window.
func _update_view_area() -> void:
	var screen := get_viewport().get_visible_rect().size
	var free_width := _panel.get_global_rect().position.x
	controller.rig.view_area = Rect2(0.0, 0.0, clampf(free_width / screen.x, 0.25, 1.0), 1.0)


func _build_panel() -> VBoxContainer:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.075, 0.9)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -344.0
	_panel.offset_right = -14.0
	_panel.offset_top = 14.0
	_panel.offset_bottom = -14.0
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	# Keeps the content clear of the scroll bar -- only while there is one, or
	# the right margin would look wider than the left.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var bar := scroll.get_v_scroll_bar()
	bar.visibility_changed.connect(func() -> void:
			margin.add_theme_constant_override(&"margin_right", 12 if bar.visible else 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	margin.add_child(box)
	return box


## Top left, while a game is on: the turns made since the scramble.
func _build_moves() -> void:
	_moves = VBoxContainer.new()
	_moves.position = Vector2(24.0, 16.0)
	_moves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moves.add_theme_constant_override(&"separation", -6)
	add_child(_moves)
	_overlay_label(_moves, "Moves", 14, ACCENT).uppercase = true
	_moves_count = _overlay_label(_moves, "0", 44, Color.WHITE)


## Over the view once the cube is solved. Never hidden, only faded out, so its
## size -- the pivot of its pop-in -- is always up to date.
func _build_success() -> void:
	_success = VBoxContainer.new()
	_success.anchor_right = 1.0
	_success.offset_top = 16.0
	_success.offset_right = -358.0  # centered over the view, not under the panel
	_success.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_success.modulate.a = 0.0
	_success.resized.connect(func() -> void: _success.pivot_offset = _success.size * 0.5)
	add_child(_success)
	_overlay_label(_success, "Solved!", 56, ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_moves = _overlay_label(_success, "", 22, Color.WHITE)
	_success_moves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_moves.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # see _on_solved()


## Bottom left: the studio's logo, linking to its site.
func _build_studio_link() -> void:
	var link := TextureButton.new()
	link.texture_normal = STUDIO_LOGO
	link.ignore_texture_size = true
	link.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	link.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	link.anchor_top = 1.0
	link.anchor_bottom = 1.0
	link.offset_left = 16.0
	link.offset_top = -112.0
	link.offset_right = 112.0
	link.offset_bottom = -16.0
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.tooltip_text = "www.wasdcat.com"
	link.pressed.connect(func() -> void: OS.shell_open(STUDIO_URL))
	add_child(link)


## A hidden window of [param width], centered over the view, with a title and a
## close button. The caller fills its [member Dialog.content].
func _build_dialog(title: String, width: float) -> Dialog:
	var dialog := Dialog.new()
	var close := func() -> void: dialog.button.button_pressed = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.modulate.a = 0.0
	backdrop.hide()
	var on_backdrop := func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close.call()
	backdrop.gui_input.connect(on_backdrop)
	add_child(backdrop)
	dialog.backdrop = backdrop
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_right = -358.0  # centered over the view, not under the panel
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	var window := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.97)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 16
	window.add_theme_stylebox_override(&"panel", style)
	window.custom_minimum_size.x = width
	window.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks inside must not reach the backdrop
	center.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	window.add_child(box)
	dialog.content = box

	var top := HBoxContainer.new()
	box.add_child(top)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override(&"font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.tooltip_text = "Close"
	x.add_theme_font_size_override(&"font_size", 26)
	x.pressed.connect(close)
	top.add_child(x)
	return dialog


## Every input and what it does.
func _fill_help(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 10)
	box.add_child(grid)
	var cap := _button_box(Color(1.0, 1.0, 1.0, 0.1))
	cap.border_color = Color(1.0, 1.0, 1.0, 0.25)
	cap.set_border_width_all(1)
	cap.border_width_bottom = 2
	var bold := FontVariation.new()
	bold.base_font = get_theme_default_font()
	bold.variation_embolden = 0.8
	for entry in CONTROLS:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override(&"separation", 6)
		grid.add_child(keys)
		for key: String in entry[0]:
			if keys.get_child_count() > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.add_theme_color_override(&"font_color", DIM)
				keys.add_child(plus)
			var keycap := PanelContainer.new()
			keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			keycap.add_theme_stylebox_override(&"panel", cap)
			keys.add_child(keycap)
			var label := Label.new()
			label.text = key
			label.add_theme_font_override(&"font", bold)
			label.add_theme_font_size_override(&"font_size", 13)
			keycap.add_child(label)
		var action := Label.new()
		action.text = entry[1]
		action.add_theme_font_size_override(&"font_size", 15)
		grid.add_child(action)

	box.add_child(HSeparator.new())
	_note(box, "The white outline marks the layer the wheel turns next.")
	_note(box, "“Scramble to Play” starts a game: solve the cube in as few moves as you can.")


## What LPC is, and how this game is made -- each with its repository.
func _fill_about(box: VBoxContainer) -> void:
	_heading(box, "What is Low Poly Colorizer?")
	_paragraph(box, "Low Poly Colorizer (LPC) is a Blender extension for painting low-poly models face by face – with colors from one palette texture and PBR presets. All painted faces share a single material, and one click exports materials and shaders to Godot 4.")
	_link(box, "Low Poly Colorizer on GitHub ›", LPC_URL)

	_heading(box, "About this game")
	for fact: String in GAME_FACTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		box.add_child(row)
		var dot := Label.new()
		dot.text = "•"
		dot.add_theme_color_override(&"font_color", ACCENT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		_paragraph(row, fact).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_link(box, "Source code of this game on GitHub ›", GAME_URL)


func _heading(box: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6.0
	box.add_child(spacer)
	var label := Label.new()
	label.text = text
	label.uppercase = true  # after translating, unlike text.to_upper()
	label.add_theme_color_override(&"font_color", ACCENT)
	label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(label)


func _note(box: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", DIM)
	label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(label)
	return label


## Body text of a window.
func _paragraph(box: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", TEXT)
	label.add_theme_font_size_override(&"font_size", 14)
	box.add_child(label)
	return label


## Opens [param url] in the browser; only its text is clickable.
func _link(box: Container, text: String, url: String) -> LinkButton:
	var link := LinkButton.new()
	link.text = text
	link.tooltip_text = url
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	link.add_theme_font_size_override(&"font_size", 14)
	link.add_theme_color_override(&"font_color", ACCENT)
	link.add_theme_color_override(&"font_hover_color", ACCENT.lightened(0.4))
	link.add_theme_color_override(&"font_pressed_color", ACCENT.lightened(0.4))
	link.pressed.connect(OS.shell_open.bind(url))
	box.add_child(link)
	return link


## Text drawn straight over the 3D view, outlined so it reads on any backdrop.
func _overlay_label(box: Container, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", roundi(font_size * 0.2))
	box.add_child(label)
	return label


## A row that starts with [param title], lined up with the other rows' titles.
func _row(box: Container, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 76.0
	row.add_child(label)
	return row


func _option(box: Container, items: Array[String], on_select: Callable) -> OptionButton:
	var menu := OptionButton.new()
	for item in items:
		menu.add_item(item)
	# A long item ("Showroom (mixed presets)") must not widen the whole panel.
	menu.fit_to_longest_item = false
	menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.item_selected.connect(on_select)
	box.add_child(menu)
	return menu


func _button(box: Container, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_press)
	box.add_child(button)
	return button


func _slider(box: Container, title: String, from: float, to: float, step: float, value: float,
		format: Callable, on_change: Callable) -> HSlider:
	var row := _row(box, title)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 64.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = format.call(value)
	row.add_child(readout)
	var changed := func(new_value: float) -> void:
		readout.text = format.call(new_value)
		on_change.call(new_value)
	slider.value_changed.connect(changed)
	return slider


## A rounded box for small buttons and keycaps.
static func _button_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


static func _format_float(value: float) -> String:
	return "%.2f" % value


static func _format_size(value: float) -> String:
	return "%d × %d × %d" % [value, value, value]
