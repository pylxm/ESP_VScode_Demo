//
//  HeelTapping.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 20/11/24.
//

import AVFoundation

class HeelTapping:Assessment
{
    var name: String
    var fileNameComponent: String
    var sensorTypeRequired: [Settings.SensorType]
    var listData: [(key:String,data:Any)] {
        [ ("Total Time", String(format: "%.2f s", heelTappingTotalTime)),
          ("Mean Tap Interval", String(format: "%.2f ms", heelTappingAverage)),
          ("Time Deviation", String(format: "%.2f ms", heelTappingSD)),
          ("\(sideText) Heel Tap Count", String(format: "%d", plusOne)),
          ("Max Acceleration", String(format: "%.2f m/s2", meanMaxAcc * 1000)),
        ]
    }
    
    // MARK: - custom properties for Heel Tapping
    var sideText:String
    var ALPHA:Float
    var heelValueAccX: Float = 0
    var heelValueAccY: Float = 0
    var heelValueAccZ: Float = 0
    var heelValueCom: Float = 0
    var axFilteredOffset: Float = 0
    var axFiltered: Float = 0
    var heelFilteredPrev: Float = 0
    
    var accOffset: [Float] = []
    let offsetSample = 40
    var findMinAcc = false
    var currentMax: Float = 0
    var minAcc: Float = 0
    var totalMaxAcc: Float = 0
    var meanMaxAcc: Float = 0
    var peakDetect = false
    
    var plusOne: Int = 0
    var tapDeadZone: Int = 0
    
    var currentTime: CFTimeInterval = 0
    var currentTimeAcc: CFTimeInterval = 0
    var prevTimeAcc: CFTimeInterval = 0
    
    var heelTappingCurrentTime: CFTimeInterval = 0
    var heelTappingPrevTime: CFTimeInterval = 0
    var heelTappingTotalTime: CFTimeInterval = 0
    var heelTappingAverage: CFTimeInterval = 0
    var heelTappingSD: CFTimeInterval = 0
    
    var detectedHeelTappingCSV: [String] = []
    
    // MARK: - Assessment interface
    func updateAssessment(sensor: Sensor) 
    {
        guard let mwSensor = sensor as? MWIMU, sensorTypeRequired.contains(sensor.type),
              let tfAcc = mwSensor.accelerometer.last else {return}
        
        heelValueAccX = tfAcc.data[0]
        heelValueAccY = tfAcc.data[1]
        heelValueAccZ = tfAcc.data[2]
        heelValueCom = sqrt(heelValueAccX*heelValueAccX + heelValueAccY*heelValueAccY + heelValueAccZ*heelValueAccZ)
        
        axFilteredOffset = heelFilteredPrev*ALPHA + heelValueCom*(1-ALPHA)
        heelFilteredPrev = axFilteredOffset
        
        // assume it is getting moving average of up to 40 values
        accOffset.append(axFilteredOffset)
        if accOffset.count == offsetSample {
            accOffset.removeFirst()
        }
        let avgAccOffset = average(accOffset)
        axFiltered = axFilteredOffset - avgAccOffset
        
        if axFiltered < -1 && findMinAcc {
            if currentMax > axFiltered {
                currentMax = axFiltered
            }
            else if axFiltered > currentMax {
                minAcc = currentMax
                if plusOne > 0 {
                    totalMaxAcc -= minAcc
                    meanMaxAcc = totalMaxAcc / Float(plusOne)
                }
                findMinAcc = false
            }
        }
        
        if axFiltered > 0 && !findMinAcc {
            findMinAcc = true
            currentMax = 0
        }
        
        if tapDeadZone > 0 {
            tapDeadZone += 1
        }
        if tapDeadZone > 5 {
            tapDeadZone = 0
        }
        
        // to detect for each tap
        let TH:Float = -200000000.00
        if (axFilteredOffset*axFilteredOffset - avgAccOffset*avgAccOffset)  < TH && !peakDetect {
            peakDetect = true
            let value = axFilteredOffset * axFilteredOffset - avgAccOffset * avgAccOffset
            Utils.log(String(format: "%.4f", value))  // 4 decimal places
        }
        
        if peakDetect {
            if (axFilteredOffset*axFilteredOffset - avgAccOffset*avgAccOffset) > TH {
                
                
                currentTime = CACurrentMediaTime()
                heelTappingCurrentTime = currentTime - heelTappingPrevTime
                heelTappingTotalTime += heelTappingCurrentTime
                plusOne += 1
                tapDeadZone += 1

                if plusOne == 1 {
                    heelTappingCurrentTime = heelTappingCurrentTime - currentTime
                    heelTappingTotalTime = heelTappingCurrentTime
                    heelTappingSD = sqrt((pow((heelTappingCurrentTime - heelTappingAverage),2)/Double(plusOne)))
                }
                peakDetect = false
                heelTappingPrevTime = currentTime
                heelTappingAverage = heelTappingTotalTime/Double(plusOne)
                heelTappingSD = sqrt((pow((heelTappingCurrentTime - heelTappingAverage),2)/Double(plusOne)))
                
                detectedHeelTappingCSV.append(String(format: "%d,%.2f,%.2f,%.2f,%.2f", plusOne, heelTappingTotalTime, heelTappingAverage, heelTappingSD, meanMaxAcc))
            }
        }
    }
    
    func startRecording() 
    {
        accOffset = []
        detectedHeelTappingCSV = []
        findMinAcc = false
        
        currentMax = 0
        minAcc = 0
        totalMaxAcc = 0
        meanMaxAcc = 0
        peakDetect = false
        
        plusOne = 0
        tapDeadZone = 0
        
        currentTime = 0
        currentTimeAcc = 0
        prevTimeAcc = 0
        
        heelTappingCurrentTime = 0
        heelTappingPrevTime = 0
        heelTappingTotalTime = 0
        heelTappingAverage = 0
        heelTappingSD = 0
    }
    
    func stopRecording(outputPrefix:String = "") 
    {
        // save summary data to CSV file
        if !outputPrefix.isEmpty && !detectedHeelTappingCSV.isEmpty{
            let csvHeader = "Heel_Tap_Count,Total_Time_ms,Mean_Tap_Interval_ms,Time_Deviation_ms,Max_Acceleration"
            CSVWriter.save(header: csvHeader, body: detectedHeelTappingCSV, filename: "\(outputPrefix)_Summary.csv")
        }
    }
    
    // MARK: - Heel Tapping specific
    init(_ side:Settings.SensorType)
    {
        sideText = side.text.capitalized
        name = "Heel Tapping \(sideText)"
        fileNameComponent = "Heel_Tapping_\(sideText)"
        sensorTypeRequired = [side]
        
        ALPHA = (side == .left) ? 0.8 : 0.75
    }
    
    /// average values in an array
    func average<T:FloatingPoint>(_ list:[T])->T
    {
        list.reduce(0,+) / T(list.count)
    }
    
    func csvSummary()->[String]
    {
        detectedHeelTappingCSV
    }
}
