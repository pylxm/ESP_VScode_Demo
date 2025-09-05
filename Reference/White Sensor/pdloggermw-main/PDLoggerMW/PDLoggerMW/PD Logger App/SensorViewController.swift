//
//  SensorViewController.swift
//  PDLoggerMW
//
//  Created by Rio on 14/11/24.
//

import UIKit

class SensorViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var selectedIdLabel: UILabel!
    @IBOutlet var selectedAssessmentTypeLabel: UILabel!
    @IBOutlet var leftLimbSensorButton: UIButton!
    @IBOutlet var rightLimbSensorButton: UIButton!
    @IBOutlet var neckSensorButton: UIButton!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var okButton: UIButton!
    let sensors = Settings.shared.sensors
    var sensorChanged:Bool = false
 
    override func viewDidLoad()
    {
        super.viewDidLoad()
        selectedIdLabel.text = Settings.shared.patient.id
        selectedAssessmentTypeLabel.text = Settings.shared.patient.assessment.name
        
        // Initialise sensor type and button map
        let sensorButton:[Settings.SensorType:UIButton] = [
            .left: leftLimbSensorButton,
            .right: rightLimbSensorButton,
            .neck: neckSensorButton
        ]
        for button in sensorButton.values {
            button.isHidden = true
            button.isEnabled = false
        }
        
        // round buttons
        [cancelButton, okButton, leftLimbSensorButton, rightLimbSensorButton, neckSensorButton].forEach { button in
            button.layer.cornerRadius = button.frame.height * 0.2
        }
        
        // Initialise the button label
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            if let button = sensorButton[type], let mwSensor = sensors[type] as? MWIMU {
                button.layer.backgroundColor = UIColor.systemGray.cgColor
                
                setMWSensorLabel(mwSensor, button: button)
                button.isHidden = false
                button.isEnabled = true
            }
        }
        
        // Connect saved MetaWear sensor
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            if let mwSensor = sensors[type] as? MWIMU, mwSensor.id != "" {
                mwSensor.fetchSavedMetawear {
                    DispatchQueue.main.async {
                        // change button color when connected successfully
                        sensorButton[type]?.layer.backgroundColor = UIColor.green.cgColor
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                        guard let button = sensorButton[type] else {return}
                        if mwSensor.batteryLevel != 0 {  // connected and found battery level
                            self.setMWSensorLabel(mwSensor, button: button)
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func pickLeftSensor(_ sender: UIButton)
    {
        pickMetawearSensor(.left, button: sender)
    }
    
    @IBAction func pickRightSensor(_ sender: UIButton)
    {
        pickMetawearSensor(.right, button: sender)
    }
    
    @IBAction func pickNeckSensor(_ sender: UIButton)
    {
        pickMetawearSensor(.neck, button: sender)
    }
    
    func pickMetawearSensor(_ type: Settings.SensorType, button: UIButton)
    {
        guard let mwSensor = sensors[type] as? MWIMU else {return}
        // set button to gray and disabled while scanning begin
        button.layer.backgroundColor = UIColor.systemGray.cgColor
        button.isEnabled = false
        sensorChanged = true
        
        mwSensor.resetConnection(forget: true)
        mwSensor.scan {
            DispatchQueue.main.async {
                // change button color when connected successfully
                button.layer.backgroundColor = UIColor.green.cgColor
            }
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { [weak self] in
                guard let self = self else {return}
                self.setMWSensorLabel(mwSensor, button: button)
            }
        }
        
        var counter = 10 // no of seconds to wait for scan
        Utils.alert(self, title: "Scan", message: "Scanning for \(type.text) Metawear sensor. If not found after \(counter) seconds, please retry")

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            counter = counter - 1
            Utils.log("\(type.text) scan: \(counter)")
            if mwSensor.status == .connected || counter == 0 {
                DispatchQueue.main.async {
                    button.isEnabled = true
                }
                timer.invalidate()
                mwSensor.stopScan()
                // dismiss alert controller if still being presented at end of scanning
                if self.presentedViewController is UIAlertController {
                    self.dismiss(animated: true)
                }
            }
        }
    }
    
    func setMWSensorLabel(_ mwSensor:MWIMU, button:UIButton)
    {
        if mwSensor.id == "" {  // not registered
            button.setTitle("N/A", for: .normal)
        }
        else if mwSensor.batteryLevel != 0 {  // found battery level
            button.setTitle("\(mwSensor.batteryLevel)%", for: .normal)
        }
        else { // without battery level info
            button.setTitle(mwSensor.type.text.capitalized, for: .normal)
        }
        Utils.log("Battery level for \(mwSensor.type.text) sensor:\(mwSensor.batteryLevel)%")
    }
    
    @IBAction func exitSave(_ sender: UIButton)
    {
        // if any required sensor is not connected, do nothing
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            if let sensor = sensors[type], sensor.status == .notConnected {
                return
            }
        }
        
        Settings.shared.saveSensor()
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            if let sensor = sensors[type] as? MWIMU, sensor.status == .connected {
                sensor.startMetering()
            }
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ArIMUViewController") as? ArIMUViewController {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func exitWithoutSaving(_ sender: UIButton)
    {
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            (sensors[type] as? MWIMU)?.disconnect()
        }
        
        self.navigationController?.popViewController(animated: true)
    }
    
}
