//
//  FluidRenderer.swift
//  Fluify
//
//  Created by Ajay Venkat on 29/4/2024.
//

import Foundation
import MetalKit
import SwiftUI

class FluidRenderer {
    
    static var instance : FluidRenderer!

    let metalDevice : MTLDevice
    var output : MTLTexture?
    
    // Stages & Required Compute Shaders
    let pencilInputCompute : Compute
    
    let diffuseSolver : Compute
    var diffuseNewVelocitiesTexture : MTLTexture?
    
    let advectionSolver : Compute
    
    
    init (metalDevice : MTLDevice) {
        self.metalDevice = metalDevice
    
        // Setup Compute Stages
        diffuseSolver = Compute(kernel: "diffuse_kernel", metalDevice: metalDevice)
        
        pencilInputCompute = Compute(kernel: "input_kernel", metalDevice: metalDevice)
        
        advectionSolver = Compute(kernel: "advect_kernel", metalDevice: metalDevice)
        
        FluidRenderer.instance = self

    }
    
    func setOutputTexture (output : MTLTexture?) {
        self.output = output
        if (self.output != nil) {
            setupDiffusionComputeShader()
        }
    }
    
    func setupDiffusionComputeShader() {
        diffuseNewVelocitiesTexture = createTextureWithSamePropertiesAs(inputTexture: output!, device: metalDevice)
        diffuseSolver.setComputeTexture(name: "new_velocities", index: 1, value: diffuseNewVelocitiesTexture!)
    }
    
    var pencilInputs : [PencilInput] = []
    
    func addInput (screenPoint : SIMD2<Float>, direction : SIMD2<Float>, radius : Float) {
       
        pencilInputs.append( PencilInput(point: screenPoint, direction: direction/10.0, radius: radius) )
        
    }
    
    var previousTime = CACurrentMediaTime()
    
    func runCompute(commandBuffer : MTLCommandBuffer, view: MTKView) {
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - previousTime)
        previousTime = currentTime
        //
        
//        addInput(screenPoint: float2(0.5, 0.5), direction: float2(-1.0, -1.0), radius: 20)
        
        if (output != nil) {
            for pencilInput in pencilInputs {
//                print("Pressure : \(pencilInput.radius)")
//                print("Direction : \(pencilInput.direction.x), \(pencilInput.direction.y)")
//                print("Pos : \(pencilInput.point.x), \(pencilInput.point.y)")
                // Add Inputs
                pencilInputCompute.setComputeBuffer(name: "pencil_input", index: 0, value: pencilInput)
                
                
                // Output Texture to be Blitted After
                pencilInputCompute.run(inOutTexture: output!, commandBuffer: commandBuffer, view: view)
                
                
            }
            
            
            // ---- DIFFUSION ----
            
            // Diffusion Setup - Clear the new velocities texture
            clearTexture(texture: diffuseNewVelocitiesTexture!, clearColor: MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0), commandBuffer: commandBuffer, device: metalDevice)
            
            diffuseSolver.setComputeBuffer(name: "diffusion_properties", index: 0, value: DiffusionProperties(dt: deltaTime, diffusionRate: 0.0001))
            
            // Gauss-Seidel solver for diffusion of velocities
            for _ in 0...20 {
                diffuseSolver.run(inOutTexture: output!, commandBuffer: commandBuffer, view: view)
            }
            
            // Copy new velocities to output texture
            blitTexture(sourceTexture: diffuseNewVelocitiesTexture!, destinationTexture: output!, commandBuffer: commandBuffer, device: metalDevice)
            
            // --- CLEAR DIVERGENCE ---
            
            
            // --- ADVECTION ---
            advectionSolver.setComputeBuffer(name: "diffusion_properties", index: 0, value: DiffusionProperties(dt: deltaTime, diffusionRate: 0.0001))
            
            advectionSolver.run(inOutTexture: output!, commandBuffer: commandBuffer, view: view)
            
            // --- CLEAR DIVERGENCE ---
            
            
            
        }
        
        pencilInputs.removeAll()
        
    }
    
}

#Preview {
    ContentView()
}
