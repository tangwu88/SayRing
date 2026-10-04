#pragma once
#import "CoolWearPolicy.h"

// Pure policy shared by the native loop and executable host tests. An accepted
// model name is never sufficient: both context and exact UUID must match.
static inline BOOL CoolWearRecoveryTargetValid(NSString *identifier, NSString *name, NSString *context) {
    return [identifier isKindOfClass:NSString.class] &&
        [[NSUUID alloc] initWithUUIDString:identifier] != nil &&
        CoolWearModel(name) != nil && [context isKindOfClass:NSString.class] && context.length > 0;
}

static inline BOOL CoolWearRecoveryMatches(NSString *identifier, NSString *name,
    NSString *expectedID, NSString *expectedName, NSString *context,
    NSUInteger capturedGeneration, NSUInteger currentGeneration) {
    return capturedGeneration == currentGeneration &&
        [identifier isKindOfClass:NSString.class] &&
        CoolWearRecoveryTargetValid(expectedID, expectedName, context) &&
        [identifier caseInsensitiveCompare:expectedID] == NSOrderedSame &&
        [CoolWearModel(name) isEqual:CoolWearModel(expectedName)];
}
