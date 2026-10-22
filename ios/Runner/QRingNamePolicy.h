#import <Foundation/Foundation.h>

// The user-confirmed model markers select an SDK, never device capabilities.
NS_INLINE BOOL QRingIsSupportedName(NSString * _Nullable name) {
    NSString *upper = [[name ?: @"" stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([upper hasPrefix:@"R1"] || [upper hasPrefix:@"R2"] ||
        [upper containsString:@"R7C"]) return YES;
    NSString *other = [upper stringByReplacingOccurrencesOfString:@"R8[\\s_-]*PRO(?![A-Z])" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, upper.length)];
    if (![other isEqual:upper]) return NO;
    if ([upper containsString:@"R7"] || [upper containsString:@"K80"] ||
        [upper containsString:@"HR01"] || [upper containsString:@"HR05"]) {
        return NO;
    }
    return [upper containsString:@"R8"] || [upper containsString:@"R21"] ||
        [upper containsString:@"R22"] || [upper hasPrefix:@"Q_"] ||
        [upper hasPrefix:@"O_"] || [upper hasPrefix:@"R"];
}
