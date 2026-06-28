import CoreBluetooth

// The smART Sketcher 2.0 uses a single characteristic for all communication.
private let kCharUUID = CBUUID(string: "0000FFE3-0000-1000-8000-00805F9B34FB")
private let kDeviceName = "smART_sketcher2.0"
private let kLinePause: UInt64 = 50_000_000   // 50 ms in nanoseconds

enum TransferState: Equatable {
    case idle
    case scanning
    case connecting
    case transferring(line: Int)
    case done
    case failed(String)

    var isActive: Bool {
        switch self {
        case .idle, .done, .failed: return false
        default: return true
        }
    }
}

@MainActor
final class BLEManager: NSObject, ObservableObject {
    @Published var transferState: TransferState = .idle
    @Published var statusMessage = "Ready — drop an image to get started"

    var progress: Double {
        if case .transferring(let line) = transferState { return Double(line) / 128.0 }
        if case .done = transferState { return 1.0 }
        return 0
    }

    // MARK: - Private state

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?

    private var writeType: CBCharacteristicWriteType = .withResponse

    private var scanCont:    CheckedContinuation<CBPeripheral, Error>?
    private var connectCont: CheckedContinuation<Void, Error>?
    private var discoverCont: CheckedContinuation<CBCharacteristic, Error>?
    private var writeCont:   CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        // Callbacks arrive on the main queue — safe to update @Published directly.
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func send(image: AppImage) async {
        do {
            set(.scanning, "Scanning for device…")
            let p = try await scan()

            set(.connecting, "Connecting…")
            peripheral = p
            p.delegate = self
            try await connect(p)

            set(.connecting, "Discovering services…")
            let char = try await discover(p)
            txChar = char
            writeType = char.properties.contains(.write) ? .withResponse : .withoutResponse
            p.setNotifyValue(true, for: char)

            set(.connecting, "Initializing transfer…")
            try await write(Data([0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x01, 0x00]))

            guard let pixels = ImageProcessor.toRGB565(image) else {
                throw BLEError.imageProcessingFailed
            }

            set(.transferring(line: 0), "Transferring…")
            for y in 0 ..< 128 {
                let line = pixels.subdata(in: y * 320 ..< (y + 1) * 320)
                try await write(line)
                try await Task.sleep(nanoseconds: kLinePause)
                set(.transferring(line: y + 1), "Transferring… \(y + 1) / 128 lines")
            }

            set(.done, "✓ Image transferred successfully!")
        } catch {
            set(.failed(error.localizedDescription), "Error: \(error.localizedDescription)")
        }

        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        txChar = nil
    }

    // MARK: - Async helpers

    private func scan() async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { cont in
            scanCont = cont
            central.scanForPeripherals(withServices: nil)
        }
    }

    private func connect(_ p: CBPeripheral) async throws {
        try await withCheckedThrowingContinuation { cont in
            connectCont = cont
            central.connect(p)
        }
    }

    private func discover(_ p: CBPeripheral) async throws -> CBCharacteristic {
        try await withCheckedThrowingContinuation { cont in
            discoverCont = cont
            p.discoverServices(nil)
        }
    }

    private func write(_ data: Data) async throws {
        guard let p = peripheral, let char = txChar else { throw BLEError.notConnected }
        if writeType == .withResponse {
            // Wait for the device's acknowledgment before proceeding.
            try await withCheckedThrowingContinuation { cont in
                writeCont = cont
                p.writeValue(data, for: char, type: .withResponse)
            }
        } else {
            // No ack available — fire and rely on the per-line delay for pacing.
            p.writeValue(data, for: char, type: .withoutResponse)
        }
    }

    private func set(_ state: TransferState, _ message: String) {
        transferState = state
        statusMessage = message
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            Task { @MainActor in
                statusMessage = "Bluetooth unavailable"
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        guard peripheral.name == kDeviceName else { return }
        central.stopScan()
        Task { @MainActor in
            scanCont?.resume(returning: peripheral)
            scanCont = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectCont?.resume()
            connectCont = nil
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            connectCont?.resume(throwing: error ?? BLEError.connectionFailed)
            connectCont = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                discoverCont?.resume(throwing: error)
                discoverCont = nil
                return
            }
            // Search all services for the target characteristic.
            guard let services = peripheral.services, !services.isEmpty else {
                discoverCont?.resume(throwing: BLEError.serviceNotFound)
                discoverCont = nil
                return
            }
            for service in services {
                peripheral.discoverCharacteristics([kCharUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            guard discoverCont != nil else { return }  // already resolved
            if let error {
                discoverCont?.resume(throwing: error)
                discoverCont = nil
                return
            }
            if let char = service.characteristics?.first(where: { $0.uuid == kCharUUID }) {
                discoverCont?.resume(returning: char)
                discoverCont = nil
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                writeCont?.resume(throwing: error)
            } else {
                writeCont?.resume()
            }
            writeCont = nil
        }
    }
}

// MARK: - Errors

enum BLEError: LocalizedError {
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case notConnected
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed:       return "Failed to connect to device"
        case .serviceNotFound:        return "No BLE services found on device"
        case .characteristicNotFound: return "Target characteristic not found"
        case .notConnected:           return "Not connected to a device"
        case .imageProcessingFailed:  return "Could not read pixel data from image"
        }
    }
}
