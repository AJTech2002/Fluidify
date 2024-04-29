//
//  TextureUtils.swift
//  Fluify
//
//  Created by Ajay Venkat on 29/4/2024.
//

import Foundation
import MetalKit


func blitTexture(sourceTexture: MTLTexture, destinationTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
    guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
        return
    }
    
    // Copy the contents of sourceTexture to destinationTexture
    let origin = MTLOrigin(x: 0, y: 0, z: 0)
    let size = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: sourceTexture.depth)
    blitEncoder.copy(from: sourceTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: origin, sourceSize: size,
                     to: destinationTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: origin)
    
    blitEncoder.endEncoding()
}

func clearTexture(texture: MTLTexture, clearColor: MTLClearColor, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
    let renderPassDescriptor = MTLRenderPassDescriptor() 
    
    // Configure the render pass descriptor with the texture as the color attachment
    let colorAttachment = renderPassDescriptor.colorAttachments[0]
    colorAttachment?.texture = texture
    colorAttachment?.loadAction = .clear
    colorAttachment?.clearColor = clearColor
    
    
    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        return
    }
    
    // End the render encoder
    renderEncoder.endEncoding()
}

func createTextureWithSamePropertiesAs(inputTexture: MTLTexture, device: MTLDevice) -> MTLTexture? {
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: inputTexture.pixelFormat,
                                                                      width: inputTexture.width,
                                                                      height: inputTexture.height,
                                                                      mipmapped: inputTexture.mipmapLevelCount > 1)
    textureDescriptor.usage = inputTexture.usage
    textureDescriptor.storageMode = inputTexture.storageMode
    textureDescriptor.cpuCacheMode = inputTexture.cpuCacheMode
    textureDescriptor.resourceOptions = inputTexture.resourceOptions
    
    return device.makeTexture(descriptor: textureDescriptor)
}

func loadTexture(named imageName: String, into texture: MTLTexture, device: MTLDevice) {
       guard let image = UIImage(named: imageName) else {
           print("Failed to load image named \(imageName) from assets.")
           return
       }
       
       loadTexture(from: image, into: texture, device: device)
   }
   
func loadTexture(from image: UIImage, into texture: MTLTexture, device: MTLDevice) {
   guard let cgImage = image.cgImage else {
       print("Failed to get CGImage from UIImage.")
       return
   }
   
   let textureLoader = MTKTextureLoader(device: device)
   do {
       let newTexture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
       copyTexture(source: newTexture, destination: texture, device: device)
   } catch {
       print("Error loading texture:", error)
   }
}

func copyTexture(source: MTLTexture, destination: MTLTexture, device: MTLDevice) {
   let commandQueue = device.makeCommandQueue()!
   let commandBuffer = commandQueue.makeCommandBuffer()!
   
   let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
   blitCommandEncoder.copy(from: source,
                            sourceSlice: 0,
                            sourceLevel: 0,
                            sourceOrigin: MTLOriginMake(0, 0, 0),
                            sourceSize: MTLSizeMake(source.width, source.height, source.depth),
                            to: destination,
                            destinationSlice: 0,
                            destinationLevel: 0,
                            destinationOrigin: MTLOriginMake(0, 0, 0))
   blitCommandEncoder.endEncoding()
   
   commandBuffer.commit()
   commandBuffer.waitUntilCompleted()
}
