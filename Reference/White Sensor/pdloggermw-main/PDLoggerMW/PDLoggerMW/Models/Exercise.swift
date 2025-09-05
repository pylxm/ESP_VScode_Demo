//
//  Exercise.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation

struct Exercise
{
    var patient:Patient
    var assessment:Assessment {
        patient.assessment
    }
    // list of sensors used in exercise
    var sensors:[Sensor] {
        assessment.sensorTypeRequired
            .compactMap{type in Settings.shared.sensors[type]}
    }
    var repNo: Int
    var startDate:Date!
    var assessmentRecord:[String] = []
    
    // MARK: - output file names
    var fileDateFormatter = DateFormatter()
    var filenamePrefix: String {
        String(format: "%@__%@_%d_run%@", patient.id, assessment.fileNameComponent, repNo, fileDateFormatter.string(from: startDate))
    }
    var videoFileName: String {
        filenamePrefix + ".mp4"
    }
    
    init(patient: Patient)
    {
        self.patient = patient
        self.repNo = patient.nextRep
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH_mm"
    }
    
    mutating func start()
    {
        startDate = Date()
        // trigger recording of assessment data
        assessment.startRecording()
        
        // trigger recording of sensor data
        for sensor in sensors {
            sensor.startRecording()
        }
    }
    
    func end()
    {
        // summarise exercise
        assessment.stopRecording(outputPrefix: filenamePrefix)
        
        // save output of exercise and sensors to file
        for sensor in sensors {
            sensor.stopRecording(outputPrefix: filenamePrefix)
        }

        // prepare for next repetition
        patient.assessmentRecords.append(assessment.csvSummary())
        patient.assessmentDates.append(startDate)
        patient.nextRep = repNo + 1
    }
    
    func nameSuffix(_ suffix:String)->String
    {
        String(format: "%@_%@.csv", filenamePrefix, suffix)
    }
}
