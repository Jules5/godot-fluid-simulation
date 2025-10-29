extends "../demo_base.gd"

var mouse_color: Color

func _ready() -> void:
	
	super._ready()

	_fill_fluid_checkerboard(
		int(fluid_sim.resolution.x / 10),
		Color(randf(), randf(), randf(), 1),
		Color(randf(), randf(), randf(), 1))

func _input(_event: InputEvent) -> void:

	super._input(_event)

	if _event is InputEventMouseButton:
		mouse_color = Color(randf(), randf(), randf(), 1)

func _process(_dt: float) -> void:

	if Input.get_mouse_button_mask() > 0:

		var mouse_scale := fluid_sim.resolution / get_rect().size
		var mouse_pos := Vector2i(get_local_mouse_position() * mouse_scale)
		_add_fluid_circle(mouse_pos, 20, mouse_color, _dt)

	super._process(_dt)
