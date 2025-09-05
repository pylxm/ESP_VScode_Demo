//
//  MWIMU.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation
import MetaWear
import MetaWearCpp

class MWIMU:Sensor
{
    weak var delegate: SensorDelegate?
    
    var type: Settings.SensorType
    var status: SensorStatusType
    var batteryLevel: Int
    var fileNameComponent: String
    var csvHeader: String = "sensor time,gyro[0],gyro[1],gyro[2],acc[0],acc[1],acc[2],mag[0],mag[1],mag[2],yaw,pitch,roll"
    var csvData: [String] {
        accGyroMag.map { v in v.text() }
    }
    
    // MARK: - custom properties for MetaWear
    var id:String                // peripheral UUID of MetaWear sensor
    var ledColor: MblMwLedColor  // color to blink for connection indication
    var device:MetaWear!         // MetaWear peripheral
    
    // bridging data for C closure required for Metawear API to refer to self instance
    class BridgeData {
        var mwSensor: MWIMU
        init(mwSensor: MWIMU) {
            self.mwSensor = mwSensor
        }
    }
    lazy var bdPacks = BridgeData(mwSensor: self)
    var streamingCleanup:[OpaquePointer:()->()] = [:]
    
    enum MeterType {
        case accelerometer, gyroscope, magnetometer, quaternion, eulerAngle
        var text: String { "\(self)" }
    }
    
    // data collections
    struct TF {
        var time:Int
        var data:[Float]
    }
    
    var startTime:Date = Date()
    var accelerometer:[TF] = []
    var gyroscope:[TF] = []
    var magnetometer:[TF] = []
    var quaternion:[TF] = []
    var eulerAngle:[TF] = []

    var isRecording:Bool = false
    
    // merged data set
    struct TAGM {
        var time:Int  // time in millisecond
        var ax,ay,az:Float!
        var gx,gy,gz:Float!
        var mx,my,mz:Float!
        var qw,qx,qy,qz:Float!
        var ey,ep,er:Float!
        
        func text()->String
        {
            String(format: "%.3f,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@",
                   Float(time)*0.001, FtoStr(gx), FtoStr(gy), FtoStr(gz),
                   FtoStr(ax), FtoStr(ay), FtoStr(az),
                   FtoStr(mx), FtoStr(my), FtoStr(mz),
                   FtoStr(ey), FtoStr(ep), FtoStr(er))
        }
        
        /// convert optional float to string with 2 decimal
        func FtoStr(_ optNum: Float?) -> String
        {
            optNum != nil ? String(format: "%.2f", optNum!) : ""
        }
        
    }
    var accGyroMagRaw:[TAGM] = []
    var accGyroMag:[TAGM] = []
    
    
    // MARK: - Sensor interface
    func connect()
    {
        if !id.isEmpty && status == .notConnected  {
            fetchSavedMetawear {
                self.startMetering()
            }
        }
    }
    
    func disconnect() 
    {
        stopMetering()
        resetConnection(forget: false)
    }
    
