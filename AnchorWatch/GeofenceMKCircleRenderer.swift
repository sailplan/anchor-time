//
//  GeofenceMKCircleRenderer.swift
//  ResizableGeofence
//
//  Created by Siddharth Paneri on 05/06/18.
//  Copyright © 2018 Siddharth Paneri. All rights reserved.
//

import UIKit
import MapKit

fileprivate let DEFAULT_COLOR = UIColor(red: 1, green: 1, blue: 1, alpha: 1)

protocol GeofenceMKCircleRendererDelegate {
    func onRadiusChange(radius : Double)
}

class GeofenceMKCircleRenderer: MKCircleRenderer {
    var thumbBounds : MKMapRect?
    var border = 3.0
    var thumbRadius = 15.0
    var radiusLineWidth = 3.0
    fileprivate var radius = 0.0
    fileprivate var mapRadius = 0.0
    var fenceBorderColor = DEFAULT_COLOR.withAlphaComponent(0.6)
    var fenceBackgroundColor = DEFAULT_COLOR.withAlphaComponent(0.5)
    var fenceThumbColor = DEFAULT_COLOR
    var fenceRadiusColor = DEFAULT_COLOR

    var delegate : GeofenceMKCircleRendererDelegate?

    override init(circle: MKCircle) {
        super.init(circle: circle)
        self.radius = circle.radius
    }

    convenience init(circle: MKCircle, radius: Double) {
        self.init(circle: circle)
        self.radius = radius
    }

    /** radius in meters */
    func set(radius : Double){
        mapRadius = radius
        invalidatePath()
    }
    
    /** radius in meters */
    func getRadius()-> Double{
        return mapRadius
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let mapPoint = MKMapPoint(overlay.coordinate)
        let radiusAtLatitude = mapRadius * MKMapPointsPerMeterAtLatitude(overlay.coordinate.latitude)
        
        let circleBounds = MKMapRect(x: mapPoint.x, y: mapPoint.y, width: radiusAtLatitude*2, height: radiusAtLatitude*2)

        let overlayRect = self.rect(for: circleBounds)
        context.setStrokeColor(self.fenceBorderColor.cgColor)
        context.setFillColor(self.fenceBackgroundColor.cgColor)
        context.setLineWidth(CGFloat(self.border)/zoomScale)
        context.setShouldAntialias(true)
        context.addArc(center: overlayRect.origin, radius: CGFloat(radiusAtLatitude), startAngle: 0, endAngle: CGFloat(2*Double.pi), clockwise: true)
        context.drawPath(using: .fillStroke)

        // Circle thumb on right
        let xPos = overlayRect.origin.x + CGFloat(radiusAtLatitude)
        let yPos = overlayRect.origin.y
        let thumbPoint = CGPoint(x: xPos, y: yPos)
        context.setStrokeColor(self.fenceThumbColor.cgColor)
        context.setFillColor(self.fenceThumbColor.cgColor)
        let rad = self.thumbRadius / Double(zoomScale)
        let radLineWidth = self.radiusLineWidth / Double(zoomScale)
        context.setShouldAntialias(true)
        context.addArc(center: CGPoint(x: xPos, y: yPos), radius: CGFloat(rad) , startAngle: 0, endAngle: CGFloat(2*Double.pi), clockwise: true)
        context.drawPath(using: CGPathDrawingMode.fill)

        let thumbRect = CGRect(x: xPos-CGFloat(rad*2), y: yPos-CGFloat(rad*2), width: CGFloat(rad)*4, height: CGFloat(rad)*4)
        self.thumbBounds = self.mapRect(for: thumbRect)

        /* create radius dashed line */
        let patternWidth = 2 / CGFloat(zoomScale)
        context.setLineWidth(CGFloat(radLineWidth))
        context.setStrokeColor(self.fenceRadiusColor.cgColor)
        context.move(to: thumbPoint)
        context.setShouldAntialias(true)
        context.addLine(to: overlayRect.origin)
        context.setLineDash(phase: 0, lengths: [CGFloat(patternWidth), CGFloat(patternWidth * 4)])
        context.setLineCap(CGLineCap.round)
        context.drawPath(using: CGPathDrawingMode.stroke)

        DispatchQueue.main.async {
            self.delegate?.onRadiusChange(radius: self.mapRadius)
        }
        UIGraphicsPopContext()
    }
}
