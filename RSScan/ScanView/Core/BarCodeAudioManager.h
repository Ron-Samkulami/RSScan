//
//  BarCodeAudioManager.h
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 *  播放成功回调
 */
typedef void(^didPlayFinish)(void);

@interface BarCodeAudioManager : NSObject
@property (nonatomic, strong) AVAudioSession *session;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) AVAudioRecorder *recorder;

/**
 *  单例
 *
 *  @return 语音管理器对象
 */
+ (instancetype)sharedInstance;

/**
 *  播放语音 (只接受acc/wav格式,不接受amr格式)
 *
 *  @param data      指定格式的语音的二进制数据
 *  @param didFinish 播放成功回调
 */
- (void)playWithData:(NSData *)data finish:(didPlayFinish) didFinish;

/**
 *  停止播放
 */
- (void)stopPlay;


@end
