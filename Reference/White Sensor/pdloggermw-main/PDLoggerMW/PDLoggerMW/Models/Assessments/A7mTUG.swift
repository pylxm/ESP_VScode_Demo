//
//  A7MTUG.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation
import AVFoundation

class A7mTUG:Assessment
{
    var name: String = "7 Meters Timed Up and Go"
    var fileNameComponent: String = "7_Meters_Timed_Up_And_Go"
    var sensorTypeRequired: [Settings.SensorType] = [.neck, .left, .right]
//    var listData: [(key:String,data:Any)] {
//        [ ("State", stateTUG.rawValue),
//          ("Sit to stand duration", String(format: "%.2f s", standingDuration)),
//          ("Stand to sit duration", String(format: "%.2f s", sittingDuration)),
//          ("Walking forward duration", String(format: "%.2f s", walkForwDuration)),
//          ("Turning duration", String(format: "%.2f s", turnDuration)),
//          ("Walking backward duration", String(format: "%.2f s", walkBackDuration)),
//        ]
//    }
    var listData: [(key:String,data:Any)] {
        [
        ] +
        gait.listData
    }
    
    // MARK: - custom properties for 7 meters timed up and go
    var startStandingTime: CFTimeInterval = 0
    var endStandingTime: CFTimeInterval = 0
    var standingDuration: CFTimeInterval = 0
    var startSittingTime: CFTimeInterval = 0
    var endSittingTime: CFTimeInterval = 0
    var sittingDuration: CFTimeInterval = 0
    var walkForwDuration: CFTimeInterval = 0
    var walkBackDuration: CFTimeInterval = 0
    var turningStartTime: CFTimeInterval = 0
    var turningStopTime: CFTimeInterval = 0
    var turnDuration: CFTimeInterval = 0
    
    var start_roll:Float = 0.0
    var start_yaw:Float = 0.0
    var back_yaw:Float = 0.0
    
    var gait = Gait()
    
    // TUG state
    enum TUGStateType: String {
        case initializing = "Initializing"
        case sitting = "Sitting"
        case sitToStand = "Starting to stand"
        case standing = "Standing"
        case walkingForward = "Walking Forward"
        case turning = "Turning"
        case walkingBackward = "Walking Backward"
        case standToSit = "Starting to sit"
        case end = "End"
    }
    var stateTUG:TUGStateType = .initializing

    
    // MARK: - Assessment interface
    func updateAssessment(sensor: Sensor)
    {
        gait.updateAssessment(sensor: sensor)
        guard let mwSensor = sensor as? MWIMU, mwSensor.type == .neck,
            let tf = mwSensor.eulerAngle.last,
            let tfAcc = mwSensor.accelerometer.last else {return}
        
        var cur_yaw = tf.data[0]
        if cur_yaw >= 350 {
            cur_yaw = cur_yaw - 360
        }
        let cur_roll = tf.data[2]
        let cur_accZ = tfAcc.data[0]
        let last_index = mwSensor.eulerAngle.count - 1
        
        if stateTUG == .initializing{
            start_roll = cur_roll
            start_yaw = cur_yaw
            back_yaw = -1.0;
            stateTUG = .sitting
        }
        
        else if stateTUG == .sitting &&
            start_roll - cur_roll >= 1{
            startStandingTime = CACurrentMediaTime()
            stateTUG = .sitToStand
        }
        
        else if stateTUG == .sitToStand && last_index >= 5{
            // roll is close to the start roll
            if abs(start_roll - cur_roll) <= 10 &&
                // roll is recovering, increasing back to start roll
                mwSensor.eulerAngle[last_index].data[2] > mwSensor.eulerAngle[last_index - 1].data[2] &&
                mwSensor.eulerAngle[last_index - 1].data[2] > mwSensor.eulerAngle[last_index - 2].data[2] &&
                // the vertical acceleration is decreasing
                mwSensor.accelerometer[last_index - 1].data[0] - cur_accZ > 0 {
                    endStandingTime = CACurrentMediaTime()
                    standingDuration = endStandingTime - startStandingTime
                    stateTUG = .walkingForward
            }
        }
        
        else if stateTUG == .walkingForward &&
            // yaw sudden change, indicating the start of turn
            abs(start_yaw - cur_yaw) >= 30{
                turningStartTime = CACurrentMediaTime()
                walkForwDuration = turningStartTime - endStandingTime
                stateTUG = .turning
        }
        
        else if stateTUG == .turning &&
            // change of yaw is small, indicate end of turning
            abs(mwSensor.eulerAngle[last_index-1].data[0] - cur_yaw) <= 0.5{
                back_yaw = cur_yaw
                turningStopTime = CACurrentMediaTime()
                turnDuration = turningStopTime - turningStartTime
                stateTUG = .walkingBackward
        }
        
        else if stateTUG == .walkingBackward &&
            // large change of yaw, indicating turning and sitting down
            abs(back_yaw - cur_yaw) >= 30{
            startSittingTime = CACurrentMediaTime()
            walkBackDuration = startSittingTime - turningStopTime
            stateTUG = .standToSit
        }
                
        else if stateTUG == .standToSit && last_index >= 55{
            // ensure [last_index - 25] is within sitting down period
            if abs(back_yaw - mwSensor.eulerAngle[last_index - 25].data[0]) >= 30 &&
                // estimate if [last_index - 25] is the minimun within 1 second window
                mwSensor.accelerometer[last_index-25].data[0] < mwSensor.accelerometer[last_index-50].data[0] &&
                mwSensor.accelerometer[last_index-25].data[0] < mwSensor.accelerometer[last_index].data[0]{
                    endSittingTime = CACurrentMediaTime()
                    sittingDuration = endSittingTime - startSittingTime
                    stateTUG = .end
            }
        }
        
    }
    
    func startRecording()
    {
        gait.startRecording()
        
        stateTUG = .initializing
        
        standingDuration = 0
        sittingDuration = 0
        walkForwDuration = 0
        turnDuration = 0
        walkBackDuration = 0
        
        startStandingTime = 0
        endStandingTime = 0
        standingDuration = 0
        startSittingTime = 0
        endSittingTime = 0
        sittingDuration = 0
        walkForwDuration = 0
        walkBackDuration = 0
        turningStartTime = 0
        turningStopTime = 0
        turnDuration = 0
        
        start_roll = 0.0
        start_yaw = 0.0
        back_yaw = 0.0
    }
    
    func stopRecording(outputPrefix:String = "")
    {
        gait.stopRecording()
        
        // save summary data to CSV file
        if !outputPrefix.isEmpty {
            let csvData = csvSummary()
            CSVWriter.save(header: "Timed-up And Go assessment summary", body: csvData, filename: "\(outputPrefix)_Summary.csv")
        }
    }
    
    func csvSummary()->[String]
    {
        [
            String(format: "Sit to stand duration, %.2f s", standingDuration),
            String(format: "Walking forward duration, %.2f s", walkForwDuration),
            String(format: "Turning duration,%.2f s", turnDuration),
            String(format: "Walking backwards duration, %.2f s", walkBackDuration),
            String(format: "Stand to sit duration, %.2f s", sittingDuration),
        ]  + gait.csvSummary()
    }
}
