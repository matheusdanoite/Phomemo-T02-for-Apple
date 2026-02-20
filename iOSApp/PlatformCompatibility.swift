import Foundation
import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont

extension NSImage {
    var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

public var currentDeviceName: String {
    return Host.current().localizedName ?? "Mac"
}
#else
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont

public var currentDeviceName: String {
    return UIDevice.current.name
}
#endif

extension PlatformImage {
    static func fromData(_ data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

public struct PlatformPasteboard {
    public static var general: PlatformPasteboard = PlatformPasteboard()
    
    public var image: PlatformImage? {
        #if os(macOS)
        guard let data = NSPasteboard.general.data(forType: .tiff) else { return nil }
        return NSImage(data: data)
        #else
        return UIPasteboard.general.image
        #endif
    }
    
    public var string: String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}
