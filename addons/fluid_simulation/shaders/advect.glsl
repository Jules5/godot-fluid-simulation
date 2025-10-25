#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(set = 0, binding = 0) uniform sampler2D input_advected;
layout(rgba32f, set = 1, binding = 0) uniform restrict readonly image2D input_velocity;
layout(rgba32f, set = 2, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
    float dt;
    float rdx;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 velocity = imageLoad(input_velocity, uv).xy;
    vec2 source_pos = uv - (params.dt * params.rdx * velocity);
    vec4 source_data = texture(input_advected, (source_pos + 0.5) / (params.size));
    imageStore(output_data, uv, source_data);
}
