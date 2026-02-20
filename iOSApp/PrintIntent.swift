import AppIntents
import SwiftUI

import UniformTypeIdentifiers


struct PrintIntent: AppIntent {
    static var title: LocalizedStringResource = "Print"
    static var description = IntentDescription("Prints text or an image passed from Shortcuts.")
    
    // Attempt to run in background (requires Bluetooth Central background mode)
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Text", description: "Text to print", inputConnectionBehavior: .connectToPreviousIntentResult)
    var text: String?
    
    @Parameter(title: "Title", description: "Title or Sender Name", inputConnectionBehavior: .connectToPreviousIntentResult)
    var title: String?
    
    @Parameter(title: "Images",
               description: "Images to print",
               supportedContentTypes: [.image],
               inputConnectionBehavior: .connectToPreviousIntentResult)
    var files: [IntentFile]?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Ensure networking is active for Client Mode
        PrinterSharingService.shared.ensureServicesActive()
        
        // Priority: Images, then Text/Title
        
        var printedSomething = false
        
        // 1. Check for Image Files
        if let files = files, !files.isEmpty {
            for file in files {
                if let data = try? await file.data(contentType: .image),
                   let image = PlatformImage.fromData(data) {
                    
                    BluetoothManager.shared.log("PrintIntent: Printing image from file.")
                    await BluetoothManager.shared.printImage(image)
                    printedSomething = true
                    
                    // Small delay between prints?
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                } else {
                    BluetoothManager.shared.log("PrintIntent: Failed to decode one of the images.")
                }
            }
        }
        
        // 2. Check for Text & Title
        // If either is provided, print them together.
        let hasText = text != nil && !text!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTitle = title != nil && !title!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        BluetoothManager.shared.log("PrintIntent: hasText=\(hasText), hasTitle=\(hasTitle)")
        if hasTitle { BluetoothManager.shared.log("PrintIntent: title value: '\(title!)'") }
        if hasText { BluetoothManager.shared.log("PrintIntent: text value length: \(text!.count)") }

        if hasText || hasTitle {
             let titleToPrint = hasTitle ? title : nil
             let textToPrint = hasText ? text : ""
            
             BluetoothManager.shared.log("PrintIntent: Initiating printText with title: \(titleToPrint ?? "None")")
             await BluetoothManager.shared.printText(textToPrint!, title: titleToPrint)
             printedSomething = true
        }
        
        if printedSomething {
            return .result()
        }
        
        // 3. Nothing happened
        BluetoothManager.shared.log("PrintIntent: No valid input provided.")
        throw IntentError.noInput
    }
    
    enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
        case invalidImage
        case noInput
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .invalidImage: return "Could not load image from input."
            case .noInput: return "No text or image provided to print."
            }
        }
    }
}

struct PhomemoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrintIntent(),
            phrases: [
                "Imprimir com \(.applicationName)",
                "Mandar para \(.applicationName)",
                "Print with \(.applicationName)"
            ],
            shortTitle: "Imprimir na Phomemo",
            systemImageName: "printer.fill"
        )
    }
}
