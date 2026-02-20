import AppIntents
import SwiftUI


struct PrintClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Print Clipboard"
    static var description = IntentDescription("Prints the current content of the clipboard.")
    
    // Changing this to true is required to access UIPasteboard
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Ensure networking is active for Client Mode
        PrinterSharingService.shared.ensureServicesActive()
        
        // Attempt to access clipboard
        // Check for Image first
        if let image = PlatformPasteboard.general.image {
            await BluetoothManager.shared.printImage(image)
            return .result()
        }
        // Then Check for Text
        else if let string = PlatformPasteboard.general.string {
            await BluetoothManager.shared.printText(string)
            return .result()
        } else {
             // Handle empty clipboard or non-text content found.
             BluetoothManager.shared.log("Clipboard empty or no supported content found.")
             throw error("Clipboard is empty or unsupported")
        }
    }
    
    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case emptyClipboard
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .emptyClipboard: return "Clipboard is empty or contains no text."
            }
        }
    }
    
    func error(_ message: String) -> any Swift.Error {
        return IntentError.emptyClipboard
    }
}
