//
//  Assessment.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation

protocol Assessment
{
    // label for selection
    var name:String {get set}
    // part of file name
    var fileNameComponent:String {get set}
    // type of sensors required for this assessment
    var sensorTypeRequired:[Settings.SensorType] {get set}
    // snapshot list of data in float array
    var listData:[(key:String,data:Any)] {get}
    
    // function to compute assessment parameters based on sensor data
    func updateAssessment(sensor:Sensor)
    func startRecording()
    func stopRecording(outputPrefix:String)
    func csvSummary()->[String]
}

extension Assessment
{
    func csvSummary()->[String] {[]}
}
