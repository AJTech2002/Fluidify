//
//  Compute.swift
//  Fluify
//
//  Created by Ajay Venkat on 29/4/2024.
//

import Foundation
import MetalKit

enum ComputeVariableType {
    case
    Texture,
    Number,
    Buffer
}


struct ComputeVariable {
    
    var type : ComputeVariableType
    var number : Float?
    var texture : MTLTexture?
    var buffer: MTLBuffer?
    var index: Int
    
}

class Compute {
    
    let computePipelineState : MTLComputePipelineState

    var computeVariables : [String:ComputeVariable] = [:]
    
    let metalDevice : MTLDevice
    
    init (kernel: String, metalDevice : MTLDevice) {
        self.metalDevice = metalDevice
        
        let library = metalDevice.makeDefaultLibrary()
        
        guard let kernel = library?.makeFunction(name: kernel) else {
            fatalError()
        }
        
        do {
            try computePipelineState = metalDevice.makeComputePipelineState(function: kernel)
        }
        catch {
            fatalError()
        }
    }
    
    func setComputeFloat (name : String, index: Int, value : Float) {
        computeVariables[name] = ComputeVariable(type: .Number, number: value, index: index)
    }
    
    func setComputeTexture (name : String, index: Int, value : MTLTexture) {
        computeVariables[name] = ComputeVariable(type: .Texture, texture: value, index: index)
    }
    
    func setComputeBuffer<T>(name: String, index: Int, value: T) {
        guard let computeVariable = computeVariables[name] else {
            let dataSize = MemoryLayout<T>.stride
            guard let buffer = metalDevice.makeBuffer(length: dataSize, options: []) else {
                return
            }
            
            let pointer = buffer.contents().bindMemory(to: T.self, capacity: 1)
            pointer.initialize(to: value)
            
            computeVariables[name] = ComputeVariable(type: .Buffer, buffer: buffer, index: index)
            return
        }
        
        let dataSize = MemoryLayout<T>.stride
        guard let buffer = computeVariable.buffer else {
            return
        }
        
        guard buffer.length >= dataSize else {
            return
        }
        
        let pointer = buffer.contents().bindMemory(to: T.self, capacity: 1)
        pointer.initialize(to: value)
        
    }
    
    
    func run (inOutTexture: MTLTexture, commandBuffer: MTLCommandBuffer?, view: MTKView) {
        
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        computeEncoder?.setComputePipelineState(computePipelineState)
        
        let threadGroupWidth = computePipelineState.threadExecutionWidth
        let threadGroupHeight = computePipelineState.maxTotalThreadsPerThreadgroup / computePipelineState.threadExecutionWidth
        let threadGroupSize = MTLSizeMake(threadGroupWidth, threadGroupHeight, 1)
        let gridSize = MTLSizeMake(Int(view.drawableSize.width), Int(view.drawableSize.height), 1)
        
        for (_, value) in computeVariables {
            if value.type == .Number {
                var numberValue = value.number!
                computeEncoder?.setBytes(&numberValue, length: MemoryLayout<Float>.size, index: value.index)
            } else if value.type == .Texture {
                computeEncoder?.setTexture(value.texture, index: value.index)
            }
            else if value.type == .Buffer {
                computeEncoder?.setBuffer(value.buffer, offset: 0, index: value.index)
            }
        }
        
        
        computeEncoder?.setTexture(inOutTexture, index: 0)
        computeEncoder?.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        computeEncoder?.endEncoding()
        
    }
    
}
