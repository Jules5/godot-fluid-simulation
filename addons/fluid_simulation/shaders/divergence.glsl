#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D input_w;
layout(rgba32f, set = 1, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
    float halfRdx;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 wLeft = imageLoad(input_w, uv - ivec2(1, 0)).xy;
    vec2 wRight = imageLoad(input_w, uv + ivec2(1, 0)).xy;
    vec2 wDown = imageLoad(input_w, uv - ivec2(0, 1)).xy;
    vec2 wUp = imageLoad(input_w, uv + ivec2(0, 1)).xy;

    float result = params.halfRdx * ((wRight.x - wLeft.x) + (wUp.y - wDown.y));
    imageStore(output_data, uv, vec4(result, 0, 0, 1));
}
