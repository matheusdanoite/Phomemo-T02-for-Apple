import SwiftUI
import FirebaseCore

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}
#elseif os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running when window is closed
    }
}
#endif

@main
struct t02webApp: App {
  // register app delegate for Firebase and lifecycle
  #if os(iOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #elseif os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #endif
  
  // Use the shared instance
  @StateObject var bluetoothManager = BluetoothManager.shared
  @StateObject var sharingService = PrinterSharingService.shared

  // No separate init needed for macOS as configure is now in AppDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(bluetoothManager)
        .environmentObject(sharingService)
        .onOpenURL { url in
            // Handle phax://print?text=Hello
            if url.scheme == "phax" && url.host == "print" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let queryItems = components.queryItems,
                   let text = queryItems.first(where: { $0.name == "text" })?.value {
                    
                    Task {
                        await BluetoothManager.shared.printText(text)
                    }
                }
            } else if url.isFileURL {
                // Handle files shared via "Open In"
                let bluetooth = BluetoothManager.shared
                bluetooth.log("Recebido arquivo via Share Sheet: \(url.lastPathComponent)")
                
                Task {
                    if let data = try? Data(contentsOf: url) {
                        if let image = PlatformImage.fromData(data) {
                            bluetooth.log("Arquivo é uma imagem. Imprimindo...")
                            await bluetooth.printImage(image)
                        } else if let text = String(data: data, encoding: .utf8) {
                            bluetooth.log("Arquivo é texto. Imprimindo...")
                            await bluetooth.printText(text)
                        }
                    }
                }
            }
        }
    }
    .commands {
        SidebarCommands()
        CommandGroup(after: .appInfo) {
            Button("Reconectar Impressora") {
                BluetoothManager.shared.startScan()
            }
            .keyboardShortcut("R", modifiers: .command)
            
            Button("Reiniciar P2P") {
                PrinterSharingService.shared.autoRoleSelection() 
                PrinterSharingService.shared.setRole(PrinterSharingService.shared.role) // Forces restart with correct role
            }
            .keyboardShortcut("P", modifiers: .command)
        }
    }

    #if os(macOS)
    MenuBarExtra("Phomemo T02", systemImage: bluetoothManager.isConnected ? "printer.fill" : "printer") {
        StatusMenu()
            .environmentObject(bluetoothManager)
            .environmentObject(sharingService)
    }
    #endif
  }
}

#if os(macOS)
struct StatusMenu: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var sharingService: PrinterSharingService
    
    var body: some View {
        Group {
            Text("Impressora: \(bluetoothManager.isConnected ? "Conectada" : "Desconectada")")
            Text("P2P: \(sharingService.statusMessage)")
            
            Divider()
            
            Text("Logs Recentes:")
            ForEach(bluetoothManager.logs.suffix(5).reversed(), id: \.self) { log in
                Text(log)
                    .font(.system(size: 10, design: .monospaced))
            }
            
            Divider()
            
            Button("Abrir Aplicativo") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
#endif
