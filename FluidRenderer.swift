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
    
    let diffuseSolver : Compute
    let pencilInputCompute : Compute
    
    init (metalDevice : MTLDevice) {
        self.metalDevice = metalDevice
    
        // Setup Compute Stages
        diffuseSolver = Compute(kernel: "diffuse_kernel", metalDevice: metalDevice)
        
        pencilInputCompute = Compute(kernel: "input_kernel", metalDevice: metalDevice)
        
        FluidRenderer.instance = self

    }
    
    func setOutputTexture (output : MTLTexture?) {
        self.output = output
    }
    
    var pencilInputs : [PencilInput] = []
    
    func addInput (screenPoint : SIMD2<Float>, direction : SIMD2<Float>, radius : Float) {
       
        pencilInputs.append( PencilInput(point: screenPoint, direction: direction, radius: radius) )
        
    }
    
    func runCompute(commandBuffer : MTLCommandBuffer, view: MTKView) {
        if (output != nil) {
            
            for pencilInput in pencilInputs {
                print("Pressure : \(pencilInput.radius)")
                print("Direction : \(pencilInput.direction.x), \(pencilInput.direction.y)")
                print("Pos : \(pencilInput.point.x), \(pencilInput.point.y)")
                // Add Inputs
                pencilInputCompute.setComputeBuffer(name: "pencil_input", index: 0, value: pencilInput)
                
                pencilInputCompute.run(inOutTexture: output!, commandBuffer: commandBuffer, view: view)
                
            }
            
            diffuseSolver.run(inOutTexture: output!, commandBuffer: commandBuffer, view: view)
        }
        
        pencilInputs.removeAll()
        
    }
    
}

#Preview {
    ContentView()
}
