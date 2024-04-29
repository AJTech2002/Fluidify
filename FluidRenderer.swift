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
    var velocityTexture : MTLTexture?
    
    // Stages & Required Compute Shaders
    let pencilInputCompute : Compute
    
    let diffuseSolver : Compute
    var diffuseNewVelocitiesTexture : MTLTexture?
    
    let advectionSolver : Compute
    
    let calculatDivergenceSolver : Compute
    var divergenceTexture : MTLTexture?
    var pressureTexture : MTLTexture?
    let divergenceDiffusionSolver : Compute;
    let clearDivergenceSolver : Compute
    
    let boundsSolver : Compute
    
    let initialImage : Compute
    
    init (metalDevice : MTLDevice) {
        self.metalDevice = metalDevice
    
        // Setup Compute Stages
        diffuseSolver = Compute(kernel: "diffuse_kernel", metalDevice: metalDevice)
        
        pencilInputCompute = Compute(kernel: "input_kernel", metalDevice: metalDevice)
        
        advectionSolver = Compute(kernel: "advect_kernel", metalDevice: metalDevice)
        
        calculatDivergenceSolver = Compute(kernel: "calculate_divergence", metalDevice: metalDevice)
        
        divergenceDiffusionSolver = Compute(kernel: "divergence_diffusion", metalDevice: metalDevice)
        
        clearDivergenceSolver = Compute (kernel: "clear_divergence", metalDevice: metalDevice)
        
        boundsSolver = Compute(kernel: "set_bnds", metalDevice: metalDevice)
        
        initialImage = Compute(kernel: "load_image", metalDevice: metalDevice)
        
        FluidRenderer.instance = self

        
    }
    
    var output: MTLTexture?
    
    var firstFrame : Bool = true
    
    func setOutputTexture (output : MTLTexture?) {
        self.output = output
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                                         width: output!.width,
                                                                         height: output!.height,
                                                                         mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead, .renderTarget]
    
        
        self.velocityTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
        
        
        if (self.velocityTexture != nil) {
            setupComputeShaders()
        }
    }
    
    func setupComputeShaders() {
        diffuseNewVelocitiesTexture = createTextureWithSamePropertiesAs(inputTexture: velocityTexture!, device: metalDevice)
        diffuseSolver.setComputeTexture(name: "new_velocities", index: 1, value: diffuseNewVelocitiesTexture!)
        
        divergenceTexture = createTextureWithSamePropertiesAs(inputTexture: velocityTexture!, device: metalDevice)
        pressureTexture = createTextureWithSamePropertiesAs(inputTexture: velocityTexture!, device: metalDevice)
        
        calculatDivergenceSolver.setComputeTexture(name: "divergence", index: 1, value: divergenceTexture!)
        
        calculatDivergenceSolver.setComputeTexture(name: "pressure", index: 2, value: pressureTexture!)
        
        divergenceDiffusionSolver.setComputeTexture(name: "divergence", index: 1, value: divergenceTexture!)
        
        clearDivergenceSolver.setComputeTexture(name: "pressure", index: 1, value: pressureTexture!)
        
    }
    
    var pencilInputs : [PencilInput] = []
    
    func addInput (screenPoint : SIMD2<Float>, direction : SIMD2<Float>, radius : Float) {
       
        pencilInputs.append( PencilInput(point: screenPoint, direction: direction/5.0, radius: radius*2.0) )
        
    }
    
    func set_bnds (texture : MTLTexture, b : Int, commandBuffer: MTLCommandBuffer, view : MTKView) {
        
        boundsSolver.setComputeBuffer(name: "bv", index: 0, value: b)
        boundsSolver.run(inOutTexture: texture, commandBuffer: commandBuffer, view: view)
        
    }
    
    var previousTime = CACurrentMediaTime()
    
    func clearDivergence (commandBuffer: MTLCommandBuffer, view : MTKView) {
        
        calculatDivergenceSolver.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
        
        set_bnds(texture: divergenceTexture!, b: 0, commandBuffer: commandBuffer, view: view)
        set_bnds(texture: pressureTexture!, b: 0, commandBuffer: commandBuffer, view: view)
        
        for _ in 0...20 {
            divergenceDiffusionSolver.run(inOutTexture: pressureTexture!, commandBuffer: commandBuffer, view: view)
            set_bnds(texture: pressureTexture!, b: 0, commandBuffer: commandBuffer, view: view)
        }
        
        clearDivergenceSolver.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
        set_bnds(texture: velocityTexture!, b:1, commandBuffer: commandBuffer, view: view)
        set_bnds(texture: velocityTexture!, b: 2, commandBuffer: commandBuffer, view: view)
    }
    
    func runCompute(commandBuffer : MTLCommandBuffer, view: MTKView) {
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - previousTime)
        previousTime = currentTime
        
        if (firstFrame) {

            loadTexture(named: "procreate-logo", into: output!, device: metalDevice)
            
            firstFrame = false
        }
        
        
//        addInput(screenPoint: float2(0.5, 0.5), direction: float2(-1.0, -1.0), radius: 20)
     
        
        if (velocityTexture != nil) {
            for pencilInput in pencilInputs {

                pencilInputCompute.setComputeBuffer(name: "pencil_input", index: 0, value: pencilInput)
                
                pencilInputCompute.setComputeTexture(name: "output", index: 1, value: output!)
                
                // Output Texture to be Blitted After
                pencilInputCompute.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
                
                
            }
            
            
            // ---- DIFFUSION ----
            
            
            diffuseSolver.setComputeBuffer(name: "diffusion_properties", index: 0, value: DiffusionProperties(dt: deltaTime, diffusionRate: 0.0001))
           
            clearTexture(texture: diffuseNewVelocitiesTexture!, clearColor: MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0), commandBuffer: commandBuffer, device: metalDevice)
            
            // Gauss-Seidel solver for diffusion of velocities
            for _ in 0...20 {
                diffuseSolver.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
            }
            
            
            
            // Copy new velocities to output texture
            blitTexture(sourceTexture: diffuseNewVelocitiesTexture!, destinationTexture: velocityTexture!, commandBuffer: commandBuffer, device: metalDevice)
            
            set_bnds(texture: velocityTexture!, b: 1, commandBuffer: commandBuffer, view: view)
            set_bnds(texture: velocityTexture!, b: 2, commandBuffer: commandBuffer, view: view)
            
            // --- CLEAR DIVERGENCE ---
            clearDivergence(commandBuffer: commandBuffer, view: view)
            
            // --- ADVECTION ---
            advectionSolver.setComputeBuffer(name: "diffusion_properties", index: 0, value: DiffusionProperties(dt: deltaTime, diffusionRate: 0.0001))
            

            advectionSolver.setComputeTexture(name: "advectTexture", index: 1, value: output!)
            advectionSolver.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
            set_bnds(texture: output!, b: 1, commandBuffer: commandBuffer, view: view)
            set_bnds(texture: output!, b: 2, commandBuffer: commandBuffer, view: view)

            
            advectionSolver.setComputeTexture(name: "advectTexture", index: 1, value: velocityTexture!)
            advectionSolver.run(inOutTexture: velocityTexture!, commandBuffer: commandBuffer, view: view)
            
            set_bnds(texture: velocityTexture!, b: 1, commandBuffer: commandBuffer, view: view)
            set_bnds(texture: velocityTexture!, b: 2, commandBuffer: commandBuffer, view: view)
            
            // --- CLEAR DIVERGENCE ---
            clearDivergence(commandBuffer: commandBuffer, view: view)
        }
        
        pencilInputs.removeAll()
        
    }
    
}

#Preview {
    ContentView()
}
