//
//  Sensor.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation

/// base class for sensor
///
enum SensorStatusType {
    case connected, notConnected
}

protocol Sensor
{
    var type:Settings.SensorType {get set}
    var status:SensorStatusType {get set}
    var batteryLevel:Int {get set}
    var fileNameComponent:String {get set}
    var delegate: SensorDelegate? {get set}
    var csvHeader:String {get}
    var csvData:[String] {get}
    
    func connect()
    func disconnect()
    func startMeteting()
    func stopMetering()
    func startRecording()
    func stopRecording(outputPrefix:String)
}

extension Sensor
{
    func startMeteting() {}
    func stopMetering() {}
}

protocol SensorDelegate:AnyObject
{
    func sensorUpdateStatus(sensor:Sensor)
    func sensorUpdateData(sensor:Sensor)
}

extension SensorDelegate
{
    func sensorUpdateStatus(sensor:Sensor) {}
    func sensorUpdateData(sensor:Sensor) {}
}
