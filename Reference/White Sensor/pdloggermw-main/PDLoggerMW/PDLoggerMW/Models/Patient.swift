//
//  Patient.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation

class Patient
{
    var id:String
    var assessment:Assessment
    var nextRep:Int
    var assessmentRecords:[[String]]
    var assessmentDates:[Date]
    
    init(id: String, assessment: Assessment, nextRep: Int = 1)
    {
        self.id = id
        self.assessment = assessment
        self.nextRep = nextRep
        self.assessmentRecords = []
        self.assessmentDates = []
        
        // initialize folder for patient
        Settings.shared.patient = self
        Settings.shared.fileManager.createFolder(path: Settings.shared.fileRootPath)
    }
}
