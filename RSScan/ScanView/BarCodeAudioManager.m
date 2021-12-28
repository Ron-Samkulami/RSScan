//
//  BarCodeAudioManager.m
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import "BarCodeAudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface BarCodeAudioManager()<AVAudioPlayerDelegate>
@property (nonatomic, copy) didPlayFinish finishBlock;

@end

@implementation BarCodeAudioManager

+ (instancetype)sharedInstance
{
    static BarCodeAudioManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc ] init];
        [_sharedInstance activeAudioSession];
    });
    
    return _sharedInstance;
}

// 开启始终以扬声器模式播放声音
- (void)activeAudioSession
{
    self.session = [AVAudioSession sharedInstance];
    NSError *sessionError = nil;
    [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride
                             );
#pragma clang diagnostic pop
    
    if(!self.session) {
        NSLog(@"Error creating session: %@", [sessionError description]);
    }
    else {
        //会话活跃
        [self.session setActive:YES error:nil];
    }
    
    //    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)   name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)playWithData:(NSData *)data finish:(void (^)(void))didFinish;
{
    //会话活跃
    NSError *err;
    [self.session setActive:YES error:&err];
    if (err != nil) {
        NSLog(@"会话active失败,err=%@", err);
    }
    
    self.finishBlock = didFinish;
    if (self.player) {
        if (self.player.isPlaying) {
            [self.player stop];
        }
        
        self.player.delegate = nil;
        self.player = nil;
    }
    
    NSError *playerError = nil;
    self.player = [[AVAudioPlayer alloc] initWithData:data error:&playerError];
    if (self.player)  {
        self.player.delegate = self;
        [self.player play];
    } else {
        NSLog(@"Error creating player: %@", [playerError description]);
    }
}
- (void)stopPlay{
    
    if (self.player) {
        if (self.player.isPlaying) {
            [self.player stop];
        }
        
        self.player.delegate = nil;
        self.player = nil;
    }
    
    //取消会话活跃
    NSError *err;
    [self.session setActive:NO error:&err];
    if (err != nil) {
        NSLog(@"会话取消active失败,err=%@", err);
    }
}
@end
