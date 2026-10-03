//
//  RGB565Helper.h
//
//  Created by kwan on 2019/9/28.
//  Copyright © 2019 kwan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Accelerate/Accelerate.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageColorConvertHelper : NSObject

vImage_Error image2RGB565(unsigned char *imageData, UIImage *image, size_t width, size_t height);
vImage_Error image2RGB888(unsigned char *imageData, UIImage *image, size_t width, size_t height);

void bytearrtostr(Byte *data, size_t length);

@end

NS_ASSUME_NONNULL_END
