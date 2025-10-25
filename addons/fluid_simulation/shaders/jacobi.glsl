#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D input_x;
layout(rgba32f, set = 1, binding = 0) uniform restrict readonly image2D input_b;
layout(rgba32f, set = 2, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
    float alpha;
    float rbeta;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    // left, right, bottom, and top x samples
    vec2 xLeft = imageLoad(input_x, uv - ivec2(1, 0)).xy;
    vec2 xRight = imageLoad(input_x, uv + ivec2(1, 0)).xy;
    vec2 xDown = imageLoad(input_x, uv - ivec2(0, 1)).xy;
    vec2 xUp = imageLoad(input_x, uv + ivec2(0, 1)).xy;

    // b sample, from center
    vec2 bCenter = imageLoad(input_b, uv).xy; // TODO: not the right image

    // evaluate Jacobi iteration
    vec2 result = (xLeft + xRight + xDown + xUp + params.alpha * bCenter) * params.rbeta;

    imageStore(output_data, uv, vec4(result, 0.0, 1.0));
}
