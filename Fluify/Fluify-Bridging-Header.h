//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//


#ifndef definitions_h
#define definitions_h

#include <simd/simd.h>

struct PencilInput {
    vector_float2 point;
    vector_float2 direction;
    float radius;
};

struct DiffusionProperties {
    float dt;
    float diffusionRate;
};

#endif /* definitions_h */
