//
//  RSScanView.h
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// 资源路径
#define kRSScanSrcName(file) [@"RSScan.bundle" stringByAppendingPathComponent:file]
#define kRSScanFrameworkSrcName(file) [@"Frameworks/RSScan.framework/RSScan.bundle" stringByAppendingPathComponent:file]

typedef void (^ScanCancelBlock)(void);
typedef void (^ScanFailerBlock)(NSError *error);
typedef void (^ScanResultBlock)(NSString *scanResult);
typedef void (^BuyScanDeviceBlock)(UIViewController *scanViewController);

@interface RSScanView : UIViewController

/// 扫码取消
@property (nonatomic,copy) ScanCancelBlock cancelBlock;
/// 扫码失败
@property (nonatomic,copy) ScanFailerBlock failerBlock;
/// 扫码成功
@property (nonatomic,copy) ScanResultBlock resultBlock;
/// 点击广告位
@property (nonatomic, copy) BuyScanDeviceBlock advsActionBlock;

/// 扫描类型 def 0二维码  1条码
@property (nonatomic,assign) int scanType;
/// 是否播放声音
@property (nonatomic,assign) BOOL isPlayMusic;
/// 是否自动连续扫描, def NO
@property (nonatomic,assign) BOOL isContinuousAutoScan;
/// 是否显示广告位, def NO
@property (nonatomic,assign) BOOL isShowAdvertising;

//启动扫描 不带参数
- (void)StartScan;

//停止扫描
- (void)StopScan;

@end
