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

float3 DirectionToRGB(float2 direction) {
    // Add an offset to ensure that all values are positive
    float offset = 1.0;
    float r = (direction.x + offset) / (2.0 * offset); // Map [-1, 1] to [0, 1]
    float g = (direction.y + offset) / (2.0 * offset); // Map [-1, 1] to [0, 1]
    
    // Set blue channel to a constant value
    float b = 0.5; // Constant value (adjust as needed)
    
    return float3(r, g, b);
}

// Pass in texture to be renderered
fragment float4 fragment_main(Fragment in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    float4 vel = texture.sample(sampler(), in.texCoord);
    float2 vel_l = float2(vel.x*10.0, vel.y*10.0);
    float3 col_ = DirectionToRGB(vel_l);
    return float4(col_*clamp(length(vel_l), 0.0, 1.0), 1.0);
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
   
        color_buffer.write(float4(direction.x , direction.y, 0.0, 0.0), grid_index);
    }
    
   
    
    
}

float4 lerp(float4 a, float4 b, float t) {
    return a * (1.0 - t) + b * t;
}

// Diffusion Kernel
kernel void diffuse_kernel (texture2d<float, access::read> currentVelocities [[texture(0)]], texture2d<float, access::read_write> newVelocities [[texture(1)]], uint2 grid_index [[thread_position_in_grid]],
    device DiffusionProperties* properties [[buffer(0)]]
    ) {
    
    int width = currentVelocities.get_width();
    float a = properties[0].dt * properties[0].diffusionRate *  float(width) * float(width);
    
    uint2 curr = grid_index;
    uint2 left = uint2(curr.x - 1, curr.y);
    uint2 right = uint2(curr.x + 1, curr.y);
    uint2 down = uint2(curr.x, curr.y - 1);
    uint2 up = uint2(curr.x, curr.y + 1);
    
    float4 newVal = (currentVelocities.read(curr) + a * (newVelocities.read(left) + newVelocities.read(right) + newVelocities.read(up) + newVelocities.read(down))/4) / (1+a);
    
    newVelocities.write(newVal, curr);
}


kernel void advect_kernel (texture2d<float, access::read_write> currentVelocities, uint2 grid_index [[thread_position_in_grid]], device DiffusionProperties* properties [[buffer(0)]]) {
    
    float dt = properties[0].dt;
    
    float size = currentVelocities.get_width();
    float dt0 = dt * float(size);
    
    uint2 curr = grid_index;

    
    float x = float(curr.x) - dt0 * currentVelocities.read(curr).x;
    float y = float(curr.y) - dt0 * currentVelocities.read(curr).y;
    
    if (x < 0.5f) x = 0.5f; if (y < 0.5f) y = 0.5f;
    if (x > size + 0.5f) x = size + 0.5f; if (y > size + 0.5f) y = size + 0.5f;
    
    // Neighbours of where the velocity backtrace ended
   int i0 = (int)x;
   int i1 = i0 + 1;
   int j0 = (int)y;
   int j1 = j0 + 1;

   // Finding fractionally how much of each of the neighbours to affect
   float s1 = x - i0;
   float s0 = 1 - s1;
   float t1 = y - j0;
   float t0 = 1 - t1;
    
    float4 veli0j0 = currentVelocities.read(uint2(i0, j0));
    float4 veli0j1 = currentVelocities.read(uint2(i0, j1));
    float4 veli1j0 = currentVelocities.read(uint2(i1, j0));
    float4 veli1j1 = currentVelocities.read(uint2(i1, j1));
    
    float4 leftV = s0 * (t0 * veli0j0 + t1 * veli0j1);
    float4 rightV = s1 * (t0 * veli1j0 + t1 * veli1j1);
    
    float4 finalVel = leftV + rightV;
    
    currentVelocities.write(finalVel, curr);
}
