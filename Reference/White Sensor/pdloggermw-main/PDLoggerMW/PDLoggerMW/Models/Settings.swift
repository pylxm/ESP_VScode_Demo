//
//  Settings.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation
import MetaWear
import MetaWearCpp

struct Settings
{
    static var shared = Settings()
    
    var user:User
    
    // sensor types supported
    enum SensorType:Int, CaseIterable {
        case neck=0, left=1, right=2  // IMU sensors
        var text:String {"\(self)"}
    }
    var sensors:[SensorType:Sensor]

    var patient:Patient!
    var assessments:[Assessment]
    
    var fileManager = FilesManager()
    var fileRootPath:String {
        String(format: "%@/%@", fileManager.documentsDirectory.path, patient.id)
    }
    
    init()
    {
        user = User(name: UserDefaults.standard.string(forKey: "username") ?? "me",
                         passwordHash: UserDefaults.standard.string(forKey: "passwordHash") ?? "me",
                         passwordHint: UserDefaults.standard.string(forKey: "passwordHint") ?? "me")
        
        // load sensor id
        sensors = [
            .neck: MWIMU(type: .neck, id: UserDefaults.standard.string(forKey: "sensorNeck") ?? "", fileNameComponent: "1", ledColor: MBL_MW_LED_COLOR_RED),
            .left: MWIMU(type: .left, id: UserDefaults.standard.string(forKey: "sensorLeft") ?? "", fileNameComponent: "2", ledColor: MBL_MW_LED_COLOR_GREEN),
            .right: MWIMU(type: .right, id: UserDefaults.standard.string(forKey: "sensorRight") ?? "", fileNameComponent: "3", ledColor: MBL_MW_LED_COLOR_BLUE),
        ]
        
        // load assessments
        assessments = [
            StandingPostureCapture(),
            A7mTUG(),
            FreeWalk(),
            A10mW(),
            HeelTapping(.left),
            HeelTapping(.right)
        ]
    }
    
    func saveUser()
    {
        UserDefaults.standard.setValue(user.name, forKey: "username")
        UserDefaults.standard.setValue(user.passwordHash, forKey: "passwordHash")
        UserDefaults.standard.setValue(user.passwordHint, forKey: "passwordHint")
    }
    
    func saveSensor()
    {
        UserDefaults.standard.setValue((sensors[.neck] as? MWIMU)?.id ?? "", forKey: "sensorNeck")
        UserDefaults.standard.setValue((sensors[.left] as? MWIMU)?.id ?? "", forKey: "sensorLeft")
        UserDefaults.standard.setValue((sensors[.right] as? MWIMU)?.id ?? "", forKey: "sensorRight")
    }
}
