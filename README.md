# Fluidify
This is an app showcasing a simple **Fluid Simulation Renderer** built using Metal for the iPad and Apple Pencil using the Navier Stokes equation based on this [paper](http://graphics.cs.cmu.edu/nsp/course/15-464/Fall09/papers/StamFluidforGames.pdf). The idea is to allow image deformation through fluid simulations similar to *Procreate's Liquify* tool.

## Technology
- SwiftUI and Swift for iPad
- Apple Pencil support for realtime drawing of velocity and color directly to a texture
- Rendering engine in Metal
- Realtime fluid simulation running on Compute Shaders 

## Final Result

https://github.com/AJTech2002/Fluidify/assets/25098044/a9b52989-c48c-47f9-8d6c-b4aa511a5c5f

## Fluid Simulation Steps

### Drawing in Velocity

Capture **Apple Pencil** inputs including tilt and pressure to get the input direction and pressure into a texture.

![vel-draw](https://github.com/AJTech2002/Fluidify/assets/25098044/62c1b648-7a45-4d53-b6d0-99b160144865)

### Diffusion
Diffuse the velocities the velocities over time.

https://github.com/AJTech2002/Fluidify/assets/25098044/6b478cf0-6e30-4458-b23c-d7e51fc8ab87

### Advect 
Advect the velocities and clear the divergence to ensure the fluid is incompressible.

https://github.com/AJTech2002/Fluidify/assets/25098044/8ec67e53-71e9-4250-9b95-00a6a712a3d3

### Advect & Modify a Texture 
Use the velocity field to move around a given texture in memory and insert new paint into texture.

https://github.com/AJTech2002/Fluidify/assets/25098044/cd4ed03b-6025-4d23-a35f-a74a82cdf8af
