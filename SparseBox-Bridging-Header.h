//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
@import UIKit;
#import "minimuxer-Bridging-Header.h"

#pragma mark - Private API
@interface UIDevice(Private)
@property(nonatomic, strong, readonly) NSString *buildVersion;
+ (BOOL)_hasHomeButton;
@end
