//
//  Gait.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 20/11/24.
//

import Foundation

class Gait: Assessment
{
    var name: String = "Gait Analysis"
    var fileNameComponent: String = "gait"
    var sensorTypeRequired: [Settings.SensorType] = [.left, .right]
    
    var listData: [(key: String, data: Any)] {
        [ //("Coeff of Var", String(format: "Left: %.2f Right: %.2f", covOfvar[0], covOfvar[1])),
          ("Step Count", String(format: "Left: %d Right: %d Total: %d", countStep[0], countStep[1], totalStepCount)),
          ("Stride time", String(format: "Mean: %.2f s Max: %.2f s Min: %.2f s", meanStrideTime[1], maxStrideTime[1], minStrideTime[1])),
          ("Cadence", String(format: "%.2f Max: %.2f Min: %.2f (steps/min)", cadence[1], maxCadence[1], minCadence[1])),
        ]
    }
    
    // MARK: - custom properties for Gait
    let ALPHA:Float = 0.9
    var STEP_THRESHOLD:Float = 10000
    
    var prevMaxTime:[Float] = [0, 0]
    var prevGyroFiltered:[Float] = [0, 0]
    var goAbvThres:[Bool] = [false, false]
    var deadCounter:[Int] = [0, 0]
    var countStep:[Int] = [0, 0]
    var maxFilValue:[Float] = [0, 0]
    var currentMaxTime:[Float] = [0, 0]
    var isFindingMax:[Bool] = [false, false]
    var legStartTime:[Float] = [0, 0]
    var totalStrideTime:[Float] = [0, 0]
    var totalStrideTimeSq:[Float] = [0, 0]
    var meanStrideTime:[Float] = [0, 0]
    var maxStrideTime:[Float] = [0, 0]
    var minStrideTime:[Float] = [100, 100]
    var cadence:[Float] = [0, 0]
    var maxCadence:[Float] = [0, 0]
    var minCadence:[Float] = [100, 100]
    var covOfvar:[Float] = [0, 0]

    var totalStepCount = 0
    var prevTotalStepCount = 0
    
    // MARK: - Assessment interface
    func updateAssessment(sensor: Sensor) 
    {
        guard let mwSensor = sensor as? MWIMU, mwSensor.type == .left || mwSensor.type == .right,
              let tfAcc = mwSensor.accelerometer.last, let tfGyro = mwSensor.gyroscope.last else {return}
        
        let side = mwSensor.type == .left ? 0 : 1
        doLegAnalysis(side: side, ay: tfAcc.data[1], gz: tfGyro.data[2], time: tfGyro.time)
    }
    
    func startRecording() 
    {
        prevMaxTime = [0, 0]
        prevGyroFiltered = [0, 0]
        goAbvThres = [false, false]
        deadCounter = [0, 0]
        countStep = [0, 0]
        maxFilValue = [0, 0]
        currentMaxTime = [0, 0]
        isFindingMax = [false, false]
        legStartTime = [0, 0]
        totalStrideTime = [0, 0]
        totalStrideTimeSq = [0, 0]
        meanStrideTime = [0, 0]
        covOfvar = [0, 0]
        totalStepCount = 0
        prevTotalStepCount = 0
        
        maxStrideTime = [0, 0]
        minStrideTime = [100, 100]
        cadence = [0, 0]
        maxCadence = [0, 0]
        minCadence = [100, 100]
    }
    
    func stopRecording(outputPrefix:String = "") 
    {
        // save summary data to CSV file
        if !outputPrefix.isEmpty {
            let csvData = csvSummary()
            CSVWriter.save(body: csvData, filename: "\(outputPrefix)_Summary.csv")
        }
    }
    
