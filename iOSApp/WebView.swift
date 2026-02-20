import SwiftUI
import WebKit

#if os(macOS)
struct WebView: NSViewRepresentable {
    @ObservedObject var bluetoothManager: BluetoothManager
    var page: String = "index.html"

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "printHandler")
        config.userContentController = contentController
        
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        loadContent(into: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) { }
}
#else
struct WebView: UIViewRepresentable {
    @ObservedObject var bluetoothManager: BluetoothManager
    var page: String = "index.html"

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "printHandler")
        config.userContentController = contentController
        
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        loadContent(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
#endif
    
extension WebView {
    func loadContent(into webView: WKWebView) {
        // Since WebAssets is now a Folder Reference (blue folder), 
        // it's copied as a real directory into the app bundle.
        guard let folderURL = Bundle.main.url(forResource: "WebAssets", withExtension: nil) else {
            print("Error: WebAssets folder not found in bundle.")
            showError(into: webView, message: "WebAssets folder not found in Bundle.")
            return
        }
        
        let pageURL = folderURL.appendingPathComponent(page)
        if FileManager.default.fileExists(atPath: pageURL.path) {
            print("Loading page: \(pageURL.path)")
            webView.loadFileURL(pageURL, allowingReadAccessTo: folderURL)
        } else {
            print("Error: '\(page)' not found in WebAssets.")
            showError(into: webView, message: "'\(page)' not found in WebAssets.")
        }
    }

    private func showError(into webView: WKWebView, message: String) {
        let html = """
        <html>
        <body style="font-family: -apple-system, sans-serif; padding: 40px; text-align: center; background: #f0f0f2;">
            <h1 style="color: #ff3b30;">Content Load Error</h1>
            <p style="color: #3a3a3c;">\(message)</p>
            <p style="font-size: 0.8em; color: #8e8e93;">Check Xcode Folder Reference configuration.</p>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "printHandler", let body = message.body as? [String: Any], let base64 = body["base64"] as? String {
                let type = body["type"] as? String // 'text_render' or 'image_render'
                print("DEBUG: printHandler received message with type: \(type ?? "nil")")
                
                if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
                   let image = PlatformImage.fromData(data) {
                    
                    Task {
                        let skipRotation = (type == "text_render")
                        await self.parent.bluetoothManager.printImage(image, skipRotation: skipRotation)
                    }
                }
            }
        }
    }
}
