//
//  ClockDrawingView.swift
//  FaceLandmarker
//
//  Created by Hans zhu on 8/18/24.
//

import UIKit

class ClockDrawingView: UIView {
    var hourHandPosition: CGPoint?
    var minuteHandPosition: CGPoint?
    private var currentPath: UIBezierPath?
    private var allPaths: [UIBezierPath] = []
    private var isHourHandSet = false
    
    // Setup the view to allow user drawing
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        setupGestureRecognizers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = .white
        setupGestureRecognizers()
    }
    
    private func setupGestureRecognizers() {
        // Enable touch-based drawing
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        self.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: self)
        
        switch sender.state {
        case .began:
            currentPath = UIBezierPath()
            currentPath?.move(to: location)
        case .changed:
            currentPath?.addLine(to: location)
            setNeedsDisplay()  // Trigger a redraw
        case .ended:
            if let path = currentPath {
                allPaths.append(path)
            }
            if !isHourHandSet {
                hourHandPosition = location  // Set hour hand position
                isHourHandSet = true
            } else {
                minuteHandPosition = location  // Set minute hand position
            }
            currentPath = nil
        default:
            break
        }
    }
    
    // Override draw function to draw the paths
    override func draw(_ rect: CGRect) {
        UIColor.black.setStroke()
        for path in allPaths {
            path.lineWidth = 2
            path.stroke()
        }
        currentPath?.lineWidth = 2
        currentPath?.stroke()
        
        // Draw the clock face circle
        if let context = UIGraphicsGetCurrentContext() {
            let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
            let radius = min(rect.width, rect.height) / 2 - 20 // Padding around the circle
            context.setLineWidth(5)
            context.setStrokeColor(UIColor.black.cgColor)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            context.strokePath()
            
            // Draw hour marks
            for i in 1...12 {
                let angle = CGFloat(i) * .pi / 6 // Divide the circle into 12 parts
                let markRadius = radius - 20 // Shorter marks for the hour indicators
                let xStart = center.x + markRadius * cos(angle)
                let yStart = center.y + markRadius * sin(angle)
                let xEnd = center.x + radius * cos(angle)
                let yEnd = center.y + radius * sin(angle)
                context.move(to: CGPoint(x: xStart, y: yStart))
                context.addLine(to: CGPoint(x: xEnd, y: yEnd))
                context.strokePath()
            }
        }
    }
    
    // Clear the drawing
    func clearDrawing() {
        allPaths.removeAll()
        hourHandPosition = nil
        minuteHandPosition = nil
        isHourHandSet = false
        setNeedsDisplay()
    }
}
