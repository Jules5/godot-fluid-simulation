#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D input_data;
layout(rgba32f, set = 1, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
    float scale;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 offset = ivec2(0, 0);
    float scale = params.scale;

    if (uv.x < 1)
        offset.x = 1;
    else if (params.size.x - uv.x < 2)
        offset.x = -1;
    else if (uv.y < 1)
        offset.y = 1;
    else if (params.size.y - uv.y < 2)
        offset.y = -1;
    else
        scale = 1;

    vec2 result = scale * imageLoad(input_data, uv + offset).xy;
    imageStore(output_data, uv, vec4(result, 0, 1));
}
