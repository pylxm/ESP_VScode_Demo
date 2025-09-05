//
//  FreeWalk.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation
import AVFoundation

class FreeWalk:Assessment
{
    var name: String = "Free Walk"
    var fileNameComponent: String = "Free_Walk"
    var sensorTypeRequired: [Settings.SensorType] = [.neck, .left, .right]
    var listData: [(key:String,data:Any)] {
        [
        ] +
        gait.listData
    }
    
    // MARK: - custom properties for Free Walk
    var getNeckOffset = true
    var neckTimeOffset: CFTimeInterval = 0
    
    var rollFoundTrough = true;
    var rollFoundPeak = true;
    var pitchFoundTrough = true
    var pitchFoundPeak = true
    var initializeMaxMin = true
    var maxNRoll: Float = 0
    var minNRoll: Float = 0
    var maxNPitch: Float = 0
    var minNPitch: Float = 0
    var sumRollPeak: Float = 0
    var sumRollTrough: Float = 0
    var meanRollPeak: Float = 0
    var meanRollTrough: Float = 0
    var sumPitchPeak: Float = 0
    var sumPitchTrough: Float = 0
    var meanPitchPeak: Float = 0
    var meanPitchTrough: Float = 0
    var rollMinCounter: Int = 0
    var rollMaxCounter: Int = 0
    var pitchMinCounter: Int = 0
    var pitchMaxCounter: Int = 0
    var NRollPeak: [Float] = []
    var NRollTrough: [Float] = []
    var NPitchPeak: [Float] = []
    var NPitchTrough: [Float] = []
    
    var gait = Gait()
    
    // MARK: - Assessment interface
    func updateAssessment(sensor: Sensor) 
    {
        gait.updateAssessment(sensor: sensor)
        guard let mwSensor = sensor as? MWIMU, mwSensor.type == .neck,
              let tf = mwSensor.eulerAngle.last  else {return}
        
        if getNeckOffset {
            neckTimeOffset = CACurrentMediaTime()
            getNeckOffset = false
        }
        calculateSway(neckPitch: tf.data[1], neckRoll: tf.data[2])
    }
    
    func startRecording() 
    {
        getNeckOffset = true
        gait.startRecording()
    }
    
    func stopRecording(outputPrefix:String = "") 
    {
        gait.stopRecording()
        
        // save summary data to CSV file
        if !outputPrefix.isEmpty {
            let csvData = csvSummary()
            CSVWriter.save(header: "\(name) summary", body: csvData, filename: "\(outputPrefix)_Summary.csv")
        }
    }
    
    // MARK: - Free Walk specific
    func calculateSway(neckPitch:Float, neckRoll:Float)
    {
        if rollFoundPeak {
            if neckRoll < minNRoll {
                minNRoll = neckRoll
                rollMinCounter = 0
            } 
            else {
                rollMinCounter += 1
            }
        }
        
        if rollFoundTrough {
            if neckRoll > maxNRoll {
                maxNRoll = neckRoll
                rollMaxCounter = 0
            } 
            else {
                rollMaxCounter += 1
            }
        }
        
        if rollMaxCounter > 20 {
            NRollPeak.append(maxNRoll)
            sumRollPeak += maxNRoll
            meanRollPeak = sumRollPeak/Float(NRollPeak.count)
            
            rollFoundPeak = true
            rollFoundTrough = false
//            Utils.log("Found peak at \(maxNRoll)")
            maxNRoll = -999
            rollMaxCounter = 0
        }
        
        if rollMinCounter > 20 {
            NRollTrough.append(minNRoll)
            sumRollTrough += minNRoll
            meanRollTrough = sumRollTrough/Float(NRollTrough.count)
            
            rollFoundTrough = true
            rollFoundPeak = false
//            Utils.log("Found trough at \(minNRoll)\n size: \(NRollTrough.count)")
            minNRoll = 999
            rollMinCounter = 0
        }
        //pitch
        if pitchFoundPeak {
            if neckPitch < minNPitch {
                minNPitch = neckPitch
                pitchMinCounter = 0
            } 
            else {
                pitchMinCounter += 1
            }
        }
        
        if pitchFoundTrough {
            if neckPitch > maxNPitch {
                maxNPitch = neckPitch
                pitchMaxCounter = 0
            } 
            else {
                pitchMaxCounter += 1
            }
        }
        
        if pitchMaxCounter > 20 {
            NPitchPeak.append(maxNPitch)
            sumPitchPeak += maxNPitch
            meanPitchPeak = sumPitchPeak/Float(NPitchPeak.count)
            
            pitchFoundPeak = true
            pitchFoundTrough = false
            Utils.log("Found peak at \(maxNPitch)")
            maxNPitch = -999
            pitchMaxCounter = 0
        }
        
        if (pitchMinCounter > 20) {
            NPitchTrough.append(minNPitch)
            sumPitchTrough += minNPitch
            meanPitchTrough = sumPitchTrough/Float(NPitchTrough.count)
            pitchFoundTrough = true
            pitchFoundPeak = false
            Utils.log("Found trough at \(minNPitch)\n size: \(NPitchTrough.count)")
            minNPitch = 999
            pitchMinCounter = 0
        }
        
        if NPitchPeak.count > 0 && NPitchTrough.count > 0 && NRollPeak.count > 0 && NRollTrough.count > 0 {
            Utils.log("Sway is: \(meanRollPeak - meanRollTrough) \(meanPitchPeak - meanPitchTrough)")
        }
    }
    
    func csvSummary()->[String]
    {
        [] + gait.csvSummary()
    }
}
