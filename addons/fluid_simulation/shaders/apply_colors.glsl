#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D input_colors;
layout(rgba32f, set = 1, binding = 0) uniform restrict readonly image2D input_sources;
layout(rgba32f, set = 2, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	vec4 current_color = imageLoad(input_colors, uv);
    vec4 source_color = imageLoad(input_sources, uv);
	imageStore(output_data, uv, vec4(mix(current_color.rgb, source_color.rgb, source_color.a), 1));
}
