//
//  SwiftyTeeth.swift
//  SwiftyTeeth
//
//  Created by Basem Emara on 10/27/16.
//
//

import Foundation
import CoreBluetooth

open class SwiftyTeeth: NSObject {

    static let shared = SwiftyTeeth()
    
    fileprivate var scanChangesHandler: ((Device) -> Void)?
    fileprivate var scanCompleteHandler: (([Device]) -> Void)?

    fileprivate lazy var centralManager: CBCentralManager = {
        let instance = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.robotpajamas.SwiftyTeeth"))
        // Throwaway command to init CoreBluetooth (helps prevent timing problems)
        instance.retrievePeripherals(withIdentifiers: [])
        return instance
    }()

    // TODO: Hold a private set, and expose a list?
    open var scannedDevices = Set<Device>()
    
    // TODO: Should be a list? Can connect to > 1 device
    fileprivate var connectedDevices = [String:Device]()

    
    // TODO: Need iOS 9 support
//    open var state: CBManagerState {
//        return centralManager.state
//    }

    open var isScanning: Bool {
        return centralManager.isScanning
    }
    
    public override init() {
    }
}

// MARK: - Manager Scan functions
extension SwiftyTeeth {

    open func scan() {
        scannedDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    open func scan(changes: ((Device) -> Void)?) {
        scanChangesHandler = changes
        scan()
    }
    
    open func scan(for timeout: TimeInterval = 10, changes: ((Device) -> Void)? = nil, complete: @escaping ([Device]) -> Void) {
        scanChangesHandler = changes
        scanCompleteHandler = complete
        // TODO: Should this be on main, or on CB queue?
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            self.stopScan()
        }
        scan()
    }

    open func stopScan() {
        // TODO: Cancel asyncAfter if in progress?
        centralManager.stopScan()
        scanCompleteHandler?(Array(scannedDevices))
        
        // Reset Handlers
        scanChangesHandler = nil
        scanCompleteHandler = nil
    }
}


// MARK: - Internal Connection functions
extension SwiftyTeeth {
    
    // Using these internal functions, so that we can track devices 'in use'
    internal func connect(to device: Device) {
        // Add device to dictionary only if it isn't there
        if connectedDevices[device.id] == nil {
            connectedDevices[device.id] = device
        }
        centralManager.connect(device.peripheral, options: nil)
    }
    
    // Using these internal functions, so that we can track devices 'in use'
    internal func disconnect(from device: Device) {
        // Add device to dictionary only if it isn't there
        if connectedDevices[device.id] == nil {
            connectedDevices[device.id] = device
        }
        centralManager.cancelPeripheralConnection(device.peripheral)
    }
}


// MARK: - Peripheral functions
extension SwiftyTeeth {

    open func readValue(for characteristic: UUID, complete: (CBCharacteristic) -> Void) {
        //TODO
    }

    open func write(data: NSData, for characteristic: UUID, complete: (CBCharacteristic) -> Void) {
        //TODO
    }
}

// MARK: - Central manager
extension SwiftyTeeth: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .unknown:
            print("Bluetooth state is unknown.")
        case .resetting:
            print("Bluetooth state is resetting.")
        case .unsupported:
            print("Bluetooth state is unsupported.")
        case .unauthorized:
            print("Bluetooth state is unauthorized.")
        case .poweredOff:
            print("Bluetooth state is powered off.")
        case .poweredOn:
            print("Bluetooth state is powered on")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard peripheral.name != nil else {
            return
        }
        
        let device = Device(manager: self, peripheral: peripheral)
        scannedDevices.insert(device)
        scanChangesHandler?(device)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("centralManager: didConnect")
        connectedDevices[peripheral.identifier.uuidString]?.didConnect()
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("centralManager: didFailToConnect")
        connectedDevices[peripheral.identifier.uuidString]?.didDisconnect()
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("centralManager: didDisconnect")
        connectedDevices[peripheral.identifier.uuidString]?.didDisconnect()
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
    }
}

// TODO: If multiple peripherals are connected, should there be a peripheral validation done?
// MARK: - CBPeripheralDelegate
extension SwiftyTeeth: CBPeripheralDelegate {
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        connectedDevices[peripheral.identifier.uuidString]?.didUpdateName()
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        connectedDevices[peripheral.identifier.uuidString]?.didModifyServices(invalidatedServices: invalidatedServices)
    }
    
    public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didUpdateRSSI(error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didReadRSSI(RSSI: RSSI, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didDiscoverServices(error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didDiscoverIncludedServicesFor(service: service, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didDiscoverCharacteristicsFor(service: service, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didUpdateValueFor(characteristic: characteristic, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didWriteValueFor(characteristic: characteristic, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didUpdateNotificationStateFor(characteristic: characteristic, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didDiscoverDescriptorsFor(characteristic: characteristic, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didUpdateValueFor(descriptor: descriptor, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        connectedDevices[peripheral.identifier.uuidString]?.didWriteValueFor(descriptor: descriptor, error: error)
    }
}


