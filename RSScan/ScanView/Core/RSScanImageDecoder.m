//
//  RSScanImageDecoder.m
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import "RSScanImageDecoder.h"

#define screenW [[UIScreen mainScreen] bounds].size.width //屏幕宽度
#define screenH [[UIScreen mainScreen] bounds].size.height //屏幕高度

@implementation RSScanImageDecoder
{
    int _cropPiexlX;
    int _cropPiexlY;
    int _cropPiexlW;
    int _cropPiexlH;
}
#pragma mark - public
/**
 解析图像
 */
- (void)decodeSampleBuffer:(CMSampleBufferRef)sampleBuffer processing:(UIImageView *)previewImageView success:(void (^)(NSString *))success {
    //获取图像
    UIImage *image = [self getImageFromSampleBuffer:sampleBuffer];
    
    //修正图片方向
    image = [self fixImageOrientation:image];
    
    //滤镜处理,增强画质
    image = [self enhanceImage:image];
    
    //预览增强效果
    dispatch_async(dispatch_get_main_queue(), ^{
        previewImageView.image = image;
    });
    
    //二值化处理
    image = [self convertToGrayScaleWithImage:image];
    
    
    
    //识别图像
    [self recognizeImage:image success:success];
}

/**
 设置裁剪框尺寸
 */
- (void)setCropRect:(CGRect)cropRect {
    _cropRect = cropRect;
    /**
     buffer的方向是右转90度，需要将裁剪框进行坐标转换，并结合分辨率计算裁剪框的像素坐标
     */
    if (self.imageResolution.imageResolutionW*self.imageResolution.imageResolutionH != 0) {
        _cropPiexlX = self.imageResolution.imageResolutionW/screenH * self.cropRect.origin.y;
        _cropPiexlY = self.imageResolution.imageResolutionH/screenW * (screenW-self.cropRect.origin.x-self.cropRect.size.width);
        _cropPiexlW = self.imageResolution.imageResolutionW/screenH * self.cropRect.size.height;
        _cropPiexlH = self.imageResolution.imageResolutionH/screenW * self.cropRect.size.width;
    }
    /**
     当裁剪框尺寸发生改变时，需要重载裁剪时的pixbuffer和videoinfo
     */
    self.needResetPixbuffer = YES;
}

#pragma mark - private
/**
 get Image
 */
- (UIImage *)getImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    //先获取并保存亮度，裁剪时这些信息会丢失
//    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
//    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
//    CFRelease(metadataDict);
//    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
//    _brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    
    CMSampleBufferRef cropSampleBuffer;
    //crop buffer 裁剪
    cropSampleBuffer = [self cropSampleBufferByCPU:sampleBuffer];
    //tranform buffer to image 转换成图像
    UIImage *image = [self imageWithOutputSampleBuffer:cropSampleBuffer];
    CFRelease(cropSampleBuffer);
    
    return image;
}

/**
 crop buffer with CPU
 使用CPU进行裁剪
 */
- (CMSampleBufferRef)cropSampleBufferByCPU:(CMSampleBufferRef)sampleBuffer {
    OSStatus status;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the image buffer
    CVPixelBufferLockBaseAddress(imageBuffer,kCVPixelBufferLock_ReadOnly);
    // Get information about the image
    uint8_t *baseAddress     = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t  bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t  width            = CVPixelBufferGetWidth(imageBuffer);
//    size_t  height           = CVPixelBufferGetHeight(imageBuffer);
    NSInteger bytesPerPixel  =  bytesPerRow/width;

    // YUV 420 Rule
    if (_cropPiexlX % 2 != 0) _cropPiexlX += 1;
    NSInteger baseAddressStart = _cropPiexlY*bytesPerRow+bytesPerPixel*_cropPiexlX;
    static NSInteger lastAddressStart = 0;
    lastAddressStart = baseAddressStart;

    // pixbuffer 与 videoInfo 只有位置变换、切换分辨率、相机重启时需要更新，其余情况不需要
    static CVPixelBufferRef            pixbuffer = NULL;
    static CMVideoFormatDescriptionRef videoInfo = NULL;

    // x,y changed need to reset pixbuffer and videoinfo
    if (lastAddressStart != baseAddressStart || self.needResetPixbuffer == YES) {
        if (pixbuffer != NULL) {
            CVPixelBufferRelease(pixbuffer);
            pixbuffer = NULL;
        }

        if (videoInfo != NULL) {
            CFRelease(videoInfo);
            videoInfo = NULL;
        }
        
        if (self.needResetPixbuffer == YES) {
            self.needResetPixbuffer = NO;
        }
    }

    if (pixbuffer == NULL) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool : YES],           kCVPixelBufferCGImageCompatibilityKey,
                                 [NSNumber numberWithBool : YES],           kCVPixelBufferCGBitmapContextCompatibilityKey,
                                 [NSNumber numberWithInt  : _cropPiexlW],  kCVPixelBufferWidthKey,
                                 [NSNumber numberWithInt  : _cropPiexlH], kCVPixelBufferHeightKey,
                                 nil];

        status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, _cropPiexlW, _cropPiexlH, kCVPixelFormatType_32BGRA, &baseAddress[baseAddressStart], bytesPerRow, NULL, NULL, (__bridge CFDictionaryRef)options, &pixbuffer);
        if (status != 0) {
            NSLog(@"Crop CVPixelBufferCreateWithBytes error %d",(int)status);
            return NULL;
        }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer,kCVPixelBufferLock_ReadOnly);

    CMSampleTimingInfo sampleTime = {
        .duration               = CMSampleBufferGetDuration(sampleBuffer),
        .presentationTimeStamp  = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        .decodeTimeStamp        = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    };

    if (videoInfo == NULL) {
        status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, &videoInfo);
        if (status != 0) NSLog(@"Crop CMVideoFormatDescriptionCreateForImageBuffer error %d",(int)status);
    }

    CMSampleBufferRef cropBuffer = NULL;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixbuffer, true, NULL, NULL, videoInfo, &sampleTime, &cropBuffer);
    if (status != 0) NSLog(@"Crop CMSampleBufferCreateForImageBuffer error %d",(int)status);

    lastAddressStart = baseAddressStart;

    return cropBuffer;
}

