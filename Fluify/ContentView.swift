//
//  ContentView.swift
//  Fluify
//
//  Created by Ajay Venkat on 28/4/2024.
//

import SwiftUI
import MetalKit

struct ContentView: UIViewRepresentable {
    
    func makeCoordinator() -> Renderer {
        Renderer(self) // Give instance of view
    }
    
    func makeUIView(context: Context) -> MTKView {
        
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        
        return mtkView
        
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        
    }
    
}

#Preview {
    ContentView()
}
