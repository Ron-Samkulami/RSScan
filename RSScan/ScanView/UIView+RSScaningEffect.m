//
//  UIView+RSScaningEffect.m
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import "UIView+RSScaningEffect.h"

@implementation UIView (RSScaningEffect)

#pragma mark public function

- (void) startScaningRepeatCount:(int)count {
    [self startScaningRepeatCount:count Duration:2 HeightFactor:0.3];
}

- (void) startScaningRepeatCount:(int)count Duration:(int)duration {
    [self startScaningRepeatCount:count Duration:duration HeightFactor:0.3];
}

- (void) startScaningRepeatCount:(int)count Duration:(int)duration HeightFactor:(float) factor {
    CGFloat w = self.frame.size.width;
    CGFloat h = self.frame.size.height;
    
    CALayer *grid = [CALayer layer];
    UIImage *gridImage = [self getGridWithWidth:w Height:h];
    grid.contents = (id)gridImage.CGImage;
    grid.frame = CGRectMake(0, 0, w, h);
    grid.name = @"grid";
    
    CALayer *laser = [CALayer layer];
    //laser.transform = CATransform3DMakeRotation(M_PI, 1, 0, 0); //弧度 = 角度 * pi / 180  floorf(h * factor)
    laser.backgroundColor = [[UIColor clearColor] CGColor];
    UIImage *laserImage = [self getLaserWithWidth:w Height:h];
    laser.contents = (id)laserImage.CGImage;
    laser.frame = CGRectMake(0, -laserImage.size.height, w, h);
    
    CABasicAnimation *downAnimation = [CABasicAnimation animationWithKeyPath:@"position.y"];
    downAnimation.byValue = @(h + laserImage.size.height);
    downAnimation.duration = duration;
    downAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
//    downAnimation.delegate = self;
    downAnimation.beginTime = 0;
    downAnimation.autoreverses = NO;
    downAnimation.repeatCount = count;
    
    grid.mask = laser;
    [self.layer addSublayer:grid];
    
    [laser addAnimation:downAnimation forKey:@"scaning"];
}


- (void) stopScaning {
    for (CALayer *layer in self.layer.sublayers) {
        if ([layer.name isEqualToString:@"grid"]) {
            [layer removeFromSuperlayer];
        }
    }
}


#pragma mark private function

- (UIImage *) getLaserWithWidth:(CGFloat)width Height:(CGFloat)height {
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    id alphaWhiteColor = (__bridge id) [[UIColor alloc] initWithRed:255.0/255 green:255.0/255 blue:255.0/255 alpha:0.0].CGColor;
    id whiteColor = (__bridge id) [UIColor whiteColor].CGColor;
    CGFloat locations[] = { 0.0f, 1.0f, 0.0f };
    NSArray *colors = @[alphaWhiteColor, whiteColor, alphaWhiteColor];
    
    CGGradientRef gradient =  CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGPoint startPoint = CGPointMake(floorf(width / 2), 0);
    CGPoint endPoint = CGPointMake(floorf(width / 2), height);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CFRelease(gradient);
    CFRelease(colorSpace);
    
    UIImage *laser = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return laser;
}

- (UIImage *)getGridWithWidth:(int)width Height:(int)height {
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    for (int y=0; y<height; y=y+3) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, y);
        CGContextAddLineToPoint(context, width, y);
        CGContextStrokePath(context);
    }
    for (int x=0; x<width; x=x+3) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, x, 0);
        CGContextAddLineToPoint(context, x, height);
        CGContextStrokePath(context);
    }
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