    // MARK: - Gait specific
    /// estimate gait parameters
    /// - parameter side: 0 is left, 1 is right
    /// - parameter ay: accelerator y-axis
    /// - parameter gz: gyroscope z-axis
    /// - parameter time: relative time in millisecond
    func doLegAnalysis(side:Int, ay:Float, gz:Float, time: Int)
    {
        let gyroZ_value = side == 0 ? max(-gz,0) : max(gz,0)
        
        let gyroFiltred = (prevGyroFiltered[side] * ALPHA) + (gyroZ_value * (1 - ALPHA))
        prevGyroFiltered[side] = gyroFiltred
        let gyroFiltredSq = gyroFiltred * gyroFiltred
        
        if gyroFiltredSq > STEP_THRESHOLD && !goAbvThres[side] && deadCounter[side] == 0 && ay < 100000 {
            countStep[side] += 1
            deadCounter[side] += 1
            goAbvThres[side] = true
        }
        else if gyroFiltredSq < STEP_THRESHOLD && goAbvThres[side] {
            goAbvThres[side] = false
            maxFilValue[side] = 0
        }
        
//        if gyroFiltredSq > STEP_THRESHOLD && goAbvThres[side] {
        if goAbvThres[side] {
            if abs(gyroZ_value) > maxFilValue[side] {
                maxFilValue[side] = gyroZ_value
                currentMaxTime[side] = roundf(Float(time)/1000*100)/100
            }
            isFindingMax[side] = true
        }
        
//        if gyroFiltredSq < STEP_THRESHOLD && isFindingMax[side] {
        if !goAbvThres[side] && isFindingMax[side] {
            isFindingMax[side] = false
            
            if countStep[side] == 1 {
                legStartTime[side] = currentMaxTime[side]
            }
            else if countStep[side] > 1
            {
                Utils.log("currentMaxTime[\(side)]: \(currentMaxTime[side])")
                let strideTime = currentMaxTime[side] - prevMaxTime[side]
                totalStrideTime[side] += strideTime
                totalStrideTimeSq[side] += strideTime * strideTime //pow(rightStrideTime, 2)
                meanStrideTime[side] = totalStrideTime[side] / Float(countStep[side] - 1)
                maxStrideTime[side] = max(strideTime, maxStrideTime[side])
                minStrideTime[side] = min(strideTime, minStrideTime[side])
                
                //Calculate to the current mean
                let meanStrideTime = totalStrideTime[side] / Float(countStep[side])
                
                //Calculate to the current SD
                let sdStrideTime = (totalStrideTimeSq[side] / Float(countStep[side])) - (meanStrideTime*meanStrideTime)
                covOfvar[side] = sdStrideTime / meanStrideTime
                
                // Calculate cadence
                cadence[side] = (Float(countStep[side] - 1) / totalStrideTime[side]) * 60 * 2
                maxCadence[side] = max(cadence[side], maxCadence[side])
                minCadence[side] = min(cadence[side], minCadence[side])
            }
            prevMaxTime[side] = currentMaxTime[side]
        }
        
        if deadCounter[side] > 0 {
            deadCounter[side] += 1
            if deadCounter[side] > 30 {
                deadCounter[side] = 0
            }
        }
        
        totalStepCount = countStep[0] + countStep[1]
        if totalStepCount != prevTotalStepCount {
            Utils.log("countLeftStep: \(countStep[0]), countRightStep: \(countStep[1]), totalStepCount: \(totalStepCount)")
        }
        prevTotalStepCount = totalStepCount
    }
    
    func csvSummary()->[String]
    {
        [
            String(format: "No. of Left steps, %i steps", countStep[0]),
            String(format: "No. of Right steps, %i steps", countStep[1]),
            String(format: "Total steps, %i steps", totalStepCount),
            String(format: "Mean stride time, %.2f s", (totalStrideTime[1]/Float(countStep[1]-1))),
            String(format: "Max stride period, %.2f s", maxStrideTime[1]),
            String(format: "Min stride time, %.2f s", minStrideTime[1]),
            String(format: "Mean cadence, %.2f steps/minute", cadence[1]),
            String(format: "Max cadence, %.2f steps/minute", maxCadence[1]),
            String(format: "Min cadence, %.2f steps/minute", minCadence[1]),
            //String(format: "Left Leg coefficient of variation, %.2f", covOfvar[0]),
            //String(format: "Right Leg coefficient of variation, %.2f", covOfvar[1])
        ]
    }
}
