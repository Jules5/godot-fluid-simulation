#[compute]
#version 450

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Our textures.
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D input_p;
layout(rgba32f, set = 1, binding = 0) uniform restrict readonly image2D input_w;
layout(rgba32f, set = 2, binding = 0) uniform restrict writeonly image2D output_data;

// Our push PushConstant.
layout(push_constant, std430) uniform Params {
    vec2 size;
    float halfRdx;
} params;

// The code we want to execute in each invocation.
void main() 
{
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    float pLeft = imageLoad(input_p, uv - ivec2(1, 0)).r;
    float pRight = imageLoad(input_p, uv + ivec2(1, 0)).r;
    float pDown = imageLoad(input_p, uv - ivec2(0, 1)).r;
    float pUp = imageLoad(input_p, uv + ivec2(0, 1)).r;
    
    vec4 uNew = imageLoad(input_w, uv);
    uNew.xy -= params.halfRdx * vec2(pRight - pLeft, pUp - pDown);
    imageStore(output_data, uv, uNew);
}
