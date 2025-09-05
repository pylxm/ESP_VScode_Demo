//
//  StandingPostureCapture.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation

class StandingPostureCapture:Assessment
{
    var name: String = "Standing Posture Capture"
    var fileNameComponent: String = "Posture_Capture"
    var sensorTypeRequired: [Settings.SensorType] = [.neck]

    var listData: [(key:String,data:Any)] {
        [ ("Neck Yaw Mean", neckYawMean),
          ("Neck Pitch Mean", neckPitchMean),
          ("Neck Roll Mean", neckRollMean),
          ("Neck Pitch Angle", neckPitchAngle),
        ]
    }

    // MARK: - custom properties for standing posture capture
    var neckTimeOffset: Int = 0
    var neckPitchMean: Float = 0.0
    var neckRollMean: Float = 0.0
    var neckYawMean: Float = 0.0
    var initialNeckPitch: Float = 0.0
    var initialNeckRoll: Float = 0.0
    var initialNeckYaw: Float = 0.0
    var neckPitchAngle: Float = 0.0
    
    var eulerAngleIndex: Int = 0
    var neckRollCSV:[String] = []
    
    // MARK: - Assessment interface
    func updateAssessment(sensor: Sensor) {
        guard let mwSensor = sensor as? MWIMU else {return}
        
        // update mean values incrementally using new data
        let eulerAngleCount = mwSensor.eulerAngle.count
        if eulerAngleCount > eulerAngleIndex {
            // new data added
            if eulerAngleIndex == 0 {
                initialNeckYaw = mwSensor.eulerAngle[0].data[0]
                initialNeckPitch = mwSensor.eulerAngle[0].data[1]
                initialNeckRoll = mwSensor.eulerAngle[0].data[2]
            }
            
            let newData = mwSensor.eulerAngle[eulerAngleIndex..<eulerAngleCount].map{tf in tf.data}
            neckYawMean = (neckYawMean * Float(eulerAngleIndex)) + Utils.sum(newData.map{data in data[0] - initialNeckYaw})
            neckYawMean /= Float(eulerAngleCount)
            neckPitchMean = (neckPitchMean * Float(eulerAngleIndex)) + Utils.sum(newData.map{data in data[1] - initialNeckPitch})
            neckPitchMean /= Float(eulerAngleCount)
            neckRollMean = (neckRollMean * Float(eulerAngleIndex)) + Utils.sum(newData.map{data in data[2] - initialNeckRoll})
            neckRollMean /= Float(eulerAngleCount)
            
            // collect details for output
            mwSensor.eulerAngle[eulerAngleIndex..<eulerAngleCount].forEach { tf in
                neckRollCSV.append(String(format: "%.2f,%.2f", Float(tf.time)*0.01, tf.data[2]))
            }

            eulerAngleIndex = eulerAngleCount
        }
        
    }
    
    func startRecording()
    {
        // reset counters
        eulerAngleIndex = 0
        neckYawMean = 0.0
        neckPitchMean = 0.0
        neckRollMean = 0.0
        initialNeckYaw = 0.0
        initialNeckPitch = 0.0
        initialNeckRoll = 0.0
        neckRollCSV = []
    }
    
    func stopRecording(outputPrefix:String = "")
    {
        if !outputPrefix.isEmpty {
            // save summary data to CSV file
            let csvData = csvSummary()
            CSVWriter.save(header: "Standing posture summary", body: csvData, filename: "\(outputPrefix)_Summary.csv")
            
            // save detail data to CSV file
            if !neckRollCSV.isEmpty {
                CSVWriter.save(header: "Time stamp, Neck Roll", body: neckRollCSV, filename: "\(outputPrefix)_RPY.csv")
            }
        }
    }
    
    // MARK: - standing posture capture specific
    func csvSummary()->[String]
    {
        [ 
            String(format: "Pitch mean, %.3f degrees", neckPitchMean),
            String(format: "Roll mean, %.3f degrees", neckRollMean),
            String(format: "Yaw mean, %.3f degrees", neckYawMean)
        ]
    }

}
