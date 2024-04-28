//
//  Shader.metal
//  Fluify
//
//  Created by Ajay Venkat on 28/4/2024.
//

#include <metal_stdlib>
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
//    return texture.sample(sampler(), in.texCoord);
    return float4(1.0, 0.0, 0.0, 1.0);
}
