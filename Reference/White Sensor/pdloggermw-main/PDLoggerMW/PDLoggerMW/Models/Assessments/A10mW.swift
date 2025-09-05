//
//  A10mW.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation

class A10mW:FreeWalk
{
//    var listData: [(key:String,data:Any)] {
//        [
//        ]
//    }
//    
    // MARK: - custom properties for 10m Walk
    
    // MARK: - Assessment interface
//    override func updateAssessment(sensor: Sensor) {
//        super.updateAssessment(sensor: sensor)
//    }
//    
//    override func startRecording() {
//        super.startRecording()
//    }
//    
    override func stopRecording(outputPrefix:String = "") {
        super.stopRecording()
        
        // save summary data to CSV file
        if !outputPrefix.isEmpty {
            let csvData = csvSummary()
            CSVWriter.save(header: "\(name) summary", body: csvData, filename: "\(outputPrefix)_Summary.csv")
        }
    }
    
    // MARK: - 10m Walk specific
    override init() {
        super.init()
        name = "10 Meters Walk"
        fileNameComponent = "10_Meters_Walk"
    }
    
//    override func csvSummary() -> [String] {
//        // if have IRStart and IRStop, get the time interval as walk duration
//    }
}
