extends "../demo_base.gd"

func _process(_dt: float) -> void:

	if Input.get_mouse_button_mask() > 0:

		var mouse_scale := fluid_sim.resolution / get_rect().size
		var mouse_pos := Vector2i(get_local_mouse_position() * mouse_scale)
		_add_fluid_circle(mouse_pos, 20, Color.WHITE_SMOKE, _dt)

	super._process(_dt)
