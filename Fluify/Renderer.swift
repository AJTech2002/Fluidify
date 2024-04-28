//
//  Renderer.swift
//  Fluify
//
//  Created by Ajay Venkat on 28/4/2024.
//

import MetalKit

class Renderer : NSObject, MTKViewDelegate {

    var parent: ContentView
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    
    let screen_verts : [SIMD2<Float>] = [
        SIMD2<Float>(-1, -1), SIMD2<Float>(1, -1), SIMD2<Float>(-1, 1),
        SIMD2<Float>(-1, 1), SIMD2<Float>(1, -1), SIMD2<Float>(1, 1)
    ]
    
    let screen_tex_coords : [SIMD2<Float>] = [
        SIMD2<Float>(0, 1), SIMD2<Float>(1, 1), SIMD2<Float>(0, 0),
        SIMD2<Float>(0, 0), SIMD2<Float>(1, 1), SIMD2<Float>(1, 0)
    ]
    
    let pipelineState : MTLRenderPipelineState
    
    let vertexBuffer : MTLBuffer
    let textureCoordBuffer : MTLBuffer
    
    init(_ parent : ContentView) {
        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        self.metalCommandQueue = metalDevice.makeCommandQueue()
        
        // Setup the Render Pipeline (Descriptor -> State)
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        let library = metalDevice.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_main")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            try pipelineState = metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            fatalError()
        }
        
        // Setup Quad to Render to Screen
        vertexBuffer = metalDevice.makeBuffer(bytes: screen_verts, length: screen_verts.count * MemoryLayout<SIMD2<Float>>.stride, options: [])!
        textureCoordBuffer = metalDevice.makeBuffer(bytes: screen_tex_coords, length: screen_tex_coords.count * MemoryLayout<SIMD2<Float>>.stride, options: [])!
        
    
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        let commandBuffer = metalCommandQueue.makeCommandBuffer()
        
        let renderPassDescriptor = view.currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor()
        renderPassDescriptor?.colorAttachments[0].loadAction = .load
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderEncoder?.setRenderPipelineState(pipelineState)
        
        
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.setVertexBuffer(textureCoordBuffer, offset: 0, index: 1)
        
        // Draw basic screen rect
        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder?.endEncoding()
        
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        
    }
    
}