/**
 解析图像
 */
- (UIImage *)imageWithOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    UIImage *image = nil;
    @try {
        
        //解析图像
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        CVPixelBufferLockBaseAddress(imageBuffer,kCVPixelBufferLock_ReadOnly);
    #warning 偶发崩溃，转换出来的baseAddress为空
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGImageRef newImage = CGBitmapContextCreateImage(newContext);
        CGContextRelease(newContext);
        CGColorSpaceRelease(colorSpace);
        
        image = [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationRight];
        
        CGImageRelease(newImage);
        CVPixelBufferUnlockBaseAddress(imageBuffer,kCVPixelBufferLock_ReadOnly);

    } @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
    }
    
    return image;
}

/**
 修正图片方向
 */
- (UIImage *)fixImageOrientation:(UIImage *)image{
    
    UIImageOrientation imageOrientation = image.imageOrientation;
    CGFloat imgWidth = image.size.width;
    CGFloat imgHeight = image.size.height;
    
    // No-op if the orientation is already correct
    if (imageOrientation == UIImageOrientationUp) return image;
    
    // Calculate the proper transformation to make the image upright.
    // Do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, imgHeight);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, imgHeight);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, imgWidth, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, imgHeight, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Draw the underlying CGImage into a new context, applying the transform
    CGContextRef ctx = CGBitmapContextCreate(NULL, imgWidth, imgHeight,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,imgHeight,imgWidth), image.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,imgWidth,imgHeight), image.CGImage);
            break;
    }
    
    // Create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [[UIImage alloc]initWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

/**
 图像画质增强处理
 */
- (UIImage *)enhanceImage:(UIImage *)sourceImage {
    CIImage *sourceCIImage = [CIImage imageWithCGImage:sourceImage.CGImage];

    //1、调节亮度
    CIFilter *brightenFilter = [CIFilter filterWithName:@"CIColorControls"
                             withInputParameters:@{
                                 kCIInputImageKey:sourceCIImage,
//                                 kCIInputSaturationKey:[NSNumber numberWithFloat:0.9],//饱和度0.9
                                 kCIInputBrightnessKey:[NSNumber numberWithFloat:0.17],//亮度0.19
                                 kCIInputContrastKey:[NSNumber numberWithFloat:1.31],//对比度1.32
                             }];
    CIImage *brightenCIImage = [brightenFilter outputImage];
    
    //2、调节曝光
    CIFilter *exposureFilter = [CIFilter filterWithName:@"CIExposureAdjust" withInputParameters:@{
        kCIInputImageKey:brightenCIImage,
        kCIInputEVKey:[NSNumber numberWithFloat:1.1],//曝光度1.1
    }];
    CIImage *outputCIImage = [exposureFilter outputImage];
    
    //3、输出处理后的图片
    CIContext *context = [CIContext contextWithOptions: nil];
    CGImageRef outputCGImage = [context createCGImage:outputCIImage fromRect:[outputCIImage extent]];
    UIImage *outputImage = [UIImage imageWithCGImage:outputCGImage];
    
    CGImageRelease(outputCGImage);
    return outputImage;
}

/**
 二值化处理
 */
- (UIImage *)convertToGrayScaleWithImage:(UIImage *)sourceImage{
    
    CGImageRef imageRef = [sourceImage CGImage];
    
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = width*sizeof(uint32_t);
    
    //像素将画在这个数组
    uint32_t *pixels = (uint32_t *)malloc(width *height * sizeof(uint32_t));
    //清空像素数组
    memset(pixels, 0, width*height*sizeof(uint32_t));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    //用 pixels 创建一个 context
    CGContextRef context =CGBitmapContextCreate(pixels, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    int tt =1;
    CGFloat intensity;
    int bw;
    
    for (int y = 0; y <height; y++) {
        for (int x =0; x <width; x ++) {
            uint8_t *rgbaPixel = (uint8_t *)&pixels[y*width+x];
            intensity = (rgbaPixel[tt] + rgbaPixel[tt + 1] + rgbaPixel[tt + 2]) / 3. / 255.;
            
            bw = intensity > 0.45?255:0;
            
            rgbaPixel[tt] = bw;
            rgbaPixel[tt + 1] = bw;
            rgbaPixel[tt + 2] = bw;
        }
    }

    // create a new CGImageRef from our context with the modified pixels
    CGImageRef image = CGBitmapContextCreateImage(context);
    
    // Done with the context, color space, and pixels
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    // Make a new UIImage to return
    UIImage *resultUIImage = [UIImage imageWithCGImage:image];
    // Done with image now too
    CGImageRelease(image);
    
    return resultUIImage;
}

/**
 识别图片
 */
- (void)recognizeImage:(UIImage *)image success:(void (^)(NSString *))success {
    //    __weak __typeof__(self) weakSelf = self;
    [ZXingWrapper recognizeImage:image block:^(ZXBarcodeFormat barcodeFormat, NSString *str) {
        //        __typeof__(self) self = weakSelf;
        if (str != nil && str.length > 0) {
            //recognize successfully
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) success(str);
            });
        }
    }];
}
@end
