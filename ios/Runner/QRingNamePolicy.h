#import <Foundation/Foundation.h>

// The user-confirmed model markers select an SDK, never device capabilities.
NS_INLINE BOOL QRingIsSupportedName(NSString * _Nullable name) {
    NSString *upper = [[name ?: @"" stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([upper hasPrefix:@"R1"] || [upper hasPrefix:@"R2"] ||
        [upper containsString:@"R7C"]) return YES;
    if ([upper containsString:@"R7"] || [upper containsString:@"K80"] ||
        [upper containsString:@"HR01"] || [upper containsString:@"HR05"]) {
        return NO;
    }
    return [upper containsString:@"R8"] || [upper containsString:@"R21"] ||
        [upper containsString:@"R22"] || [upper hasPrefix:@"Q_"] ||
        [upper hasPrefix:@"O_"] || [upper hasPrefix:@"R"];
}

// 系统名称可能晚于广播名到达。只使用同一外设的名字；任一来源指向其他通道时停止。
NS_INLINE NSString * _Nullable QRingSelectionName(NSString * _Nullable systemName, NSString * _Nullable observedName) {
    if ((systemName.length && !QRingIsSupportedName(systemName)) ||
        (observedName.length && !QRingIsSupportedName(observedName))) return nil;
    return systemName.length ? systemName : (observedName.length ? observedName : nil);
}
