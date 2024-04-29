//
//  FluifyApp.swift
//  Fluify
//
//  Created by Ajay Venkat on 28/4/2024.
//

import SwiftUI

@main
struct FluifyApp: App {
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                  
                DrawingViewWrapper()
                    
            }.frame(width: 500, height: 500)
        }
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let xDist = point.x - x
        let yDist = point.y - y
        return sqrt(xDist * xDist + yDist * yDist)
    }
    
    func angle(to point: CGPoint) -> Angle {
        let dx = point.x - x
        let dy = point.y - y
        let angle = atan2(dy, dx)
        return Angle(radians: Double(angle))
    }
}

#Preview {
    ContentView()
}
