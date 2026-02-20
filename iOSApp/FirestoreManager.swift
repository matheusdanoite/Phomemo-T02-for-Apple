import Foundation
import FirebaseFirestore
import Combine

struct PrintJob {
    let id: String
    let image: PlatformImage
    let timestamp: Date
    let type: String?
}

class FirestoreManager: ObservableObject {
    @Published var latestJob: PrintJob?
    @Published var status: String = "Idle"
    
    private var db: Firestore!
    private var listener: ListenerRegistration?
    
    init() {
        // Checking if Firebase is configured is handled in App Delegate, 
        // but we access Firestore lazily or after init?
        // Firestore.firestore() should work if configure() was called.
        // But this class is initialized in ContentView... which is in WindowGroup.
        // configure() is in didFinishLaunching. 
        // It *should* be fine.
    }
    
    func startListening() {
        if db == nil {
             db = Firestore.firestore()
        }
        
        status = "Listening for jobs..."
        listener = db.collection("print_jobs")
            .order(by: "timestamp", descending: false)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    self.status = "Error: \(error?.localizedDescription ?? "Unknown")"
                    return
                }
                
                if let doc = documents.first {
                    let data = doc.data()
                    if let base64String = data["data"] as? String,
                       let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
                       let image = PlatformImage.fromData(imageData) {
                        
                        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        let type = data["type"] as? String
                        
                        DispatchQueue.main.async {
                            self.latestJob = PrintJob(id: doc.documentID, image: image, timestamp: timestamp, type: type)
                            self.status = "New Job Received!"
                        }
                    } else {
                         // Corrupt data?
                         self.status = "Received invalid job data"
                    }
                }
            }
    }
    
    func deleteJob(_ id: String) {
        db.collection("print_jobs").document(id).delete() { err in
            if let err = err {
                print("Error removing document: \(err)")
            } else {
                print("Document successfully removed!")
                DispatchQueue.main.async {
                    if self.latestJob?.id == id {
                        self.latestJob = nil
                        self.status = "Job completed & deleted"
                    }
                }
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
    }
}
