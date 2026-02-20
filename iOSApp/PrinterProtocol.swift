import Foundation

class PrinterProtocol {
    
    // Initialize Printer
    static func initialize() -> Data {
        return Data([0x1B, 0x40]) // ESC @
    }
    
    // Feed Paper
    // ESC d n: Feeds n lines.
    // For T02, 1 line is approx 3.75mm? Or 0.125mm? 
    // If user said it rolled a lot with 100, then 100 was too much.
    // Let's set default to 5 lines (approx 1-2cm depending on implementation)
    static func feed(lines: UInt8 = 5) -> Data {
        return Data([0x1B, 0x64, lines]) // ESC d n
    }
    
    // Reset Printer
    static func reset() -> Data {
        return Data([0x1B, 0x40])
    }
    
    // Generate Raster Data for T02
    // T02 uses a standard raster command or a variation.
    // Based on common T02 implementations:
    // Width is usually 384 dots (48 bytes).
    // Command: GS v 0 (0x1D 0x76 0x30) + mode(0) + xL + xH + yL + yH + data
    static func rasterData(from bitmap: Data, widthBytes: Int, heightPixels: Int) -> Data {
        var command = Data()
        
        // GS v 0 m xL xH yL yH d1...dk
        command.append(contentsOf: [0x1D, 0x76, 0x30, 0x00])
        
        // xL, xH (Bytes per line)
        let xL = UInt8(widthBytes % 256)
        let xH = UInt8(widthBytes / 256)
        command.append(contentsOf: [xL, xH])
        
        // yL, yH (Height in dots)
        let yL = UInt8(heightPixels % 256)
        let yH = UInt8(heightPixels / 256)
        command.append(contentsOf: [yL, yH])
        
        // Data
        command.append(bitmap)
        
        return command
    }
    
    // Helper to print a Base64 encoded 1-bit monochome image string
    // Assumes the string strictly contains raw pixel data (0=white, 1=black? OR inverted?)
    // Actually, usually 1=print (black), 0=no print.
    // BUT the standard bitmap format usually packs 8 pixels per byte.
    // If we receive a raw Base64 of the *PNG*, we need to decode properly.
    // HOWEVER, the plan said "base64_encoded_image". The web sends a DataURL of a PNG.
    // The iOS app needs to convert that UIImage/Data to 1-bit bitmap data.
}




