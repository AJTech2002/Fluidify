
import SwiftUI
import UIKit

struct DrawingViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> DrawingUIView {
        let view = DrawingUIView()
        return view
    }
    
    func updateUIView(_ uiView: DrawingUIView, context: Context) {
        // Update the view if needed
    }
}

class DrawingUIView: UIView {

    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, touch.type == .pencil else { return }
        
            let pressure = (touch.force / touch.maximumPossibleForce)*100.0
            let azimuthUnitVector = touch.azimuthUnitVector(in: self)
            
            let location = touch.preciseLocation(in: self)
            let normalizedLocation = CGPoint(x: location.x / bounds.width, y: location.y / bounds.height)

            FluidRenderer.instance.addInput(screenPoint: float2(Float(normalizedLocation.x), Float(normalizedLocation.y)), direction: float2(Float(-azimuthUnitVector.dx), Float(-azimuthUnitVector.dy)), radius: Float(pressure))
            
        }
}