    /// Reset clock and meter data array, then start data collection
    func startRecording()
    {
        accelerometer = []
        gyroscope = []
        magnetometer = []
        quaternion = []
        eulerAngle = []
        accGyroMag = []
        accGyroMagRaw = []
        startTime = Date()
        isRecording = true
        
        // check status every 1 sec until stop recording
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            timer in
            self.updateStatus()
            if !self.isRecording{
                timer.invalidate()
            }
        }
    }
    
    /// Stop data collection and merge data
    func stopRecording(outputPrefix:String = "")
    {
        isRecording = false
        mergeData()
        // reconnect any disconnected sensors for next recording use
        reconnect()
        
        // save data to CSV file
        if !outputPrefix.isEmpty && !csvData.isEmpty {
            CSVWriter.save(header: csvHeader, body: csvData, filename: String(format: "%@_%@.csv", outputPrefix, fileNameComponent))
        }
    }
    
    init(type: Settings.SensorType, id:String, status: SensorStatusType = .notConnected, batteryLevel: Int = 0, fileNameComponent: String, ledColor: MblMwLedColor)
    {
        self.type = type
        self.id = id
        self.status = status
        self.batteryLevel = batteryLevel
        self.fileNameComponent = fileNameComponent
        self.ledColor = ledColor
    }
    
    // MARK: - MetaWear specific
    /// Fetch saved Metawear device, connect
    /// - Parameter completion: closure to run after succesful connection
    func fetchSavedMetawear(completion: (()->Void)? )
    {
        Utils.log("Connecting \(type.text) device \(id)")
        
        // check if already connected
        if status == .connected {
            Utils.log("Already connected \(type.text) device \(id)")
            completion?()
        }
        else {
            // go through each saved device
            MetaWearScanner.shared.retrieveSavedMetaWearsAsync().continueOnSuccessWith { [weak self] deviceList in
                for device in deviceList {
                    if self?.id == device.peripheral.identifier.uuidString {
                        // attempt to connect
                        self?.connectMetawear(device: device) {
                            completion?()
                        }
                    }
                }
            }
        }
    }
    
    /// Scan for nearby MetaWear device, connect and save
    func scan(completion: (()->Void)? )
    {
        MetaWearScanner.shared.startScan(allowDuplicates: true) { [weak self] device in
            // We found a MetaWear board, see if it is close
            Utils.log("Found a \(device.name) device: RSSI = \(device.rssi)")
            if device.rssi < 0 && device.rssi > -70 {
               // Hooray! We found a MetaWear board, so stop scanning for more
               MetaWearScanner.shared.stopScan()
               // Connect to the board we found
                guard let self = self else {return}
                self.connectMetawear(device: device) {
                    device.remember()
                    Utils.log("Connected \(self.type.text) device \(self.id)")
                    completion?()
                }
            }
        }
    }
    
    /// Connect to a Metawear device
    /// - Parameter device: Metawear instance
    /// - Parameter completion: closure to run upon successful connection
    private func connectMetawear(device: MetaWear, completion: (()->Void)? )
    {
        device.connectAndSetup().continueWith { t in
            if let error = t.error {
                // Sorry we couldn't connect
                Utils.log("Connect to device failed: \(error)")
            }
            else {
                Utils.log("Connected to device \(String(describing: device.mac)) \(device.peripheral.identifier)")
                device.apiAccessQueue.async {
                    // increase bluetooth radio signal strength
                    mbl_mw_settings_set_tx_power(device.board, 4)
                    // blink LED to identify sensor
                    var pattern = MblMwLedPattern()
                    mbl_mw_led_load_preset_pattern(&pattern, MBL_MW_LED_PRESET_PULSE)
                    mbl_mw_led_stop_and_clear(device.board)
                    mbl_mw_led_write_pattern(device.board, &pattern, self.ledColor)
                    mbl_mw_led_play(device.board)
                }
                
                let seconds = 8.0
                device.apiAccessQueue.asyncAfter(deadline: .now() + seconds) {
                    mbl_mw_led_stop_and_clear(device.board)
                }
                
                // set connection state
                self.status = .connected
                // save device
                self.device = device
                self.id = device.peripheral.identifier.uuidString
                self.readBatteryLevel()
                
                completion?()
            }
        }
    }
    
    /// reset connection for Metawear device
    func resetConnection(forget:Bool)
    {
        if let device = self.device {
            device.apiAccessQueue.async {
                if self.status == .connected {
                    mbl_mw_debug_reset(device.board)
                }
            }
            // delay disconnect to clear apis in queue
            device.apiAccessQueue.asyncAfter(deadline: .now() + 1.0) {
                Utils.log("Cancel connection to \(self.type.text) sensor")
                device.cancelConnection()
                if forget {
                    device.forget()
                }
                self.status = .notConnected
            }
        }
    }
    
    /// reconnect all Metawear devices
    func reconnect()
    {
        if let device = self.device, status == .notConnected {
            connectMetawear(device: device) {
                Utils.log("Reconnected to \(self.type.text) sensor")
                self.updateStatus()
            }
        }
    }
    
    func updateStatus()
    {
        let newStatus:SensorStatusType = device.isConnectedAndSetup ? .connected : .notConnected
        if newStatus != status {
            delegate?.sensorUpdateStatus(sensor: self)
            status = newStatus
        }
    }
    
    /// Stop scanning for devices
    func stopScan()
    {
        MetaWearScanner.shared.stopScan()
    }
    
    /// read battery level
    func readBatteryLevel()
    {
        if let device = self.device {
            device.apiAccessQueue.async {
                let signal = mbl_mw_settings_get_battery_state_data_signal(device.board)!
                
                mbl_mw_datasignal_subscribe(signal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let state:MblMwBatteryState = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.batteryLevel = Int(state.charge)
                    Utils.log("Battery level for \(dataPackIn.mwSensor.type.text) sensor: \(state.charge)%")
                }
                mbl_mw_datasignal_read(signal)
                self.streamingCleanup[signal] = {
                    device.apiAccessQueue.async {
                        mbl_mw_datasignal_unsubscribe(signal)
                    }
                }
            }
        }
    }
    
    /// configure fusion mode
    func startFusion()
    {
        if let device = self.device {
            device.apiAccessQueue.async {
                // set fusion mode and ranges
                mbl_mw_sensor_fusion_set_mode(device.board, MBL_MW_SENSOR_FUSION_MODE_NDOF)
                mbl_mw_sensor_fusion_set_acc_range(device.board, MBL_MW_SENSOR_FUSION_ACC_RANGE_4G)
                mbl_mw_sensor_fusion_set_gyro_range(device.board, MBL_MW_SENSOR_FUSION_GYRO_RANGE_2000DPS)
                
                // subscribe to data signal
                let accSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_ACC)!
                mbl_mw_datasignal_subscribe(accSignal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let accelerometer: MblMwCorrectedCartesianFloat = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.addMeterData(.accelerometer, time: obj!.pointee.timestamp, record: MblMwCartesianFloat(x: accelerometer.x, y: accelerometer.y, z: accelerometer.z))
                }
                let gyroSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_GYRO)!
                mbl_mw_datasignal_subscribe(gyroSignal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let gyroscope: MblMwCorrectedCartesianFloat = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.addMeterData(.gyroscope, time: obj!.pointee.timestamp, record: MblMwCartesianFloat(x: gyroscope.x, y: gyroscope.y, z: gyroscope.z))
                }
                let magSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_MAG)!
                mbl_mw_datasignal_subscribe(magSignal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let magnetometer: MblMwCorrectedCartesianFloat = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.addMeterData(.magnetometer, time: obj!.pointee.timestamp, record: MblMwCartesianFloat(x: magnetometer.x, y: magnetometer.y, z: magnetometer.z))
                }
                let quatSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)!
                mbl_mw_datasignal_subscribe(quatSignal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let quaternion: MblMwQuaternion = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.addMeterData(.quaternion, time: obj!.pointee.timestamp, record: quaternion)
                }
                let eulerSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)!
                mbl_mw_datasignal_subscribe(eulerSignal, bridge(obj: self.bdPacks)) { (context, obj) in
                    let eulerAngle: MblMwEulerAngles = obj!.pointee.valueAs()
                    let dataPackIn : BridgeData = bridge(ptr: context!)
                    dataPackIn.mwSensor.addMeterData(.eulerAngle, time: obj!.pointee.timestamp, record: eulerAngle)
                }
                // enable data signal and start fusion
                mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
                mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_ACC)
                mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_GYRO)
                mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_CORRECTED_MAG)
                mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)
                mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)
                mbl_mw_sensor_fusion_write_config(device.board)
                mbl_mw_sensor_fusion_start(device.board)
                
                // clean up all in one
                self.streamingCleanup[accSignal] = {
                    device.apiAccessQueue.async {
                        mbl_mw_sensor_fusion_stop(device.board)
                        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
                        mbl_mw_datasignal_unsubscribe(accSignal)
                        mbl_mw_datasignal_unsubscribe(gyroSignal)
                        mbl_mw_datasignal_unsubscribe(magSignal)
                        mbl_mw_datasignal_unsubscribe(quatSignal)
                        mbl_mw_datasignal_unsubscribe(eulerSignal)
                    }
                }
            }
        }
    }
    
    /// Start meters in MetaWear sensor
    ///  either 3 individual meters or fusion
    func startMetering()
    {
        startFusion()
        Utils.log("MWDevice \(type.text) meter started")
    }
    
    /// Stop meters in MetaWear sensor
    func stopMetering()
    {
        while !streamingCleanup.isEmpty {
            streamingCleanup.popFirst()?.value()
        }
        Utils.log("MWDevice meter stopped")
    }

    /// When is recording, collect data through data signal subscription and append to corresponding meter data array
    /// - Parameter meter: meter type (accelerometer, gyroscope, magnetometer, quarternion, euler angle)
    /// - Parameter time: timestamp from sensor
    /// - Parameter record: 3-axis data from sensor
    func addMeterData(_ meter: MeterType, time: Date, record: Any)
    {
        if isRecording {
            switch meter {
            case .accelerometer:
                // output data in mm/s^2 unit, input is g
                let a = record as! MblMwCartesianFloat
                let f:Float = 9810.0 // *9.81m/s^2 * 1000mm/m
                let newRecord = TF(time: Int(time.timeIntervalSince(startTime)*1000), data: [a.x * f, a.y * f, a.z * f])
                accelerometer.append(newRecord)
            case .gyroscope:
                // output data in degree/sec, input is the same
                let g = record as! MblMwCartesianFloat
                let newRecord = TF(time: Int(time.timeIntervalSince(startTime)*1000), data: [g.x, g.y, g.z])
                gyroscope.append(newRecord)
            case .magnetometer:
                // output data in milli Gauss, input is micro Tesla
                let m = record as! MblMwCartesianFloat
                let f:Float = 10.0 // *1/10^6 T/uT * 10^4 G/T * 10^3 mG/G
                let newRecord = TF(time: Int(time.timeIntervalSince(startTime)*1000), data: [m.x * f, m.y * f, m.z * f])
                magnetometer.append(newRecord)
            case .quaternion:
                // input and output data has no unit
                let q = record as! MblMwQuaternion
                let newRecord = TF(time: Int(time.timeIntervalSince(startTime)*1000), data: [q.w, q.x, q.y, q.z])
                quaternion.append(newRecord)
            case .eulerAngle:
                // input and output data in degrees
                let e = record as! MblMwEulerAngles
                let newRecord = TF(time: Int(time.timeIntervalSince(startTime)*1000), data: [e.yaw, e.pitch, e.roll])
//                Utils.log("Time: \(newRecord.time) Euler Angle:\(e.yaw), \(e.pitch), \(e.roll)")
                eulerAngle.append(newRecord)
            }
            delegate?.sensorUpdateData(sensor: self)
        }
    }
    
    /// Merge data of accelerometer, gyroscope, magnetometer by time
    /// Update into instance variable:
    /// accGyroMagRaw :  actual sensor data merged in a sparse matrix with nil as missing value
    /// accGyroMag: interpolated sensor data merged in a 50-Hz or 20ms interval matrix without missing value
    func mergeData() {
        var buf:[Int:TAGM] = [:]

        if accelerometer.isEmpty || gyroscope.isEmpty || magnetometer.isEmpty {
            Utils.log("WARNING: Not enough data to merge on \(type.text) side")
            Utils.log("Accelerometer data count: \(accelerometer.count)")
            Utils.log("Gyroscope data count: \(gyroscope.count)")
            Utils.log("Magnetometer data count: \(magnetometer.count)")
        }
        else {
            accelerometer.forEach{ rec in
                if buf[rec.time] != nil {
                    buf[rec.time]?.ax = rec.data[0]
                    buf[rec.time]?.ay = rec.data[1]
                    buf[rec.time]?.az = rec.data[2]
                }
                else {
                    buf[rec.time] = TAGM(time: rec.time, ax:rec.data[0], ay:rec.data[1], az:rec.data[2])
                }
            }
            gyroscope.forEach{ rec in
                if buf[rec.time] != nil {
                    buf[rec.time]?.gx = rec.data[0]
                    buf[rec.time]?.gy = rec.data[1]
                    buf[rec.time]?.gz = rec.data[2]
                }
                else {
                    buf[rec.time] = TAGM(time: rec.time, gx:rec.data[0], gy:rec.data[1], gz:rec.data[2])
                }
            }
            magnetometer.forEach{ rec in
                if buf[rec.time] != nil {
                    buf[rec.time]?.mx = rec.data[0]
                    buf[rec.time]?.my = rec.data[1]
                    buf[rec.time]?.mz = rec.data[2]
                }
                else {
                    buf[rec.time] = TAGM(time: rec.time, mx:rec.data[0], my:rec.data[1], mz:rec.data[2])
                }
            }
            quaternion.forEach{ rec in
                if buf[rec.time] != nil {
                    buf[rec.time]?.qw = rec.data[0]
                    buf[rec.time]?.qx = rec.data[1]
                    buf[rec.time]?.qy = rec.data[2]
                    buf[rec.time]?.qz = rec.data[3]
                }
                else {
                    buf[rec.time] = TAGM(time: rec.time, qw:rec.data[0], qx:rec.data[1], qy:rec.data[2], qz:rec.data[3])
                }
            }
            eulerAngle.forEach{ rec in
                if buf[rec.time] != nil {
                    buf[rec.time]?.ey = rec.data[0]
                    buf[rec.time]?.ep = rec.data[1]
                    buf[rec.time]?.er = rec.data[2]
                }
                else {
                    buf[rec.time] = TAGM(time: rec.time, ey:rec.data[0], ep:rec.data[1], er:rec.data[2])
                }
            }
            // order by time
            let timeSequence = Array(buf.keys).sorted()
            accGyroMagRaw = []
            var maxTimeGap = 0
            var prevTime = 0
            for t in timeSequence {
                accGyroMagRaw.append(buf[t]!)
                if prevTime > 0 {
                    if (t - prevTime) > maxTimeGap {
                        maxTimeGap = t - prevTime
                    }
                }
                prevTime = t
            }
            Utils.log("\(type.text) sensor has \(timeSequence.count) data time from \(timeSequence[0]) to \(prevTime) with max time gap \(maxTimeGap) ms")
            
            // generate a uniform ranged data, starts from time when all readings are present each side
            // align to 50Hz (every 20ms)
            var rangeBegin:Int = max(accelerometer.first?.time ?? 0,
                                     gyroscope.first?.time ?? 0,
                                     magnetometer.first?.time ?? 0,
                                     quaternion.first?.time ?? 0,
                                     eulerAngle.first?.time ?? 0)
            rangeBegin = (((rangeBegin - 1) / 20) + 1 ) * 20
            var rangeEnd:Int = min(accelerometer.last?.time ?? Int.max,
                                   gyroscope.last?.time ?? Int.max,
                                   magnetometer.last?.time ?? Int.max,
                                   quaternion.last?.time ?? Int.max,
                                   eulerAngle.last?.time ?? Int.max)
            rangeEnd = (rangeEnd / 20) * 20
            
            var (ai, gi, mi, qi, ei) = (0, 0, 0, 0, 0)
            var axyz, gxyz, mxyz, qwxyz, eypr : TF?
            accGyroMag = []
            for t in stride(from: rangeBegin, through: rangeEnd, by: 20) {
                (ai, axyz) = interpolateTFArr(arr: accelerometer, initial_index: ai, time: t)
                (gi, gxyz) = interpolateTFArr(arr: gyroscope, initial_index: gi, time: t)
                (mi, mxyz) = interpolateTFArr(arr: magnetometer, initial_index: mi, time: t)
                (qi, qwxyz) = interpolateTFArr(arr: quaternion, initial_index: qi, time: t)
                (ei, eypr) = interpolateTFArr(arr: eulerAngle, initial_index: ei, time: t)
                accGyroMag.append(TAGM(time: t,
                                       ax: axyz?.data[0], ay: axyz?.data[1], az: axyz?.data[2],
                                       gx: gxyz?.data[0], gy: gxyz?.data[1], gz: gxyz?.data[2],
                                       mx: mxyz?.data[0], my: mxyz?.data[1], mz: mxyz?.data[2],
                                       qw: qwxyz?.data[0], qx: qwxyz?.data[1], qy: qwxyz?.data[2], qz: qwxyz?.data[3],
                                       ey: eypr?.data[0], ep: eypr?.data[1], er: eypr?.data[2]))
            }
        }
    }
    
    /// Linear interpolate of x to get y based on (x1,y1) and (x2,y2) where x1 < x2
    func interpolate(x1: Int, y1: Float, x2: Int, y2: Float, x: Int) -> Float
    {
        (y2-y1)/Float(x2-x1)*Float(x-x1) + y1
    }
    
    /// Linear interpolate of t -> (x,y,z) based on a pair of known t -> (x,y,z)
    ///  If input t is not within the interval, return nil
    func interpolateTF(d1:TF, d2:TF, time: Int) -> TF?
    {
        if d1.time == time {  // exactly on interval boundary
            return d1
        }
        if d1.time < time && time < d2.time {  // within interval, interpolate
            var mid = d1.data
            for i in 0..<mid.count {
                mid[i] = interpolate(x1: d1.time, y1: d1.data[i], x2: d2.time, y2: d2.data[i], x: time)
            }
            return TF(time: time, data: mid)
        }
        return nil
    }
    
    /// Linrear interpolate of t -> [Float] based on an array of t -> [Float]  and search from initial index
    /// Assume array is sorted by ascending time
    /// - returns: tuple of final index and [Float].  Nil for [Float] if beyond the range of whole array
    func interpolateTFArr(arr:[TF], initial_index: Int, time: Int) -> (Int, TF?)
    {
        var i = initial_index
        var xyz:TF?
        while xyz == nil && arr.count >= 2 && i < arr.count - 1 {
            xyz = interpolateTF(d1: arr[i], d2: arr[i+1], time: time)
            if xyz == nil {
                i += 1
            }
        }
        return (i, xyz)
    }

}
