class_name FluidSimulation2D
extends Node

@export var resolution := Vector2(640, 360)

var input_forces_img: Image
var input_colors_img: Image
var output_texture: Texture2DRD: set = _set_output_texture 

var device: RenderingDevice

class ComputePipeline:
	var name: String
	var shader_id: RID
	var pipeline_id: RID

var advect_pipeline: ComputePipeline
var jacobi_pipeline: ComputePipeline
var apply_forces_pipeline: ComputePipeline
var apply_colors_pipeline: ComputePipeline
var divergence_pipeline: ComputePipeline
var subtract_pipeline: ComputePipeline
var boundary_pipeline: ComputePipeline

var tex_id_velocity: RID 
var tex_id_pressure: RID 
var tex_id_color: RID 
var tex_id_divergence: RID 
var tex_id_input_forces: RID 
var tex_id_input_colors: RID 
var tex_id_temp: RID

var sampler: RID

var x_groups := 0
var y_groups := 0

func _ready() -> void:
	
	x_groups = int((resolution.x - 1) / 8 + 1)
	y_groups = int((resolution.y - 1) / 8 + 1)

	RenderingServer.call_on_render_thread(_initialize)
	input_forces_img = Image.create(int(resolution.x), int(resolution.y), false, Image.FORMAT_RGBAF);
	input_colors_img = Image.create(int(resolution.x), int(resolution.y), false, Image.FORMAT_RGBAF);

func _notification(_what: int) -> void:

	if _what == NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_terminate)

func _set_output_texture(_output: Texture2DRD) -> void:

	output_texture = _output
	output_texture.texture_rd_rid = tex_id_color

func _process(_dt: float) -> void:

	RenderingServer.call_on_render_thread(_render_process.bind(_dt))

func _initialize() -> void:

	device = RenderingServer.get_rendering_device()
	
	# Init shaders
	advect_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/advect.glsl")
	jacobi_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/jacobi.glsl")
	apply_forces_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/apply_forces.glsl")
	apply_colors_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/apply_colors.glsl")
	divergence_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/divergence.glsl")
	subtract_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/subtract.glsl")
	boundary_pipeline = _create_compute_pipeline("res://addons/fluid_simulation/shaders/boundary.glsl")

	# Init texture format
	var tex_format := RDTextureFormat.new()
	tex_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.width = int(resolution.x)
	tex_format.height = int(resolution.y)
	tex_format.mipmaps = 1
	tex_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)

	# Init textures
	tex_id_velocity = _create_texture(tex_format)
	tex_id_pressure = _create_texture(tex_format)
	tex_id_color = _create_texture(tex_format)
	tex_id_divergence = _create_texture(tex_format)
	tex_id_input_forces = _create_texture(tex_format)
	tex_id_input_colors = _create_texture(tex_format)
	tex_id_temp = _create_texture(tex_format)

	# Init sampler
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = device.sampler_create(sampler_state)

func _swap_tex_velocity() -> void:

	var tex_id_swap := tex_id_velocity
	tex_id_velocity = tex_id_temp
	tex_id_temp = tex_id_swap

func _swap_tex_pressure() -> void:

	var tex_id_swap := tex_id_pressure
	tex_id_pressure = tex_id_temp
	tex_id_temp = tex_id_swap

func _swap_tex_color() -> void:

	var tex_id_swap := tex_id_color
	tex_id_color = tex_id_temp
	tex_id_temp = tex_id_swap

func _terminate() -> void:

	if output_texture:
		output_texture.texture_rd_rid = RID()

	sampler = _free_rid(sampler)

	tex_id_velocity = _free_rid(tex_id_velocity)
	tex_id_pressure = _free_rid(tex_id_pressure)
	tex_id_color = _free_rid(tex_id_color)
	tex_id_divergence = _free_rid(tex_id_divergence)
	tex_id_input_forces = _free_rid(tex_id_input_forces)
	tex_id_input_colors = _free_rid(tex_id_input_colors)
	tex_id_temp = _free_rid(tex_id_temp)

	_free_pipeline(advect_pipeline)
	_free_pipeline(jacobi_pipeline)
	_free_pipeline(apply_forces_pipeline)
	_free_pipeline(apply_colors_pipeline)
	_free_pipeline(divergence_pipeline)
	_free_pipeline(subtract_pipeline)
	_free_pipeline(boundary_pipeline)

