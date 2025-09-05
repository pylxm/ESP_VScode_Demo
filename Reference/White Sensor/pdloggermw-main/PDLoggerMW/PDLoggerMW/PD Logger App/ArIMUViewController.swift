//
//  SensorViewController.swift
//  PDLoggerMW
//
//  Created by Rio on 14/11/24.
//

import UIKit
import AVKit

class ArIMUViewController: UIViewController, UITextFieldDelegate, RecordingDelegate, SensorDelegate
{ 
    var camera:Camera!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var liveStackViewBox: UIView!
    @IBOutlet weak var liveInfoStackView: UIStackView!
    
    @IBOutlet weak var recordButtonLabel: UIButton!
    @IBOutlet weak var recordTimeLabel: UILabel!
    var recordButton:RecordButton!

    @IBOutlet weak var neckStatusLabel: UILabel!
    @IBOutlet weak var leftLimbStatusLabel: UILabel!
    @IBOutlet weak var rightLimbStatusLabel: UILabel!
    @IBOutlet weak var backButtonLabel: UIBarButtonItem!
    
    // exercise
    var exercise:Exercise!
    
    /// dictionary of label to value for liveStackView
    var liveStackLabels:[String:UILabel] = [:]
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // set up camera
        setupCameraSession()
        
        // set up recording button
        recordButton = RecordButton()
        recordButtonLabel.layer.addSublayer(recordButton)
        recordTimeLabel.text = ""
        
        // set up sensor status label
        let sensorsRequired = Settings.shared.patient.assessment.sensorTypeRequired
        neckStatusLabel.isHidden = sensorsRequired.contains(.neck) ? false : true
        leftLimbStatusLabel.isHidden = sensorsRequired.contains(.left) ? false : true
        rightLimbStatusLabel.isHidden = sensorsRequired.contains(.right) ? false : true
        
