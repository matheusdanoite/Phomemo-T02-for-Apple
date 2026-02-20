import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var sharingService: PrinterSharingService
    @StateObject var firestoreManager = FirestoreManager()
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedTab = 0
    #if os(iOS)
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    init() {
        #if os(iOS)
        if !ProcessInfo.processInfo.isiOSAppOnMac {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .black
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        #endif
    }
    
    private var isPadOrMac: Bool {
        #if os(macOS)
        return true
        #elseif targetEnvironment(macCatalyst)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    
    enum Tab: Int, CaseIterable, Identifiable {
        case photos = 0
        case text = 1
        case strip = 2
        case info = 3

        var id: Int { self.rawValue }

        var label: String {
            switch self {
            case .photos: return "Fotos"
            case .text: return "Texto"
            case .strip: return "Faixa"
            case .info: return "Infos"
            }
        }

        var icon: String {
            switch self {
            case .photos: return "photo"
            case .text: return "text.alignleft"
            case .strip: return "scroll"
            case .info: return "gear"
            }
        }
    }
    
    var body: some View {
        Group {
            if isPadOrMac {
                VStack(spacing: 0) {
                    topNavBar
                        .padding(.bottom, 5) // Subtle space below high nav
                    
                    destinationView(for: Tab(rawValue: selectedTab) ?? .photos)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                #if os(macOS)
                .background(Color(NSColor.windowBackgroundColor))
                #else
                .background(Color(UIColor.systemBackground))
                #endif
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        destinationView(for: tab)
                            .tabItem {
                                Label(tab.label, systemImage: tab.icon)
                            }
                            .tag(tab.rawValue)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    @Namespace private var tabAnimation
    
    private var topNavBar: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { tab in
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab.rawValue 
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundColor(selectedTab == tab.rawValue ? .primary : .secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background(
                        ZStack {
                            if selectedTab == tab.rawValue {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .matchedGeometryEffect(id: "indicator", in: tabAnimation)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        #if os(macOS)
        .background(.ultraThinMaterial)
        #else
        .background(Color.black.opacity(0.8))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func destinationView(for tab: Tab) -> some View {
        switch tab {
        case .photos:
            WebView(bluetoothManager: bluetoothManager, page: "index.html")
        case .text:
            WebView(bluetoothManager: bluetoothManager, page: "text.html")
        case .strip:
            WebView(bluetoothManager: bluetoothManager, page: "strip.html")
        case .info:
            infoView
        }
    }

    private var infoView: some View {
        VStack(spacing: 12) {
            Text("Phomemo T02 Relay")
                .font(.title2)
                .bold()
                .padding(.top, 10)
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Bluetooth: \(bluetoothManager.isConnected ? "Connected" : "Scanning...")")
                        .foregroundColor(bluetoothManager.isConnected ? .green : .orange)
                }
                HStack {
                    Image(systemName: "cloud")
                    Text("Firestore: \(firestoreManager.status)")
                }
                
                Divider()
                    .background(Color.gray)
                
                Text("Compartilhamento P2P")
                    .font(.headline)
                
                HStack {
                    Image(systemName: sharingService.role == .host ? "server.rack" : "person.2")
                    Text("Modo atual: \(sharingService.role.rawValue)")
                        .font(.subheadline)
                        .bold()
                }
                
                HStack {
                    Image(systemName: "personalhotspot")
                    Text("Status: \(sharingService.statusMessage)")
                        .font(.caption)
                }
                
                if sharingService.isConnected {
                    Text("Conectado a \(sharingService.connectedPeers.count) dispositivo(s)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Device Name Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Nome do dispositivo P2P")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("Ex: Impressora da Sala", text: $sharingService.displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Atualizar") {
                        sharingService.updateDisplayName(sharingService.displayName)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            
            Spacer(minLength: 5)
            
            // Latest Job Preview
            if let job = firestoreManager.latestJob {
                VStack(spacing: 5) {
                    Text("Processing Job...")
                        .font(.caption)
                        .bold()
                    Image(platformImage: job.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 150) // Reduced height
                        .border(Color.black, width: 1)
                        .background(Color.white)
                }
            } else {
                VStack {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("Waiting for remote jobs...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
            }
            
            Spacer(minLength: 5)
            
            // Logs
            VStack(alignment: .leading, spacing: 4) {
                Text("Logs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(bluetoothManager.logs, id: \.self) { log in
                            Text(log)
                                .font(.system(size: 9, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(height: 80) // Reduced height
                .padding(5)
                .background(Color.black.opacity(0.05))
                .cornerRadius(5)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .onAppear {
            // Auto-start sharing service based on printer connection
            let newRole: AppRole = bluetoothManager.isConnected ? .host : .client
            sharingService.setRole(newRole)
            
            // Only listen if we are host
            if newRole == .host {
                firestoreManager.startListening()
            }
        }
        .onChange(of: sharingService.role) { oldRole, newRole in
            if newRole == .host {
                firestoreManager.startListening()
            } else {
                firestoreManager.stopListening()
            }
        }
        .onChange(of: firestoreManager.latestJob?.id) { oldId, newId in
            if let job = firestoreManager.latestJob, bluetoothManager.isConnected {
                printAndCleanup(job)
            }
        }
        .onChange(of: sharingService.receivedJob) { oldJob, chunks in
            if let chunks = chunks, sharingService.role == .host, bluetoothManager.isConnected {
                Task {
                    bluetoothManager.log("Recebido trabalho P2P de \(sharingService.remotePeerName ?? "Peer"). Imprimindo...")
                    for chunk in chunks {
                        await bluetoothManager.write(Data(chunk))
                    }
                    await bluetoothManager.write(PrinterProtocol.feed(lines: 5))
                    sharingService.receivedJob = nil
                }
            }
        }
        .onChange(of: bluetoothManager.isConnected) { oldStatus, isConnected in
            // Automate Role Selection: Host if connected to printer, Client otherwise
            sharingService.setRole(isConnected ? .host : .client)
            
             // If we connected and have a pending job, print it
             if isConnected, let job = firestoreManager.latestJob {
                 printAndCleanup(job)
             }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        #if os(iOS)
        if phase == .background {
            bluetoothManager.log("App em background: Solicitando tempo extra para manter conexões.")
            
            // End existing task if any
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            
            // Start new background task
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PrinterConnectionStayAlive") {
                // Expiration handler: called when system is about to kill the process
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
                self.bluetoothManager.log("Tempo de background expirou.")
            }
        } else if phase == .active {
            bluetoothManager.log("App voltou ao foreground.")
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            
            // Restart services if needed (safety check)
            if !sharingService.isConnected {
                sharingService.setRole(bluetoothManager.isConnected ? .host : .client)
            }
        }
        #endif
    }
    
    func printAndCleanup(_ job: PrintJob) {
        Task {
            let skipRotation = (job.type == "text_render")
            await bluetoothManager.printImage(job.image, skipRotation: skipRotation)
            
            // Delay deletion to ensure print commands are sent
            // Since printImage is now async and awaits all writes, 
            // the delay is just a safety margin or can be removed.
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            firestoreManager.deleteJob(job.id)
        }
    }
}
