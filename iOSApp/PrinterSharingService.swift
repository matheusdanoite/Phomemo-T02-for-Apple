import Foundation
import MultipeerConnectivity
import Combine

/// Roles for devices in the printer sharing network
enum AppRole: String, CaseIterable, Identifiable {
    case host = "Host"
    case client = "Cliente"
    
    var id: String { rawValue }
}

/// Manages MultipeerConnectivity session for sharing a Phomemo printer
/// across multiple devices on the local network.
class PrinterSharingService: NSObject, ObservableObject {
    static let shared = PrinterSharingService() // Singleton Instance
    
    @Published var role: AppRole = .host
    @Published var connectedPeers: [MCPeerID] = []
    @Published var statusMessage: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var receivedJob: [[UInt8]]?
    @Published var remotePeerName: String?
    
    @Published var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: "p2p_display_name")
        }
    }
    
    // MARK: - MultipeerConnectivity
    
    private let serviceType = "phomemo-share" // Max 15 chars
    private var myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // MARK: - Init
    
    override init() {
        let savedName = UserDefaults.standard.string(forKey: "p2p_display_name")
        let name = savedName ?? currentDeviceName
        self.displayName = name
        self.myPeerID = MCPeerID(displayName: name)
        super.init()
        
        setupSession()
    }
    
    private func setupSession() {
        self.session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        self.session.delegate = self
    }
    
    func updateDisplayName(_ newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName != displayName else { return }
        
        stop()
        displayName = cleanName
        myPeerID = MCPeerID(displayName: cleanName)
        setupSession()
        startServices()
    }
    
    // MARK: - Public API
    
    func setRole(_ newRole: AppRole) {
        stop()
        role = newRole
        startServices()
    }
    
    private func startServices() {
        // 1. Start Advertising
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["role": role.rawValue],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        // 2. Start Browsing
        browser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: serviceType
        )
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        statusMessage = "Role: \(role.rawValue) - Ativo"
        print("[PrinterSharing] Started services as \(role.rawValue)")
    }
    
    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        
        DispatchQueue.main.async {
            self.connectedPeers = []
            self.isConnected = false
            self.statusMessage = "Idle"
        }
        print("[PrinterSharing] Services stopped")
    }
    
    func sendPrintJob(_ chunks: [[UInt8]]) {
        // Ensure services are active before sending
        ensureServicesActive()
        
        guard !session.connectedPeers.isEmpty else {
            statusMessage = "Sem peers conectados"
            return
        }
        
        do {
            let data = try JSONEncoder().encode(chunks)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            statusMessage = "Trabalho enviado!"
        } catch {
            statusMessage = "Erro no envio: \(error.localizedDescription)"
        }
    }

    /// Guarantees that discovery and advertising are running.
    /// Useful for background tasks like App Intents or Share Sheet.
    func ensureServicesActive() {
        if advertiser == nil || browser == nil {
            print("[PrinterSharing] Ensuring services are active for background task...")
            autoRoleSelection() 
            startServices()
        }
    }

    /// Automatically sets the role based on whether the device is currently connected to a printer.
    func autoRoleSelection() {
        let isPrinterConnected = BluetoothManager.shared.isConnected
        let newRole: AppRole = isPrinterConnected ? .host : .client
        if role != newRole {
            print("[PrinterSharing] Auto-selecting role: \(newRole.rawValue)")
            role = newRole
        }
    }
    
    deinit {
        stop()
    }
}

// MARK: - MCSessionDelegate

extension PrinterSharingService: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.isConnected = !session.connectedPeers.isEmpty
            
            switch state {
            case .connected:
                self.statusMessage = "Conectado: \(peerID.displayName)"
            case .connecting:
                self.statusMessage = "Conectando..."
            case .notConnected:
                self.statusMessage = self.role == .host ? "Aguardando Clientes..." : "Procurando Host..."
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Host receives print job data from a client
        do {
            let chunks = try JSONDecoder().decode([[UInt8]].self, from: data)
            DispatchQueue.main.async {
                self.remotePeerName = peerID.displayName
                self.receivedJob = chunks
            }
        } catch {
            print("[PrinterSharing] Failed to decode job: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PrinterSharingService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.statusMessage = "Erro ao anunciar" }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PrinterSharingService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let info = info, let peerRole = info["role"] else { return }
        
        let myRole = self.role.rawValue
        
        // Connect if roles are different
        if (myRole == AppRole.host.rawValue && peerRole == AppRole.client.rawValue) ||
           (myRole == AppRole.client.rawValue && peerRole == AppRole.host.rawValue) {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.statusMessage = "Erro ao procurar" }
    }
}