        sensorsRequired
            .compactMap{type in Settings.shared.sensors[type]}
            .forEach{sensor in sensorUpdateStatus(sensor: sensor)}
    }
    
    /// configure and start camera with previewLayer
    func setupCameraSession()
    {
        let fpsRequest = 30
        
        camera = Camera(sessionPreset: .high, fpsRequested: fpsRequest)
        camera.cameraDelegate = self
//        camera.start()

        previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = cameraView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        cameraView.layer.sublayers?.forEach{$0.removeFromSuperlayer()}
        cameraView.layer.addSublayer(previewLayer)
    }
    
    @IBAction func recordButtonPressed(_ sender: UIButton) 
    {
        if !recordButton.isRecording {
            Utils.log("start recording")
            backButtonLabel.isEnabled = false
            liveInfoStackViewInit()
            recordButton.buttonTapped()
            recordTimeLabel.text = "00:00"
            
            exercise = Exercise(patient: Settings.shared.patient)
            for var sensor in exercise.sensors {
                sensor.delegate = self
            }
            exercise.start()
            camera.startRecording(exercise: exercise)
        }
        else {
            Utils.log("end recording")
            backButtonLabel.isEnabled = true
            recordButton.buttonUntapped()
            
            camera.stopRecording()
            exercise.end()
            for var sensor in exercise.sensors {
                sensor.delegate = nil
            }
            showCurrentSummary()
//            exercise = nil
        }
    }
    
    func showCurrentSummary()
    {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "CsvVc") as? CsvViewController {
            vc.filePath = URL(fileURLWithPath: Settings.shared.fileRootPath).appendingPathComponent("\(exercise.filenamePrefix)_Summary.csv")
            exercise = nil
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    func recordingTimer(currentTime: String) 
    {
        Utils.log("Current recording time: \(currentTime)")
        recordTimeLabel.text = "Rep \(Settings.shared.patient.nextRep) - \(currentTime)"
    }
    
    // MARK: - Live View
    /// set up liveStackView with labels according to AR setting
    func liveInfoStackViewInit()
    {
        if liveInfoStackView.subviews.isEmpty {
            liveStackViewBox.layer.cornerRadius = 8.0
            Settings.shared.patient.assessment.listData.forEach{ assignLabelsToLiveStackView(title:$0.key) }
        }
        else {  // clear values
            for (key,label) in liveStackLabels {
                label.text = key
            }
        }
    }
    
    /// add label in liveInfoStackView
    /// - Parameter title: new label title
    func assignLabelsToLiveStackView(title:String)
    {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: liveInfoStackView.frame.width, height: 50))
        label.textAlignment = .left
        label.text = title
        if UIDevice.current.userInterfaceIdiom == .phone {
            label.font.withSize(3.0)
        }
        else {
            label.font.withSize(14.0)
        }
        label.textColor = .white
        label.numberOfLines = 10
        label.minimumScaleFactor = 0.5
        
        liveInfoStackView.addArrangedSubview(label)
        liveStackLabels[title] = label
    }
    
    /// update live info with key data map
    /// - Parameter keyData: dictionary with label text as key for updating the data to liveInfoStackView
    func updateLiveInfo(keydata:[(key:String,data:Any)] ) {
        DispatchQueue.main.async
        {
            for (key, data) in keydata {
                if let label = self.liveStackLabels[key] {
                    if let floatData = data as? Float {
                        label.text = String(format: "%@: %.2f", key, floatData)
                    }
                    else if let intData = data as? Int {
                        label.text = String(format: "%@: %d", key, intData)
                    }
                    else if let stringData = data as? String {
                        label.text = String(format: "%@: %@", key, stringData)
                    }
                }
            }
        }
    }
    
    @IBAction func toggleLiveInfo(_ sender: UIButton)
    {
        let alreadyHidden = liveInfoStackView.isHidden
        liveInfoStackView.isHidden = !alreadyHidden
        liveStackViewBox.isHidden = !alreadyHidden
        sender.tintColor = alreadyHidden ? .cyan : .darkGray
    }
    
    // MARK: - Back button
    @IBAction func backButtonPressed(_ sender: Any)
    {
        // disconnect MetaWear sensors
        for type in Settings.shared.patient.assessment.sensorTypeRequired {
            if let mwSensor = Settings.shared.sensors[type] as? MWIMU {
                mwSensor.disconnect()
            }
        }
        
        let participantVCIndex = self.navigationController!.viewControllers.count - 3 // return to participant view instead of the previous page
        self.navigationController?.popToViewController(self.navigationController!.viewControllers[participantVCIndex], animated: true)
 
    }
    
    // MARK: - Summary button
    @IBAction func summaryButtonPressed(_ sender: Any)
    {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SummaryViewController") as? SummaryViewController {
             vc.modalPresentationStyle = .fullScreen // Set to fullscreen
             // vc.modalTransitionStyle = .partialCurl
            self.present(vc, animated: true , completion: nil)
        }
    }
    
    // MARK: - Sensor updates
    func sensorUpdateStatus(sensor: Sensor) {
        let connectedColor = UIColor(red: 0.13, green: 0.85, blue: 0.15, alpha: 1.0)
        let disconnectedColor = UIColor(red: 0.976, green: 0.412, blue: 0.055, alpha: 1.0)
        DispatchQueue.main.async {
            switch sensor.type {
            case .neck: 
                self.neckStatusLabel.textColor = sensor.status == .connected ? connectedColor : disconnectedColor
                self.neckStatusLabel.text = "Neck(\(sensor.batteryLevel)%)"
            case .left:
                self.leftLimbStatusLabel.textColor = sensor.status == .connected ? connectedColor : disconnectedColor
                self.leftLimbStatusLabel.text = "Left(\(sensor.batteryLevel)%)"
            case .right:
                self.rightLimbStatusLabel.textColor = sensor.status == .connected ? connectedColor : disconnectedColor
                self.rightLimbStatusLabel.text = "Right(\(sensor.batteryLevel)%)"
            }
            
            if self.recordButton.isRecording && sensor.status == .notConnected {
                let okAction = UIAlertAction(title: "Stop", style: .default) {_ in
                    self.recordButtonPressed(self.recordButtonLabel)
                }
                Utils.alert(self, title: "Sensor Disconnected", message: "Sensor \(sensor.type.text) is disconnected. Please retake", actions: [okAction])
            }
        }
    }
    
    func sensorUpdateData(sensor: Sensor) {
        if let exercise = self.exercise {
            exercise.assessment.updateAssessment(sensor: sensor)
            updateLiveInfo(keydata: exercise.assessment.listData)
        }
    }
}
