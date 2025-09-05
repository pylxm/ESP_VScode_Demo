//
//  Camera.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import AVFoundation
import UIKit

protocol RecordingDelegate:AnyObject
{
    /// update recording timer with current time string
    func recordingTimer(currentTime:String)
}

extension RecordingDelegate {
    /// update tick count and recoding timer. Each tick = 1 second
    func recordingTimer(tick: Int)
    {
        let currentTime = String(format:"%02d:%02d", tick / 60, tick % 60)
        self.recordingTimer(currentTime: currentTime)
    }
}

class Camera: NSObject, AVCaptureFileOutputRecordingDelegate
{
    var device : AVCaptureDevice
    var session : AVCaptureSession
    var input : AVCaptureDeviceInput
    var recordingOutput = AVCaptureMovieFileOutput()
    
    var isRecording:Bool = false
//    var isConfiguring:Bool = false
    weak var timer:Timer?
    weak var cameraDelegate:RecordingDelegate?
    var fps:Int = 0
    
    let cameraQueue = DispatchQueue(label: "cameraSetup")
    
    init(sessionPreset:AVCaptureSession.Preset, fpsRequested:Int)
    {
        Utils.log("Starting cam")
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        session = AVCaptureSession()
        input = try! AVCaptureDeviceInput(device: device)
        
        session.beginConfiguration()
        session.addInput(input)
        session.sessionPreset = sessionPreset
        super.init()
        
        var bestFrameRate = 0
        var bestVFormat:AVCaptureDevice.Format!
        for vFormat in device.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            
            if isSatisfyCameraFormat(vFormat) {
                if bestFrameRate < Int(frameRates.maxFrameRate) {
                    bestFrameRate = Int(frameRates.maxFrameRate)
                    bestVFormat = vFormat
                }
                if bestFrameRate >= fpsRequested {
                    setVideoFPS(frameRate: fpsRequested, format: vFormat)
                    break
                }
            }
        }
        // next best frame rate if unable to get requested frame rate
        if fps == 0 && bestFrameRate > 0 {
            setVideoFPS(frameRate: bestFrameRate, format: bestVFormat)
        }
        
        if session.canAddOutput(recordingOutput) {
            session.addOutput(recordingOutput)
            if let videoDataOuputConnection = recordingOutput.connection(with: .video) {
                recordingOutput.setRecordsVideoOrientationAndMirroringChangesAsMetadataTrack(true, for: videoDataOuputConnection)
            }
        }
        
        Utils.log("Device frame rate: \(device.activeVideoMaxFrameDuration.timescale) - \(device.activeVideoMinFrameDuration.timescale)")
        cameraQueue.async {
            self.session.commitConfiguration()
            Utils.log("camera commited configuration")
            self.session.startRunning()
            Utils.log("camera start running session")
        }
    }
    
    /// set video format at specific frame rate
    /// - parameter frameRate: Frame per second
    /// - parameter format: video format
    func setVideoFPS(frameRate:Int, format:AVCaptureDevice.Format)
    {
        fps = frameRate
        Utils.log("\(format.description)")
        do {
            try device.lockForConfiguration()
            Utils.log("Setting frame rate: \(frameRate)")
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            device.unlockForConfiguration()
        }
        catch {
            Utils.log("Setting frame rate \(frameRate) error!")
        }
    }
    
//    func start()
//    {
//        cameraQueue.async {
//            self.session.startRunning()
//        }
//    }
    
//    func stop()
//    {
//        session.stopRunning()
//    }
    
    /// start recording with output sent to filepath folder and fileName as prefix
    func startRecording(exercise:Exercise)
    {
        let videoDataOuputConnection = recordingOutput.connection(with: .video)
        let isPortrait = (UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height)
        videoDataOuputConnection!.videoOrientation = isPortrait ? .portrait : .landscapeRight

        let videoURL = Settings.shared.fileManager.newURL(withName: exercise.videoFileName)
        recordingOutput.startRecording(to: videoURL, recordingDelegate: self)
        
        isRecording = true
        recordingTimer(currentTick: 0)
    }

    func stopRecording()
    {
        timer?.invalidate()
        isRecording = false
        recordingOutput.stopRecording()
    }

    /// tick counting while recording
    private func recordingTimer(currentTick:Int)
    {
        cameraDelegate?.recordingTimer(tick: currentTick)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) {
            [weak self] _ in
            self?.recordingTimer(currentTick: currentTick + 1)
        }
    }
    
    ///  delegate to show video file saving status
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?)
    {
        if let err = error {
            Utils.log("Recording output error \(err.localizedDescription) for \(outputFileURL)")
        }
        else {
            Utils.log("Recording finished for \(outputFileURL.lastPathComponent)")
        }
    }
    
    /// check if format meets all requirements
    private func isSatisfyCameraFormat(_ format: AVCaptureDevice.Format) -> Bool
    {
        if #available(iOS 13.0, *) {
            return
                format.formatDescription.dimensions.height == 1080 &&
                format.formatDescription.dimensions.width == 1920
        }
        else {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return
                dimension.height == 1080 &&
                dimension.width == 1920
        }
    }
}
