import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "PillrLogo" asset catalog image resource.
    static let pillrLogo = DeveloperToolsSupport.ImageResource(name: "PillrLogo", bundle: resourceBundle)

    /// The "Reflection Example" asset catalog image resource.
    static let reflectionExample = DeveloperToolsSupport.ImageResource(name: "Reflection Example", bundle: resourceBundle)

    /// The "cloud" asset catalog image resource.
    static let cloud = DeveloperToolsSupport.ImageResource(name: "cloud", bundle: resourceBundle)

    /// The "faceid" asset catalog image resource.
    static let faceid = DeveloperToolsSupport.ImageResource(name: "faceid", bundle: resourceBundle)

    /// The "heart" asset catalog image resource.
    static let heart = DeveloperToolsSupport.ImageResource(name: "heart", bundle: resourceBundle)

    /// The "lock" asset catalog image resource.
    static let lock = DeveloperToolsSupport.ImageResource(name: "lock", bundle: resourceBundle)

    /// The "notification" asset catalog image resource.
    static let notification = DeveloperToolsSupport.ImageResource(name: "notification", bundle: resourceBundle)

    /// The "pill" asset catalog image resource.
    static let pill = DeveloperToolsSupport.ImageResource(name: "pill", bundle: resourceBundle)

    /// The "tick" asset catalog image resource.
    static let tick = DeveloperToolsSupport.ImageResource(name: "tick", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "PillrLogo" asset catalog image.
    static var pillrLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .pillrLogo)
#else
        .init()
#endif
    }

    /// The "Reflection Example" asset catalog image.
    static var reflectionExample: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .reflectionExample)
#else
        .init()
#endif
    }

    /// The "cloud" asset catalog image.
    static var cloud: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cloud)
#else
        .init()
#endif
    }

    /// The "faceid" asset catalog image.
    static var faceid: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .faceid)
#else
        .init()
#endif
    }

    /// The "heart" asset catalog image.
    static var heart: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .heart)
#else
        .init()
#endif
    }

    /// The "lock" asset catalog image.
    static var lock: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .lock)
#else
        .init()
#endif
    }

    /// The "notification" asset catalog image.
    static var notification: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .notification)
#else
        .init()
#endif
    }

    /// The "pill" asset catalog image.
    static var pill: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .pill)
#else
        .init()
#endif
    }

    /// The "tick" asset catalog image.
    static var tick: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tick)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "PillrLogo" asset catalog image.
    static var pillrLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .pillrLogo)
#else
        .init()
#endif
    }

    /// The "Reflection Example" asset catalog image.
    static var reflectionExample: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .reflectionExample)
#else
        .init()
#endif
    }

    /// The "cloud" asset catalog image.
    static var cloud: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cloud)
#else
        .init()
#endif
    }

    /// The "faceid" asset catalog image.
    static var faceid: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .faceid)
#else
        .init()
#endif
    }

    /// The "heart" asset catalog image.
    static var heart: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .heart)
#else
        .init()
#endif
    }

    /// The "lock" asset catalog image.
    static var lock: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .lock)
#else
        .init()
#endif
    }

    /// The "notification" asset catalog image.
    static var notification: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .notification)
#else
        .init()
#endif
    }

    /// The "pill" asset catalog image.
    static var pill: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .pill)
#else
        .init()
#endif
    }

    /// The "tick" asset catalog image.
    static var tick: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tick)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