func _render_process(_dt: float) -> void:

	# Apply forces
	device.texture_update(tex_id_input_forces, 0, input_forces_img.get_data())
	_run_compute(apply_forces_pipeline, RID(), [tex_id_velocity, tex_id_input_forces, tex_id_temp], _to_bytes(16, [resolution]))
	_swap_tex_velocity()
	
	# Apply colors
	device.texture_update(tex_id_input_colors, 0, input_colors_img.get_data())
	_run_compute(apply_colors_pipeline, RID(), [tex_id_color, tex_id_input_colors, tex_id_temp], _to_bytes(16, [resolution]))
	_swap_tex_color()
	
	# Clear inputs
	_clear_sources()
	
	# Advect velocity
	var grid_scale := 1.0 # We have a 1:1 ratio for now
	var rdx := 1.0 / grid_scale 
	_run_compute(advect_pipeline, tex_id_velocity, [tex_id_velocity, tex_id_temp], _to_bytes(16, [resolution, _dt, rdx]))
	_swap_tex_velocity()

	# Diffusion
	var delta_x := 1.0 / grid_scale 
	var alpha := (delta_x * delta_x) / _dt
	var rbeta := 1.0 / (4.0 + alpha)
	var constants := _to_bytes(16, [resolution, alpha, rbeta])
	for i in 30:
		_run_compute(jacobi_pipeline, RID(), [tex_id_velocity, tex_id_velocity, tex_id_temp], constants)
		_swap_tex_velocity()

	# Projection 
	var half_rdx := rdx * 0.5
	_run_compute(divergence_pipeline, RID(), [tex_id_velocity, tex_id_divergence], _to_bytes(16, [resolution, half_rdx]))
	
	alpha = -(delta_x * delta_x)
	rbeta = 0.25
	constants = _to_bytes(16, [resolution, alpha, rbeta])
	for i in 60:
		_run_compute(jacobi_pipeline, RID(), [tex_id_pressure, tex_id_divergence, tex_id_temp], constants)
		_swap_tex_pressure()

	_run_compute(subtract_pipeline, RID(), [tex_id_pressure, tex_id_velocity, tex_id_temp], _to_bytes(16, [resolution, half_rdx]))
	_swap_tex_velocity()
	
	# Boundaries
	var bound_scale := -1.0
	_run_compute(boundary_pipeline, RID(), [tex_id_velocity, tex_id_temp], _to_bytes(16, [resolution, bound_scale]))
	_swap_tex_velocity()
	bound_scale = 1.0
	_run_compute(boundary_pipeline, RID(), [tex_id_pressure, tex_id_temp], _to_bytes(16, [resolution, bound_scale]))
	_swap_tex_pressure()

	# Advect color
	_run_compute(advect_pipeline, tex_id_color, [tex_id_velocity, tex_id_temp], _to_bytes(16, [resolution, _dt, rdx]))
	_swap_tex_color()
	
	# Update output
	if output_texture:
		output_texture.texture_rd_rid = tex_id_color

func _create_compute_pipeline(_shader_path: String) -> ComputePipeline:
	
	var shader_file := load(_shader_path) as RDShaderFile
	var shader_spirv := shader_file.get_spirv()
	var pipeline := ComputePipeline.new()
	pipeline.name = _shader_path.get_file().get_basename()
	pipeline.shader_id = device.shader_create_from_spirv(shader_spirv)
	pipeline.pipeline_id = device.compute_pipeline_create(pipeline.shader_id)
	return pipeline

func _create_texture(_format: RDTextureFormat) -> RID:

	var rid := device.texture_create(_format, RDTextureView.new(), [])
	device.texture_clear(rid, Color(0, 0, 0, 1), 0, 1, 0, 1)
	return rid

func _create_uniform_set(_pipeline: ComputePipeline, _texture_rd: RID, _uniform_set: int) -> RID:

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_texture_rd)

	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return device.uniform_set_create([uniform], _pipeline.shader_id, _uniform_set)

func _create_sampler_uniform_set(_pipeline: ComputePipeline, _texture_rd: RID, _uniform_set: int) -> RID:

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = 0
	uniform.add_id(sampler)
	uniform.add_id(_texture_rd)

	# Even though we're using 3 sets, they are identical, so we're kinda cheating.
	return device.uniform_set_create([uniform], _pipeline.shader_id, _uniform_set)
	
func _free_rid(_obj_rid: RID) -> RID:

	if _obj_rid.is_valid():
		device.free_rid(_obj_rid)

	return RID()

func _free_pipeline(_pipeline: ComputePipeline) -> void:
	
	if _pipeline.pipeline_id.is_valid():
		_pipeline.pipeline_id = _free_rid(_pipeline.pipeline_id)
		_pipeline.shader_id = _free_rid(_pipeline.shader_id)

func _clear_sources() -> void:
	
	input_forces_img.fill(Color.BLACK)
	input_colors_img.fill(Color.TRANSPARENT)

func _run_compute(_pipeline: ComputePipeline, _sampler_texture: RID, _image_textures: Array[RID], _push_constants: PackedByteArray) -> void:

	var samplers: Array[RID] = []
	var uniforms: Array[RID] = []
	
	# Setup sampler uniform
	if _sampler_texture.is_valid():
		uniforms.append(_create_sampler_uniform_set(_pipeline, _sampler_texture, uniforms.size()))

	# Setup texture uniforms
	for i in _image_textures.size():
		uniforms.append(_create_uniform_set(_pipeline, _image_textures[i], uniforms.size()))

	# Run compute shader
	var compute_list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, _pipeline.pipeline_id)
	for i in uniforms.size():
		device.compute_list_bind_uniform_set(compute_list, uniforms[i], i)
	device.compute_list_set_push_constant(compute_list, _push_constants, _push_constants.size())
	device.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	device.compute_list_end()

	# Free uniforms
	for uniform_id in uniforms:
		device.free_rid(uniform_id)

func _to_bytes(_size: int, _array: Array[Variant]) -> PackedByteArray:

	var output: PackedByteArray
	output.resize(_size)

	var offset := 0
	for element in _array:
		
		if element is float:
			output.encode_float(offset, element)
			offset += 4

		elif element is Vector2:
			output.encode_float(offset, element.x)
			offset += 4
			output.encode_float(offset, element.y)
			offset += 4
		
	return output
