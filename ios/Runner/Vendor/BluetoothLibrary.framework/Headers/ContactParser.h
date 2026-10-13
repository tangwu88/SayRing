//
//  ContactParser.h
//  BluetoothLibrary
//
//  Created by coolwear on 2023/6/5.
//  Copyright © 2023 kwan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContactParser : NSObject

+ (NSDictionary *)analyze:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
