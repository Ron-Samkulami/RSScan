//
//  UIView+RSScaningEffect.h
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (RSScaningEffect)

- (void) startScaningRepeatCount:(int)count;
- (void) startScaningRepeatCount:(int)count Duration:(int)duration;
- (void) startScaningRepeatCount:(int)count Duration:(int)duration HeightFactor:(float) factor;
- (void) stopScaning;

@end

NS_ASSUME_NONNULL_END
