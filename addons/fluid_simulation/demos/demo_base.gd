extends TextureRect

@export var fluid_sim: FluidSimulation2D

var mouse_velocity: Vector2i

func _ready() -> void:
	
	texture = Texture2DRD.new()
	fluid_sim.output_texture = texture

func _input(_event: InputEvent) -> void:

	if _event is InputEventMouseMotion:
		mouse_velocity = _event.screen_velocity
	
	elif _event is InputEventKey:
		if _event.is_pressed():
			if _event.keycode == Key.KEY_ESCAPE:
				get_tree().quit()
			elif _event.keycode == Key.KEY_F5:
				get_tree().reload_current_scene()

func _process(_dt: float) -> void:

	mouse_velocity = Vector2i.ZERO

func _fill_fluid_checkerboard(_block_size: int, _color_1: Color, _color_2: Color) -> void:
	
	for j in fluid_sim.resolution.y:
		var step_y := floori(j / _block_size)
		for i in fluid_sim.resolution.x:
			var step_x := floori(i / _block_size)
			if (step_x + step_y) % 2 == 0:
				fluid_sim.input_colors_img.set_pixel(i, j, _color_1)
			else:
				fluid_sim.input_colors_img.set_pixel(i, j, _color_2)

func _add_fluid_circle(_position: Vector2i, _radius: float, _color: Color, _dt: float) -> void:

	for i in range(_position.x - _radius, _position.x + _radius):
		if i >= 0 and i < fluid_sim.resolution.x:
			for j in range(_position.y - _radius, _position.y + _radius):
				if j >= 0 and j < fluid_sim.resolution.y:
					var ratio := 1.0 - clampf((_position - Vector2i(i, j)).length() / _radius, 0, 1)
					var velocity := mouse_velocity * _dt * ratio * 10
					var vel_color := Color(velocity.x, velocity.y, 0, 1)
					fluid_sim.input_forces_img.set_pixel(i, j, vel_color)
					fluid_sim.input_colors_img.set_pixel(i, j, _color * ratio)