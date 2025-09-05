//
//  RecordButton.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 18/11/24.
//

import UIKit

class RecordButton: CALayer
{
    let ringPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 70, height: 70)).cgPath
    let circlePath = UIBezierPath(ovalIn: CGRect(x: 5, y: 5, width: 60, height: 60)).cgPath
    let squarePath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 30, height: 30)).cgPath
    var isRecording = false
    
    let ringLayer = CAShapeLayer()
    let circleLayer = CAShapeLayer()
    let squareLayer = CAShapeLayer()
    
    override init()
    {
        super.init()
        // createRingViewLayer
        ringLayer.path = ringPath
        ringLayer.lineWidth = 3.0
        ringLayer.strokeColor = UIColor.white.cgColor
        ringLayer.fillColor = UIColor.clear.cgColor
        
        // createCircleLayer
        circleLayer.fillColor = UIColor.red.cgColor
        circleLayer.path = circlePath
        
        // createSquareLater
        squareLayer.fillColor = UIColor.red.cgColor
        squareLayer.path = squarePath
        
        // initial set up (ring + circle)
        self.addSublayer(ringLayer)
        self.addSublayer(circleLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func buttonTapped()
    {
        // change button from circle to square with animation
        squareLayer.add(transition(from: circlePath, to: squarePath), forKey: "animatePath")
        self.replaceSublayer(circleLayer, with: squareLayer)
        isRecording = true
    }
    
    func buttonUntapped()
    {
        // change button from square to circle with animation
        circleLayer.add(transition(from: squarePath, to: circlePath), forKey: "animatePath")
        self.replaceSublayer(squareLayer, with: circleLayer)
        isRecording = false
    }
    
    private func transition(from: CGPath, to: CGPath) -> CABasicAnimation
    {
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return animation
    }

}
