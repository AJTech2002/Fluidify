//
//  Shader.metal
//  Fluify
//
//  Created by Ajay Venkat on 28/4/2024.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "Fluify-Bridging-Header.h"
using namespace metal;

struct Fragment {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};


// Draw simple rectangle to screen
vertex Fragment vertex_main(uint vertexID [[vertex_id]],
                             constant float2* vertexArray [[buffer(0)]],
                             constant float2* texcoordArray [[buffer(1)]]) {
    Fragment out;
    out.position = float4(vertexArray[vertexID], 0.0, 1.0);
    out.texCoord = texcoordArray[vertexID];
    return out;
}

// Pass in texture to be renderered
fragment float4 fragment_main(Fragment in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    return texture.sample(sampler(), in.texCoord);
//    return float4(1.0, 0.0, 0.0, 1.0);
}

// Input Kernel (Pencil drawing)
kernel void input_kernel (texture2d<float, access::write> color_buffer [[texture(0)]], uint2 grid_index [[thread_position_in_grid]], device PencilInput* pencil_input [[buffer(0)]]) {
    
    
    if (pencil_input[0].radius < 0.1) return;
    
    float width = color_buffer.get_width();
    float height = color_buffer.get_height();
    
    float2 g_index = float2(grid_index.x, grid_index.y);
    float2 middle = float2(pencil_input[0].point.x * width, pencil_input[0].point.y * height);
    float pixelRadius = pencil_input[0].radius;
    
    
    if (distance(g_index, middle) < pixelRadius) {
        
        float2 direction = pencil_input[0].direction;
        float red = (direction.x + 1) / 2; // Map x component to red channel
        float green = (direction.y + 1) / 2; // Map y component to green
        
        color_buffer.write(float4(red, green, 0.0, 1.0), grid_index);
    }
    
   
    
    
}

// Diffusion Kernel
kernel void diffuse_kernel (texture2d<float, access::write> color_buffer [[texture(0)]], uint2 grid_index [[thread_position_in_grid]]) {
    
//    float4 col = float4(0.0, 1.0, 0.0, 1.0);
//    color_buffer.write(col, grid_index);
    
}
