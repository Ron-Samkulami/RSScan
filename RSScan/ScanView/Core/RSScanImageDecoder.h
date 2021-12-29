//
//  RSScanImageDecoder.h
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

/**
 *  扫码图像解析工具
 *  接收CMSampleBufferRef，经裁剪，解析、方向矫正、画面增强、二值化等处理后，再由ZXing进行解码
 *
 *  @author Ron
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ZXingWrapper.h"

typedef struct{
    int imageResolutionW;
    int imageResolutionH;
} ImageResolution;

@interface RSScanImageDecoder : NSObject
/// 图像分辨率，必传
@property (nonatomic, assign) ImageResolution imageResolution;
/// 裁剪框尺寸，Neither imageResolutionW nor imageResolutionH be 0, otherwise cropRect is invalid.
@property (nonatomic, assign) CGRect cropRect;
/// 是否需要重载像素缓冲区，位置变换、切换分辨率、相机重启时需要重载
@property (nonatomic, assign) BOOL needResetPixbuffer;

/**
 解析图像
 */
- (void)decodeSampleBuffer:(CMSampleBufferRef)sampleBuffer processing:(UIImageView*)previewImageView success:(void (^)(NSString *str))success;



@end


