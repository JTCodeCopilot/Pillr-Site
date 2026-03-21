#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"app.PillrXcode";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "PillrLogo" asset catalog image resource.
static NSString * const ACImageNamePillrLogo AC_SWIFT_PRIVATE = @"PillrLogo";

/// The "Reflection Example" asset catalog image resource.
static NSString * const ACImageNameReflectionExample AC_SWIFT_PRIVATE = @"Reflection Example";

/// The "cloud" asset catalog image resource.
static NSString * const ACImageNameCloud AC_SWIFT_PRIVATE = @"cloud";

/// The "faceid" asset catalog image resource.
static NSString * const ACImageNameFaceid AC_SWIFT_PRIVATE = @"faceid";

/// The "heart" asset catalog image resource.
static NSString * const ACImageNameHeart AC_SWIFT_PRIVATE = @"heart";

/// The "lock" asset catalog image resource.
static NSString * const ACImageNameLock AC_SWIFT_PRIVATE = @"lock";

/// The "notification" asset catalog image resource.
static NSString * const ACImageNameNotification AC_SWIFT_PRIVATE = @"notification";

/// The "pill" asset catalog image resource.
static NSString * const ACImageNamePill AC_SWIFT_PRIVATE = @"pill";

/// The "tick" asset catalog image resource.
static NSString * const ACImageNameTick AC_SWIFT_PRIVATE = @"tick";

#undef AC_SWIFT_PRIVATE
