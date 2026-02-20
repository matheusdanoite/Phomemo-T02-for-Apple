import Foundation
import CoreBluetooth
import MultipeerConnectivity
import Combine
import SwiftUI
#if os(iOS)
import UIKit
#endif
import CoreText

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager() // Singleton Instance
    
    @Published var isConnected = false
    @Published var logs: [String] = []
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    
    // Serial queue for printer operations to avoid blocking Main Actor
    private let printerQueue = DispatchQueue(label: "com.matheusdanoite.t02web.printer", qos: .userInitiated)
    
    // UUIDs
    private let scanUUID = CBUUID(string: "AF30") // Advertised Service
    private let serviceUUID = CBUUID(string: "FF00") // Operational Service
    private let writeCharUUID = CBUUID(string: "FF02") // Write Characteristic
    private let restoreIdentifier = "com.matheusdanoite.t02web.bluetooth.restore"
    
    override init() {
        super.init()
        let options: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier
        ]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
    
    private var connectionTimer: Timer?

    func log(_ msg: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMsg = "[\(timestamp)] \(msg)" 
        print(logMsg)
        DispatchQueue.main.async {
            // Append with unique ID trick for SwiftUI (or just unique string content)
            self.logs.append(logMsg)
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
        }
    }
    
    // MARK: - App Intent Helpers
    
    func printText(_ text: String, title: String? = nil) async {
        let sharing = PrinterSharingService.shared
        guard isConnected || (sharing.role == .client && sharing.isConnected) else {
            log("Cannot print: Not connected to printer or P2P host.")
            return
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty || (cleanTitle != nil && !cleanTitle!.isEmpty) else {
            log("No text or title to print after trimming.")
            return
        }

        log("Generating image for text: \(cleanText)")
        if let image = textToImage(cleanText, title: cleanTitle) {
            await printImage(image, skipRotation: true)
        } else {
            log("Failed to generate image from text.")
        }
    }
    
    private func textToImage(_ text: String, title: String? = nil) -> PlatformImage? {
        log("textToImage: Starting conversion. Title: '\(title ?? "nil")', Text length: \(text.count)")
        
        let targetWidth: CGFloat = 384.0 // Standard T02 Width
        #if os(macOS)
        let titleFont = NSFont.boldSystemFont(ofSize: 32)
        let bodyFont = NSFont.systemFont(ofSize: 32)
        #else
        let titleFont = PlatformFont.systemFont(ofSize: 32, weight: .black)
        let bodyFont = PlatformFont.systemFont(ofSize: 32, weight: .regular)
        #endif
        
        // Paragraph Styles
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .left
        titleParagraphStyle.lineBreakMode = .byWordWrapping
        titleParagraphStyle.lineSpacing = 1
        titleParagraphStyle.paragraphSpacing = 0
        
        let bodyParagraphStyle = NSMutableParagraphStyle()
        bodyParagraphStyle.alignment = .left
        bodyParagraphStyle.lineBreakMode = .byWordWrapping
        bodyParagraphStyle.lineSpacing = 0
        
        // Prepare Attributed String
        let finalAttributedString = NSMutableAttributedString()
        
        if let title = title, !title.isEmpty {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: PlatformColor.black,
                .paragraphStyle: titleParagraphStyle
            ]
            finalAttributedString.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))
        }
        
        if !text.isEmpty {
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: PlatformColor.black,
                .paragraphStyle: bodyParagraphStyle
            ]
            finalAttributedString.append(NSAttributedString(string: text, attributes: bodyAttributes))
        }
        
        let constraints = CGSize(width: targetWidth - 20, height: .greatestFiniteMagnitude)
        let boundingRect = finalAttributedString.boundingRect(with: constraints, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        let finalHeight = max(ceil(boundingRect.height), 8)
        let finalSize = CGSize(width: targetWidth, height: finalHeight)
        
        log("textToImage: Calculated height: \(finalHeight)px")
        
        #if os(macOS)
        let img = NSImage(size: finalSize)
        img.lockFocus()
        PlatformColor.white.setFill()
        NSRect(origin: .zero, size: finalSize).fill()
        let textRect = NSRect(x: 10, y: 0, width: targetWidth - 20, height: finalHeight)
        finalAttributedString.draw(in: textRect)
        img.unlockFocus()
        return img
        #else
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        return UIGraphicsImageRenderer(size: finalSize, format: format).image { context in
            PlatformColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))
            let textRect = CGRect(x: 10, y: 0, width: targetWidth - 20, height: finalHeight)
            finalAttributedString.draw(in: textRect)
        }
        #endif
    }
    // MARK: - CBCentralManagerDelegate
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log("Restoring Bluetooth state...")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                log("Restoring peripheral: \(peripheral.name ?? "Unknown")")
                connectedPeripheral = peripheral
                peripheral.delegate = self
                if peripheral.state == .connected {
                    isConnected = true
                }
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("Bluetooth ON. Scanning for Advertised Service \(scanUUID)...")
            if connectedPeripheral == nil {
                startScan()
            } else if let p = connectedPeripheral, p.state != .connected {
                // Was trying to connect but failed/disconnected?
                startScan()
            }
        case .poweredOff:
            log("Bluetooth OFF")
            isConnected = false
        case .unsupported:
            log("Bluetooth Unsupported")
        case .unauthorized:
            log("Bluetooth Unauthorized")
        case .resetting:
            log("Bluetooth Resetting")
        case .unknown:
            log("Bluetooth Unknown")
        @unknown default:
            log("Bluetooth Error")
        }
    }
    
    func startScan() {
        // 1. Check if already connected to system
        let connected = centralManager.retrieveConnectedPeripherals(withServices: [scanUUID, serviceUUID])
        if let peripheral = connected.first {
            log("Found system-connected device: \(peripheral.name ?? "Unknown")")
            connect(to: peripheral)
            return
        }
        
        // 2. Start Scan
        log("Scanning for Advertised Service \(scanUUID)...")
        centralManager.scanForPeripherals(withServices: [scanUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("Discovered: \(peripheral.name ?? "Unknown")")
        // Stop scan and connect
        centralManager.stopScan()
        connect(to: peripheral)
    }

    func connect(to peripheral: CBPeripheral) {
        log("Connecting to \(peripheral.name ?? "Unknown")...")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        // Start connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.log("Connection timeout! Cancelling and retrying scan...")
            self?.centralManager.cancelPeripheralConnection(peripheral)
            self?.startScan()
        }
        
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ])
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimer?.invalidate()
        log("Connected to \(peripheral.name ?? "Unknown")")
        isConnected = true
        // Discover the OPERATIONAL service (FF00)
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimer?.invalidate()
        log("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        // Retry scan after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Disconnected: \(error?.localizedDescription ?? "Normal")")
        isConnected = false
        connectedPeripheral = nil
        writeCharacteristic = nil
        startScan()
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            log("Service found: \(service.uuid)")
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([writeCharUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            log("Characteristic: \(char.uuid)")
            if char.uuid == writeCharUUID {
                log("Found Write Characteristic!")
                writeCharacteristic = char
                
                // Init printer if needed
            }
        }
    }
    
    func write(_ data: Data) async {
        await withCheckedContinuation { continuation in
            printerQueue.async { [weak self] in
                guard let self = self, let peripheral = self.connectedPeripheral, let char = self.writeCharacteristic else {
                    self?.log("Not connected or no write char")
                    continuation.resume()
                    return
                }
                
                let type: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                
                // MTU handling
                let mtu = peripheral.maximumWriteValueLength(for: type)
                var offset = 0
                
                while offset < data.count {
                    let chunkCheck = min(offset + mtu, data.count)
                    let chunk = data.subdata(in: offset..<chunkCheck)
                    peripheral.writeValue(chunk, for: char, type: type)
                    offset += mtu
                    
                    // Small delay to prevent buffer overflow for T02
                    Thread.sleep(forTimeInterval: 0.02) 
                }
                continuation.resume()
            }
        }
    }
    
    func generateChunks(from image: PlatformImage) -> [[UInt8]] {
        guard let bitmap = image.toBitmapData() else {
            log("Failed to convert image to bitmap")
            return []
        }
        
        // Dimensions
        let widthBytes = 48 // 384 dots
        let totalHeightPixels = bitmap.count / widthBytes
        
        // Split image into chunks of 128 pixels high to avoid printer buffer overflow
        let chunkHeight = 128
        var currentY = 0
        var chunks: [[UInt8]] = []
        
        while currentY < totalHeightPixels {
            let height = min(chunkHeight, totalHeightPixels - currentY)
            let start = currentY * widthBytes
            let end = (currentY + height) * widthBytes
            
            if start < bitmap.count {
                let actualEnd = min(end, bitmap.count)
                let chunkData = bitmap.subdata(in: start..<actualEnd)
                let printData = PrinterProtocol.rasterData(from: chunkData, widthBytes: widthBytes, heightPixels: height)
                chunks.append([UInt8](printData))
            }
            
            currentY += height
        }
        return chunks
    }
    
    func printImage(_ image: PlatformImage, skipRotation: Bool = false) async {
        // Automatically rotate if landscape (wider than tall), unless skipRotation is true
        let processedImage = skipRotation ? image : image.rotatedIfLandscape()
        
        // P2P Redirection Logic
        let sharing = PrinterSharingService.shared
        sharing.autoRoleSelection() 
        
        if sharing.role == .client {
            sharing.ensureServicesActive()
            
            // If not connected yet, wait up to 3 seconds for a Host to be found
            if !sharing.isConnected {
                log("Aguardando conexão P2P com Host...")
                for _ in 0..<6 { // 6 * 0.5s = 3s
                    if sharing.isConnected { break }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            
            if sharing.isConnected {
                log("Roteando trabalho de impressão via P2P para o Host: \(sharing.connectedPeers.first?.displayName ?? "Desconhecido")")
                let chunks = generateChunks(from: processedImage)
                sharing.sendPrintJob(chunks)
                return
            } else {
                log("Aviso: Falha ao encontrar um Host P2P em tempo hábil.")
                // Fallback: If not connected to printer either, it will log "Not connected..." below
            }
        }
        
        let chunks = generateChunks(from: processedImage)
        guard !chunks.isEmpty else { return }
        
        log("Printing \(chunks.count) chunks...")
        
        for chunk in chunks {
            await write(Data(chunk))
        }
        
        // Feed
        // Send a minimal feed to help separation without excessive space (1 line instead of 3 or 5)
        await write(PrinterProtocol.feed(lines: 1))
        
        log("All data sent to printer!")
    }
}


extension PlatformImage {
    // Convert to monochrome bitmap data for T02 (48 bytes width)
    func toBitmapData() -> Data? {
        #if os(macOS)
        guard let cgImage = self.cgImage else { return nil }
        #else
        guard let cgImage = self.cgImage else { return nil }
        #endif
        
        let width = 384
        // Scalled height
        let height = Int(Double(cgImage.height) * (Double(width) / Double(cgImage.width)))
        
        // 1. Resize and Draw onto a White Background (Handling Transparency)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        // We use a context to draw the image scaled and flattened
        guard let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        
        context.interpolationQuality = .high
        
        // Fill white first (treats transparent as white)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height)
        
        // 2. Floyd-Steinberg Dithering
        // We use a mutable buffer of floats for higher precision during error diffusion
        var buffer = [Float](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            buffer[i] = Float(pixels[i])
        }
        
        func distributeErrorSwift(_ x: Int, _ y: Int, _ error: Float, _ factor: Float) {
            if x >= 0 && x < width && y >= 0 && y < height {
                buffer[y * width + x] += error * factor
            }
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = buffer[index]
                let newPixel: Float = oldPixel < 128 ? 0 : 255
                let error = oldPixel - newPixel
                
                buffer[index] = newPixel
                
                // Floyd-Steinberg coefficients
                distributeErrorSwift(x + 1, y,     error, 7.0 / 16.0)
                distributeErrorSwift(x - 1, y + 1, error, 3.0 / 16.0)
                distributeErrorSwift(x,     y + 1, error, 5.0 / 16.0)
                distributeErrorSwift(x + 1, y + 1, error, 1.0 / 16.0)
            }
        }
        
        // 3. Convert to 1-bit packed data
        let totalBytes = (width * height) / 8
        var bitData = Data(count: totalBytes)
        
        for y in 0..<height {
            let bitRowOffset = y * (width / 8)
            for x in 0..<(width/8) {
                var byte: UInt8 = 0
                let byteX8 = x * 8
                for bit in 0..<8 {
                    if buffer[y * width + byteX8 + bit] < 128 {
                        byte |= (1 << (7 - bit))
                    }
                }
                bitData[bitRowOffset + x] = byte
            }
        }
        
        return bitData
    }
    
    // Rotate 90 degrees if landscape
    func rotatedIfLandscape() -> PlatformImage {
        let flattened = self.flattened()
        if flattened.size.width > flattened.size.height {
            BluetoothManager.shared.log("Imagem Landscape detectada (\(Int(flattened.size.width))x\(Int(flattened.size.height))). Rotacionando 90 graus...")
            return flattened.rotated(by: 90) ?? flattened
        }
        return flattened
    }
    
    // Normalizes image orientation (burns EXIF orientation into pixels)
    func flattened() -> PlatformImage {
        #if os(macOS)
        return self // macOS handles orientation differently or doesn't use EXIF as much for raw print
        #else
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
        #endif
    }
    
    func rotated(by degrees: Double) -> PlatformImage? {
        #if os(macOS)
        // Simple 90 deg rotation for macOS
        let rotatedSize = NSSize(width: size.height, height: size.width)
        let rotatedImage = NSImage(size: rotatedSize)
        rotatedImage.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: rotatedSize.width / 2, yBy: rotatedSize.height / 2)
        transform.rotate(byDegrees: CGFloat(degrees))
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        self.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()
        return rotatedImage
        #else
        let radians = CGFloat(degrees * .pi / 180)
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        
        // Trim off extremely small float errors
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Move origin to the middle to rotate around center
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
        #endif
    }
}
