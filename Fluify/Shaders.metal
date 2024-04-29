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

kernel void calculate_divergence (texture2d<float, access::read> currentVelocities [[texture(0)]], texture2d<float, access::write> divergence [[texture(1)]], texture2d<float, access::write> pressure [[texture(2)]], uint2 grid_index [[thread_position_in_grid]]) {
    
    float size = currentVelocities.get_width();

    float h = 1.0f / size;

    uint2 curr = grid_index;
    uint2 left = uint2(curr.x - 1, curr.y);
    uint2 right = uint2(curr.x + 1, curr.y);
    uint2 down = uint2(curr.x, curr.y - 1);
    uint2 up = uint2(curr.x, curr.y + 1);
    float div = h * -0.5f *(currentVelocities.read(right).x - currentVelocities.read(left).x +  currentVelocities.read(up).y - currentVelocities.read(down).y);
    
    divergence.write(float4(div, 0.0, 0.0, 0.0), curr);
    pressure.write(float4(0.0, 0.0, 0.0, 0.0), grid_index);

}

kernel void divergence_diffusion (texture2d<float, access::read_write> pressure [[texture(0)]], texture2d<float, access::read> divergence [[texture(1)]],  uint2 grid_index [[thread_position_in_grid]]) {
    
    uint2 curr = grid_index;
    uint2 left = uint2(curr.x - 1, curr.y);
    uint2 right = uint2(curr.x + 1, curr.y);
    uint2 down = uint2(curr.x, curr.y - 1);
    uint2 up = uint2(curr.x, curr.y + 1);
    
   
    float pres = (divergence.read(curr).r + pressure.read(left).r + pressure.read(right).r + pressure.read(down).r + pressure.read(up).r)/4.0;
    
    pressure.write(float4(pres, 0.0, 0.0, 0.0),curr);
}


kernel void clear_divergence (texture2d<float, access::read_write> currentVelocities, texture2d<float, access::read_write> pressure [[texture(1)]], uint2 grid_index [[thread_position_in_grid]]) {
    float size = currentVelocities.get_width();

    float h = 1.0f / size;
    uint2 curr = grid_index;
    uint2 left = uint2(curr.x - 1, curr.y);
    uint2 right = uint2(curr.x + 1, curr.y);
    uint2 down = uint2(curr.x, curr.y - 1);
    uint2 up = uint2(curr.x, curr.y + 1);
    
    float4 curVel = currentVelocities.read(curr);
    float2 dif = float2(0.0, 0.0);
    dif.x = 0.5 * (pressure.read(right).x - pressure.read(left).x)/h;
    dif.y = 0.5 * (pressure.read(up).x - pressure.read(down).x)/h;

    float4 newVel = float4(curVel.x - dif.x, curVel.y - dif.y, 0.0, 0.0);
    currentVelocities.write(newVel, curr);
}

kernel void set_bnds(texture2d<float, access::read_write> grid [[texture(0)]],
                                 uint2 gid [[thread_position_in_grid]], device int* bv [[buffer(0)]]) {
    // Assuming 'size' is the dimension of the texture
    uint size = grid.get_width();
    uint N = size - 2;
    
    int b = bv[0];

    // Get the indices within the texture
    uint2 texCoord = gid + uint2(1, 1);

    // Set Wall Values to their nearest neighbour
    if (texCoord.x == 0 || texCoord.x == size - 1) {
        float4 neighborValue = b == 1 ? -grid.read(uint2(texCoord.x + (texCoord.x == 0 ? 1 : -1), texCoord.y)) :
                                       grid.read(uint2(texCoord.x + (texCoord.x == 0 ? 1 : -1), texCoord.y));
        grid.write(neighborValue, texCoord);
    }
    if (texCoord.y == 0 || texCoord.y == size - 1) {
        float4 neighborValue = b == 2 ? -grid.read(uint2(texCoord.x, texCoord.y + (texCoord.y == 0 ? 1 : -1))) :
                                       grid.read(uint2(texCoord.x, texCoord.y + (texCoord.y == 0 ? 1 : -1)));
        grid.write(neighborValue, texCoord);
    }

    // Synchronize threads to ensure all writes are complete
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Set Corners to the average of two nearby squares
    if (texCoord.x == 0 && texCoord.y == 0) {
        float4 cornerValue = 0.5f * (grid.read(uint2(1, 0)) + grid.read(uint2(0, 1)));
        grid.write(cornerValue, texCoord);
    }
    if (texCoord.x == 0 && texCoord.y == size - 1) {
        float4 cornerValue = 0.5f * (grid.read(uint2(1, size - 1)) + grid.read(uint2(0, size - 2)));
        grid.write(cornerValue, texCoord);
    }
    if (texCoord.x == size - 1 && texCoord.y == 0) {
        float4 cornerValue = 0.5f * (grid.read(uint2(size - 2, 0)) + grid.read(uint2(size - 1, 1)));
        grid.write(cornerValue, texCoord);
    }
    if (texCoord.x == size - 1 && texCoord.y == size - 1) {
        float4 cornerValue = 0.5f * (grid.read(uint2(size - 2, size - 1)) + grid.read(uint2(size - 1, size - 2)));
        grid.write(cornerValue, texCoord);
    }
}
