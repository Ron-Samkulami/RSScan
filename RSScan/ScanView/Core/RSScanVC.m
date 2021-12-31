//
//  RSScanVC.m
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

/**
 图像采集session同时输出两个数据流：
 1、AVCaptureMetadataOutput，用于原生框架解析获取
 2、AVCaptureVideoDataOutput，视频输出流，每TimerInterval(0.2)秒截取一帧buffer，经裁剪，解析、方向矫正、画面增强、二值化等处理后，再由ZXing进行解码
 */

#import "RSScanVC.h"
#import "UIView+RSScaningEffect.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <PhotosUI/PhotosUI.h>
#import "BarCodeAudioManager.h"
#import "RSScanImageDecoder.h"
#import "RSScanNotificationConstants.h"

#define screenW [[UIScreen mainScreen] bounds].size.width //屏幕宽度
#define screenH [[UIScreen mainScreen] bounds].size.height //屏幕高度
#define statusBarH 0 //自定义状态栏高度

#define backBtnWH 40 //返回按钮宽高
#define flashBtnWH 40 //闪光灯按钮宽高
#define marginSpace 15 //边缘距离
#define flashToBar ((UIWindowScene *)[[[UIApplication sharedApplication]connectedScenes]allObjects][0]).statusBarManager.statusBarFrame.size.height //闪光灯按钮顶部距离

//扫描框
#define defaultScanZoneQRW 250 //二维码扫描框宽
#define defaultScanZoneQRH 250 //二维码扫描框高
#define defaultScanZoneBARW screenW-6*marginSpace //条码扫描框宽
#define defaultScanZoneBARH 120 //条码扫描框高
#define tipsLabelH 25 //提示文字高度

//底部按钮
#define buttonsViewH 96 //背景视图高度
#define bottomZoneHeigth 80 //按钮顶端与屏幕底距离
#define advertisingBtnWH 80 //广告位按钮宽高
#define qrcodeBtnWH 40 //二维码按钮宽高
#define odCodeBtnWH 40 //条码按钮宽高
#define localImageBtnWH 40 //本地图片按钮宽高

#define labelToButton 7 //按钮和标签的距离
#define labelHeight 15 //按钮标签高度
#define labelFontSize 12 //按钮标签字体
#define smalllabelFontSize 10 //按钮标签字体

#define flashBtnID 101 //闪光灯按钮ID
#define backBtnID 102 //返回按钮ID
#define qrCodeBtnID 103 //二维码按钮ID
#define barCodeBtnID 104 //条码按钮ID
#define localImageBtnID 105 //本地图片按钮ID
#define advertisingBtnID 106 //广告位按钮ID
#define filterPreviewCtrBtnID 999 //滤镜预览窗控制按钮ID

#define highlightLabelColor [UIColor colorWithRed:247/255.0 green:77/255.0 blue:97/255.0 alpha:1] //高亮颜色
#define viewBackgroundColor [[UIColor colorWithRed:53/255.0 green:53/255.0 blue:53/255.0 alpha:1]colorWithAlphaComponent:0.6] //背景颜色

#define TimerInterval 0.2 //计时器间隔

@interface RSScanVC ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate,AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

/// 扫码计时器
@property (nonatomic, strong) NSTimer *decodeTimer;
/// 扫码持续时间
@property (nonatomic, assign) NSTimeInterval totalScanTimeInterval;
/// 是否捕获图片
@property (nonatomic, assign) BOOL canCaptureImage;
/// 是否正在处理扫码结果，避免两种解析方式重复返回结果
@property (nonatomic, assign) BOOL isDealingScanResult;
/// 扫码图像解析工具
@property (nonatomic, strong) RSScanImageDecoder *imageDecoder;

@end

@implementation RSScanVC {
    //顶部栏背景
    UIView *_statusBarView;
    //返回按钮
    UIButton *_backBtn;
    //闪光灯按钮
    UIButton *_flashBtn;
    
    //主界面背景
    UIView * _topView;
    UIView * _leftView;
    UIView * _rightView;
    UIView * _bottomView;
    //扫描框
    UIImageView *_scanRect;
    UILabel *_centerTipsLabel;
    
    //底部按钮区背景
    UIView *_buttonsView;
    //广告位按钮
    UIButton *_advertisingBtn;
    //二维码
    UIButton *_qrCodeBtn;
    //条形
    UIButton *_barCodeBtn;
    //选择本地图片
    UIButton *_localImageBtn;
    //银行卡
    UIButton *_cardBtn;
    //提示文字
    UILabel *_advertisingLabel;
    UILabel *_qrCodeLabel;
    UILabel *_barCodeLabel;
    UILabel *_localImageLabel;
    UILabel *_cardLabel;
    //动画定时器
    NSTimer *_scanRectAnimatingTimer;
    
    //摄像设备
    AVCaptureDevice *_device;
    //链接对象
    AVCaptureSession *_session;
    //输入流
    AVCaptureDeviceInput *_input;
    //元数据输出流，用于原生解码
    AVCaptureMetadataOutput * _metaOutput;
    //视频输出流，用于ZXing解析
    AVCaptureVideoDataOutput *_videoOutput;
    //视频抓屏预览层
    AVCaptureVideoPreviewLayer *_preview;
    //FOR DEBUG，滤镜预览框
    UIImageView *_filterPreview;
    //滤镜预览框控制按钮
    UIButton *_filterPreviewCtrBtn;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.imageDecoder = [[RSScanImageDecoder alloc] init];
    }
    return self;
}

#pragma mark - life circle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isPlayMusic=YES;
    [self addObserver];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startScanAnimation];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self endTiming];
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Observer

- (void)addObserver {
    //监听屏幕旋转
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    //监听Scene进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sceneDidEnterBackgroundNotification:) name:rsSceneDidEnterBackgroundNotification object:nil];
    //监听Scene进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sceneDidBecomeActiveNotification:) name:rsSceneDidBecomeActiveNotification object:nil];
}

#pragma mark - 开始扫码
/**
 开始扫码
 */
- (void)StartScan {
    switch (self.scanType) {
        case 0:
            [self startScan:defaultScanZoneQRW H:defaultScanZoneQRH];
            break;
        case 1:
            [self startScan:defaultScanZoneBARW H:defaultScanZoneBARH];
            break;
        default:
            break;
    }
}

- (void)startScan:(float)width H:(float)height {
    //初始化采集会话
    [self initAVCapture];
    //初始化扫描界面
    [self initScanZoneW:width H:height];
    //关闭闪光灯
    [self setTorchMode:0];
    //设置有效识别区域
    [self setValidateZone];
    //开启会话
    [self startSession];
    //开启扫码计时器
    [self scheduledTimer];
}

/**
 判断相机权限后再开启会话
 */
- (void)startSession {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        //创建弹窗
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"请在iPhone的“设置”-“隐私”-“相机”功能中，找到“RSScan”打开相机访问权限" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"OK Action");
        }];
        [alertVC addAction:okAction];
        
        //显示弹窗
        UIWindowScene *windowScene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] allObjects][0];
        UIWindow *window = windowScene.windows[0];
        alertVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [window.rootViewController presentViewController:alertVC animated:NO completion:nil];
        return;
    }
    
    [_session startRunning];
}

/**
 停止扫码
 */
- (void)stopScan {
    //结束会话、计时器
    [_session stopRunning];
    [self endTiming];
}

#pragma mark - 初始化扫描界面
- (void)initScanZoneW:(float)width H:(float)height {
    [self.view setBackgroundColor:[UIColor whiteColor]];
    //状态栏界面
    _statusBarView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, screenW, statusBarH)];
    _statusBarView.backgroundColor = [UIColor blackColor];
    //屏幕背景颜色
    _topView = [[UIView alloc]init];
    _topView.backgroundColor = viewBackgroundColor;
    _leftView = [[UIView alloc]init];
    _leftView.backgroundColor = viewBackgroundColor;
    _rightView = [[UIView alloc]init];
    _rightView.backgroundColor = viewBackgroundColor;
    _bottomView = [[UIView alloc]init];
    _bottomView.backgroundColor = viewBackgroundColor;
    [self setBackgoundViewWidth:width height:height];
    
    //返回按钮
    _backBtn=[[UIButton alloc] init];
    [self setButtonBackgroundImageNormal:_backBtn ImageName:@"hyback2.png"];
    [self setButtonBackgroundImageSelected:_backBtn ImageName:@"hyback1.png"];
    _backBtn.frame=CGRectMake(marginSpace, flashToBar, backBtnWH, backBtnWH);
    [_backBtn setTag:backBtnID];
    [_backBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    //闪光灯按钮
    _flashBtn=[[UIButton alloc] init];
    [self setButtonBackgroundImageNormal:_flashBtn ImageName:@"light2.png"];
    [self setButtonBackgroundImageSelected:_flashBtn ImageName:@"light1.png"];
    _flashBtn.frame=CGRectMake(screenW-flashBtnWH-marginSpace, flashToBar, flashBtnWH, flashBtnWH);
    [_flashBtn setTag:flashBtnID];
    [_flashBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    
#if DEBUG
    //    滤镜预览窗
    _filterPreview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, screenW, screenH*0.4)];
    _filterPreview.hidden = YES;
    
    _filterPreviewCtrBtn=[[UIButton alloc] init];
    [_filterPreviewCtrBtn setTitle:@"打开滤镜窗" forState:UIControlStateNormal];
    [_filterPreviewCtrBtn setTitle:@"关闭滤镜窗" forState:UIControlStateSelected];
    _filterPreviewCtrBtn.frame=CGRectMake(screenW-flashBtnWH*3-marginSpace, flashToBar*2, flashBtnWH*3, flashBtnWH);
    [_filterPreviewCtrBtn setTag:filterPreviewCtrBtnID];
    [_filterPreviewCtrBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
#else
#endif
    
    //扫码框
    _scanRect = [[UIImageView alloc]init];
    _scanRect.frame = CGRectMake((screenW-width)/2, (screenH-height)/2.0-statusBarH, width, height);
    UIImage *pic = [UIImage imageNamed:kRSScanSrcName(@"scan_bg.png")];
    pic = [pic resizableImageWithCapInsets:UIEdgeInsetsMake(20,20,20,20) resizingMode:UIImageResizingModeStretch];
    _scanRect.image = pic;
    //提示文字
    _centerTipsLabel=[[UILabel alloc] init];
    _centerTipsLabel.frame=CGRectMake(CGRectGetMinX(_scanRect.frame), CGRectGetMaxY(_scanRect.frame)+20, _scanRect.frame.size.width,tipsLabelH);
    NSString *scanTips = self.scanType == 0 ? @"请将二维码放入框内，即可自动扫描" : @"请将条形码放入框内，即可自动扫描";
    [self setLabelFontTitleColor:_centerTipsLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:scanTips];
    
    //底部按钮背景
    _buttonsView = [[UIView alloc] init];
    _buttonsView.backgroundColor = [[UIColor blackColor]colorWithAlphaComponent:0.6];
    //广告位
    _advertisingBtn=[[UIButton alloc] init];
//    [self setButtonBackgroundImageNormal:_advertisingBtn ImageName:@"global_icon_machine_default"];
    [_advertisingBtn setImage:[self createImageWithColor:[UIColor yellowColor]] forState:UIControlStateNormal];
    [_advertisingBtn setTag:advertisingBtnID];
    [_advertisingBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    _advertisingLabel=[[UILabel alloc] init];
    _advertisingLabel.backgroundColor = highlightLabelColor;
    [self setLabelFontTitleColor:_advertisingLabel FontSize:smalllabelFontSize Color:[UIColor whiteColor] Title:@"这是一个广告位"];
    //二维码
    _qrCodeBtn=[[UIButton alloc] init];
    [self setButtonBackgroundImageNormal:_qrCodeBtn ImageName:@"two_dimension_code-default"];
    [self setButtonBackgroundImageSelected:_qrCodeBtn ImageName:@"two_dimension_code_selected"];
    [_qrCodeBtn setTag:qrCodeBtnID];
    [_qrCodeBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    _qrCodeLabel=[[UILabel alloc] init];
    [self setLabelFontTitleColor:_qrCodeLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:@"二维码"];
    //条形码
    _barCodeBtn=[[UIButton alloc] init];
    [self setButtonBackgroundImageNormal:_barCodeBtn ImageName:@"bar_code_default.png"];
    [self setButtonBackgroundImageSelected:_barCodeBtn ImageName:@"bar_code_secelted.png"];
    [_barCodeBtn setTag:barCodeBtnID];
    [_barCodeBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    _barCodeLabel=[[UILabel alloc] init];
    [self setLabelFontTitleColor:_barCodeLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:@"条形码"];
    //相册按钮
    _localImageBtn=[[UIButton alloc] init];
    [self setButtonBackgroundImageNormal:_localImageBtn ImageName:@"photo_default.png"];
    [self setButtonBackgroundImageSelected:_localImageBtn ImageName:@"photo_selected.png"];
    [_localImageBtn setTag:localImageBtnID];
    _localImageBtn.userInteractionEnabled = YES;
    [_localImageBtn addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    _localImageLabel = [[UILabel alloc] init];
    [self setLabelFontTitleColor:_localImageLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:@"相册"];
    //设置Frame
    [self setFrameForBottomView];
    //设置按钮选中状态
    if (self.scanType == 0) {
        _qrCodeBtn.selected = YES;
        _barCodeBtn.selected = NO;
    } else {
        _qrCodeBtn.selected = NO;
        _barCodeBtn.selected = YES;
    }
    //广告位label设置圆角
    UIRectCorner corner = UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomLeft;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:_advertisingLabel.bounds byRoundingCorners:corner cornerRadii:CGSizeMake(10, 10)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = _advertisingLabel.bounds;
    maskLayer.path = path.CGPath;
    _advertisingLabel.layer.mask = maskLayer;
    
    [self.view addSubview:_statusBarView];
    [self.view addSubview:_topView];
    [self.view addSubview:_leftView];
    [self.view addSubview:_rightView];
    [self.view addSubview:_bottomView];
    [self.view addSubview:_buttonsView];
    [self.view addSubview:_backBtn];
    [self.view addSubview:_flashBtn];
    [self.view addSubview:_scanRect];
    [self.view addSubview:_centerTipsLabel];
    [self.view addSubview:_advertisingBtn];
    [self.view addSubview:_advertisingLabel];
    [self.view addSubview:_qrCodeBtn];
    [self.view addSubview:_qrCodeLabel];
    [self.view addSubview:_barCodeBtn];
    [self.view addSubview:_barCodeLabel];
    [self.view addSubview:_localImageBtn];
    [self.view addSubview:_localImageLabel];
    [self.view addSubview:_filterPreview];
    [self.view addSubview:_filterPreviewCtrBtn];
}


#pragma mark - UI设置
/**
 设置有效识别区域
 */
- (void)setValidateZone {
    //设置原生扫码识别范围CGRect(Y,X,H,W)
//    CGRect rect=CGRectMake(image.frame.origin.y/screenH,image.frame.origin.x/screenW,image.frame.size.height/screenH,image.frame.size.width/screenW);
//    [metaOutput setRectOfInterest:rect];
    
    //设置ZXing图像识别范围（解析工具类内会做坐标转换等处理）
    self.imageDecoder.cropRect = CGRectMake(_scanRect.frame.origin.x, _scanRect.frame.origin.y, _scanRect.frame.size.width, _scanRect.frame.size.height);
    
    [_filterPreview setFrame:CGRectMake(_scanRect.frame.origin.x, _scanRect.frame.origin.y, _scanRect.frame.size.width, _scanRect.frame.size.height)];
}

/**
 设置背景
 */
- (void)setBackgoundViewWidth:(float)width height:(float)height {
    _topView.frame=CGRectMake(0, 0, screenW, (screenH-height)/2.0-statusBarH);
    _leftView.frame=CGRectMake(0, _topView.frame.origin.y+(screenH-height)/2.0-statusBarH, (screenW-width)/2.0, height);
    _rightView.frame=CGRectMake((screenW-width)/2.0+width, _topView.frame.origin.y+(screenH-height)/2.0-statusBarH, screenW-((screenW-width)/2.0+width), height);
    _bottomView.frame=CGRectMake(0, (screenH-height)/2.0-statusBarH+height, screenW, screenH-((screenH-height)/2.0-statusBarH+height)-buttonsViewH);
}
 
/**
 设置label
 */
- (void)setLabelFontTitleColor:(UILabel *)label FontSize:(float)size Color:(UIColor *)color Title:(NSString *)title {
    [label setText:title];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setTextColor:color];
    [label setFont:[UIFont fontWithName:@"HelveticaNeue" size:size]];
}

/**
 设置按钮正常状态背景
 */
- (void)setButtonBackgroundImageNormal:(UIButton *)button ImageName:(NSString *)imageName {
    UIImage *imgNormal = [UIImage imageNamed:kRSScanSrcName(imageName)]?:[UIImage imageNamed:kRSScanFrameworkSrcName(imageName)];
     [button setBackgroundImage:imgNormal forState:UIControlStateNormal];
}

/**
 设置按钮选中状态背景
 */
- (void)setButtonBackgroundImageSelected:(UIButton *)button ImageName:(NSString *)imageName {
     UIImage *imgSelected = [UIImage imageNamed:kRSScanSrcName(imageName)]?:[UIImage imageNamed:kRSScanFrameworkSrcName(imageName)];
    [button setBackgroundImage:imgSelected forState:UIControlStateSelected];
}

///设置底部相关视图Frame
- (void)setFrameForBottomView {
    //背景
    _buttonsView.frame = CGRectMake(0, screenH-buttonsViewH, screenW, buttonsViewH);
    
    CGFloat btnHorizontalSpace = (screenW-advertisingBtnWH-qrcodeBtnWH-odCodeBtnWH-localImageBtnWH-marginSpace*2)/3.0;
    if (self.isShowAdvertising) {
        _advertisingBtn.frame=CGRectMake(marginSpace, screenH-bottomZoneHeigth-10, advertisingBtnWH, advertisingBtnWH);
        _advertisingLabel.frame=CGRectMake(_buttonsView.frame.origin.x+5, _buttonsView.frame.origin.y-10, _advertisingBtn.frame.size.width, 20);
        _qrCodeBtn.frame=CGRectMake(screenW/2.0-btnHorizontalSpace*0.5-qrcodeBtnWH, screenH-bottomZoneHeigth, qrcodeBtnWH, qrcodeBtnWH);
        _barCodeBtn.frame = CGRectMake(screenW/2.0+btnHorizontalSpace*0.5, screenH-bottomZoneHeigth, odCodeBtnWH, odCodeBtnWH);
        _localImageBtn.frame = CGRectMake(screenW/2.0+odCodeBtnWH+btnHorizontalSpace*1.5,  screenH-bottomZoneHeigth, localImageBtnWH, localImageBtnWH);
    } else {
        _advertisingBtn.hidden = YES;
        _advertisingLabel.hidden = YES;
        _qrCodeBtn.frame=CGRectMake(marginSpace*2, screenH-bottomZoneHeigth, qrcodeBtnWH, qrcodeBtnWH);
        _barCodeBtn.frame = CGRectMake(screenW/2.0-odCodeBtnWH/2.0, screenH-bottomZoneHeigth, odCodeBtnWH, odCodeBtnWH);
        _localImageBtn.frame = CGRectMake(screenW-localImageBtnWH-marginSpace*2,  screenH-bottomZoneHeigth, localImageBtnWH, localImageBtnWH);
    }
    _qrCodeLabel.frame = CGRectMake(_qrCodeBtn.frame.origin.x, CGRectGetMaxY(_qrCodeBtn.frame)+labelToButton, _qrCodeBtn.frame.size.width, labelHeight);
    _barCodeLabel.frame = CGRectMake(_barCodeBtn.frame.origin.x, CGRectGetMaxY(_barCodeBtn.frame)+labelToButton, _barCodeBtn.frame.size.width, labelHeight);
    _localImageLabel.frame = CGRectMake(_localImageBtn.frame.origin.x, CGRectGetMaxY(_localImageBtn.frame)+labelToButton, _localImageBtn.frame.size.width, labelHeight);
}


#pragma mark - 设置采集会话
- (void)initAVCapture {
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    //输入流
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
    
   //元数据输出流，用于原生解码框架
    _metaOutput = [[AVCaptureMetadataOutput alloc]init];
    [_metaOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //视频输出流，用于ZXing软解析
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)];
    //指定像素的输出格式，这个参数直接影响到生成图像的成功与否
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [_videoOutput setVideoSettings:videoSettings];
    
    //创建采集会话
    _session = [[AVCaptureSession alloc]init];
    //设置采集和解析分辨率
    [_session setSessionPreset:AVCaptureSessionPreset1920x1080];
    //解析分辨率要和采集分辨率一致
    ImageResolution resolution = {1920,1080};
    self.imageDecoder.imageResolution = resolution;
    if (_input) {
        [_session addInput:_input];
        [_session addOutput:_metaOutput];
        [_session addOutput:_videoOutput];
        
        //设置扫码支持的编码格式
        [self setSupportedScanType];
        
        //设置预览层
        _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        _preview.videoGravity=AVLayerVideoGravityResizeAspectFill;
        _preview.frame=self.view.layer.bounds;
        _preview.connection.videoOrientation = [self videoOrientationFromCurrentDeviceOrientation];
        [self.view.layer insertSublayer:_preview atIndex:0];
    }
}


/**
 设置支持的编码格式
 */
- (void)setSupportedScanType {
    if (self.scanType == 1) {
        //只扫描条形码，全屏扫描
        _metaOutput.metadataObjectTypes = @[AVMetadataObjectTypeEAN13Code,  AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeITF14Code,AVMetadataObjectTypeInterleaved2of5Code];
    } else {
        //兼容二维码和条形码（条形码只有中间区域有效识别）
        _metaOutput.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypePDF417Code,AVMetadataObjectTypeAztecCode,AVMetadataObjectTypeDataMatrixCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeITF14Code,AVMetadataObjectTypeInterleaved2of5Code];
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
/// 原生框架解码结果
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSString * stringValue ;
    if (metadataObjects.count > 0 && self.isDealingScanResult == NO) {
        self.isDealingScanResult = YES;
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        stringValue = metadataObject.stringValue;
        
        /**
         *  解决EAN编码前缀有0问题，改成UPC-A编码
         *  UPC-A条码实际上是EAN-13条码的子集。如果一个EAN-13条码的第一位数字是0，那么这个条码既是EAN-13码也同样是是UPC-A码（去掉开头的0）。
         */
        if (metadataObject.type == AVMetadataObjectTypeEAN13Code &&
            stringValue.length > 0 &&
            [stringValue characterAtIndex:0] == '0') {
            stringValue = [stringValue substringFromIndex:1];
        }
        
#if DEBUG
        NSLog(@"RSScanView-totalScanTime: %.1f__BY: MetadataObjects__Result: %@",self.totalScanTimeInterval,stringValue);
        stringValue = [NSString stringWithFormat:@"%.1fs_M: %@",self.totalScanTimeInterval,stringValue];
#else
#endif
        [self scanSuccessWithResult:stringValue];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
/// 获得视频输出流
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //捕捉图像进行软解码
    if (self.canCaptureImage == YES) {
        self.canCaptureImage = NO;
        __weak __typeof__(self) weakSelf = self;
        [self.imageDecoder decodeSampleBuffer:sampleBuffer processing:_filterPreview success:^(NSString *str) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf.isDealingScanResult == NO) {
                strongSelf.isDealingScanResult = YES;
#if DEBUG
                NSLog(@"RSScanView-totalScanTime: %.1f __ BY: ZXingWrapper __ Result: %@",self.totalScanTimeInterval,str);
                str = [NSString stringWithFormat:@"%.1fs_Z: %@",self.totalScanTimeInterval,str];
#else
#endif
                [self scanSuccessWithResult:str];
            }
        }];
    }
}

#pragma mark - 扫码成功
/**
 扫码成功
 */
- (void)scanSuccessWithResult:(NSString *)result {
    [self playScanMusic];
    AudioServicesPlaySystemSoundWithCompletion(1520, nil);
    if (self.resultBlock) {
        self.resultBlock(result);
    }
    
    if (self.isContinuousAutoScan == NO) {
        //单次扫描，立即退出扫码界面
        [self stopScan];
        [self dismissViewControllerAnimated:YES completion:nil];
        
    } else {
        //连续扫描，重启扫码会话和计时器
        [_session stopRunning];
        [self endTiming];
        
        self.totalScanTimeInterval = 0;
        self.isDealingScanResult = NO;
        //设置有效识别区域
        [self setValidateZone];
        [self startSession];
        [self scheduledTimer];
    }
}

/**
 播放提示音
 */
- (void)playScanMusic {
    if (self.isPlayMusic==YES) {
        if ([BarCodeAudioManager sharedInstance].player.isPlaying == NO) {
            //“叮”
            NSString *path = [[NSBundle mainBundle] pathForResource:@"RSScan.bundle/rs_scan_succ_music.mp3" ofType:nil];
            NSData *data = [[NSData alloc] initWithContentsOfFile:path];
            [[BarCodeAudioManager sharedInstance] playWithData:data finish:^{
                [[BarCodeAudioManager sharedInstance] stopPlay];
            }];
        }
    }
}

#pragma mark- Button Action
- (void)buttonClick:(UIButton *)button {
    switch (button.tag) {
        
        case qrCodeBtnID://二维码扫码
        {
            _barCodeBtn.selected = NO;
            _localImageBtn.selected = NO;
            _qrCodeBtn.selected = YES;
            
            self.scanType=0;
            [self setScanZoneW:defaultScanZoneQRW H:defaultScanZoneQRH];
            [self setLabelFontTitleColor:_centerTipsLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:@"请将二维码放入框内，即可自动扫描"];
        }
            break;
        
        case barCodeBtnID://条形码扫码
        {
            _qrCodeBtn.selected = NO;
            _localImageBtn.selected = NO;
            _barCodeBtn.selected = YES;
            
            self.scanType=1;
            [self setScanZoneW:defaultScanZoneBARW H:defaultScanZoneBARH];
            [self setLabelFontTitleColor:_centerTipsLabel FontSize:labelFontSize Color:[UIColor whiteColor] Title:@"请将条形码放入框内，即可自动扫描"];
        }
            break;
        
        case advertisingBtnID://点击广告位
        {
            if (_advsActionBlock) {
                _advsActionBlock(self);
            }
        }
            break;
        
        case flashBtnID://闪光灯
        {
            [self setTorchMode:_device.torchMode == 0?1:0];
        }
            break;
        
        case localImageBtnID://本地图片扫描
        {
            [self LocalPhoto];
            _qrCodeBtn.selected = NO;
            _barCodeBtn.selected = NO;
            _localImageBtn.selected = YES;
        }
            break;
        
        case backBtnID://返回
        {
            [self dismissViewControllerAnimated:YES completion:^{
                if (self.cancelBlock) {
                    self.cancelBlock();
                }
            }];
        }
            break;
        
        case filterPreviewCtrBtnID://滤镜预览窗控制按钮
        {
            _filterPreviewCtrBtn.selected = !_filterPreviewCtrBtn.selected;
            _filterPreview.hidden = !_filterPreviewCtrBtn.selected;
        }
            break;
        
        default:
            break;
    }
}

#pragma mark - 选择本地图片
- (void)LocalPhoto {
    __weak typeof(RSScanVC *) weakSelf = self;
    //判断权限
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusRestricted ||
        status == PHAuthorizationStatusDenied||status==PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
            if (status==PHAuthorizationStatusAuthorized) {
                [weakSelf initImagePickerController];
            }
        }];
    } else {
        [self initImagePickerController];
    }
}

//显示图片选择控制器
- (void)initImagePickerController {
//    dispatch_async(dispatch_get_main_queue(), ^{
        UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
        ipc.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        ipc.delegate = self;
        [self presentViewController:ipc animated:YES completion:nil];
//    });
    
}

//选中图片回调
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    //当选择的类型是图片
    NSString *str = (__bridge_transfer NSString *)kUTTypeImage;
    if ([type isEqualToString:str]) {
        UIImage *scanImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        CIImage *ciImage = [CIImage imageWithCGImage:[scanImage CGImage]];
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
        NSArray * feature = [detector featuresInImage:ciImage];
        if (feature&&feature.count>0) {
            for (CIQRCodeFeature * result in feature) {
                NSString * resultStr = result.messageString;
                if (self.resultBlock) {
                    [picker dismissViewControllerAnimated:YES completion:nil];
                    [self stopScan];
                    [self dismissViewControllerAnimated:YES  completion:^{
                        self.resultBlock(resultStr);
                    }];
                    break;
                }
            }
        } else {
            if (self.faileBlock) {
                [picker dismissViewControllerAnimated:YES completion:nil];
                [self stopScan];
                [self dismissViewControllerAnimated:YES completion:^{
                    self.faileBlock([NSError errorWithDomain:@"未识别到有效的二维码" code:0 userInfo:nil]);
                }];
            }
        }
        
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    _qrCodeBtn.selected = self.scanType == 0;
    _barCodeBtn.selected = self.scanType == 1;
    _localImageBtn.selected = NO;
}

#pragma mark- 扫描动画
/**
 设置扫描框
 */
- (void)setScanZoneW:(float)w H:(float)h {
    [_scanRect stopScaning];
    
    //扫码动画框尺寸
    CGRect rect = CGRectMake((screenW-w)/2, (screenH-h)/2.0-statusBarH, w, h);
    CGRect tipsRect = CGRectMake(rect.origin.x
                               , rect.origin.y+rect.size.height+20
                               , w
                               ,tipsLabelH);
    [UIView animateWithDuration:0.3 animations:^{
        [self setBackgoundViewWidth:w height:h];
        self->_scanRect.frame=rect;
        self->_centerTipsLabel.frame=tipsRect;
    }];

    //扫描框动画
    [self performSelector:@selector(startScanAnimation) withObject:nil afterDelay:1];
    
    //切换模式，重置计时时间
    self.totalScanTimeInterval = 0;
    
    //设置有效识别区域
    [self setValidateZone];
    
    //设置可识别扫码类型
    [self setSupportedScanType];
}

/**
 开启扫描动画
 */
- (void)startScanAnimation {
    [_scanRect stopScaning];
    [_scanRect startScaningRepeatCount:100 Duration:2 HeightFactor:0.3];
}

#pragma mark - 计时相关
/**
 计时，设置每隔TimerInterval秒截取取一次视频流数据进行画面捕获及软解码
 */
- (void)scheduledTimer {
    self.decodeTimer = [NSTimer scheduledTimerWithTimeInterval:TimerInterval target:self selector:@selector(timing) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.decodeTimer forMode:NSRunLoopCommonModes];
}

/**
 计时执行
 */
- (void)timing {
    self.totalScanTimeInterval+=TimerInterval;
    self.canCaptureImage = YES;
}

/**
 结束计时
 */
- (void)endTiming {
    if ([self.decodeTimer isValid]) {
        [self.decodeTimer invalidate];
        self.decodeTimer = nil;
    }
}


#pragma mark - 监听事件
/**
 设备旋转
 */
- (void)orientationChanged {
    //调整旋转预览图方向
    _preview.connection.videoOrientation = [self videoOrientationFromCurrentDeviceOrientation];
    //预览视图
    _preview.frame=self.view.layer.bounds;
    _flashBtn.frame=CGRectMake(screenW-flashBtnWH-marginSpace, flashToBar, flashBtnWH, flashBtnWH);
    //设置底部相关视图尺寸
    [self setFrameForBottomView];
    
    //扫码框、背景图
    if (self.scanType == 0) {
        [self setScanZoneW:defaultScanZoneQRW H:defaultScanZoneQRH];
    } else {
        [self setScanZoneW:defaultScanZoneBARW H:defaultScanZoneBARH];
    }
}

/**
 scene进入后台
 */
- (void)sceneDidEnterBackgroundNotification:(NSNotification *)notification {
    [_session stopRunning];
    [self endTiming];
}

/**
 scene回到前台
 */
- (void)sceneDidBecomeActiveNotification:(NSNotification *)notification {
    //重新设置识别区域，否则会导致奔溃
    [self setValidateZone];
    //开启会话
    [self startSession];
    //开启扫码计时器
    [self scheduledTimer];
    //开启扫描动画
    [self startScanAnimation];
}

#pragma mark - other
/**
 指定屏幕方向
 */
- (AVCaptureVideoOrientation)videoOrientationFromCurrentDeviceOrientation {
    NSArray *sceneArray = [[[UIApplication sharedApplication] connectedScenes] allObjects];
    UIWindowScene *windoScene = (UIWindowScene *)sceneArray[0];
    
    switch (windoScene.interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:{
            return AVCaptureVideoOrientationLandscapeLeft;
        }
        case UIInterfaceOrientationLandscapeRight:{
            return AVCaptureVideoOrientationLandscapeRight;
        }
        case UIInterfaceOrientationPortraitUpsideDown:{
            return AVCaptureVideoOrientationPortraitUpsideDown;
        }
        default: {
            return AVCaptureVideoOrientationPortrait;
        }
    }
}

#pragma mark - 硬件调节相关
/**
 设置闪光灯状态
 */
- (void)setTorchMode:(NSInteger)torchMode {
    if ([_device hasTorch]) {
        [_device lockForConfiguration:nil];
        [_device setTorchMode: torchMode];
        [_device unlockForConfiguration];
    }
}


#pragma mark - tool
//获取纯色图片
- (UIImage*)createImageWithColor:(UIColor*)color {
    CGRect rect = CGRectMake(0, 0, advertisingBtnWH, advertisingBtnWH);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

@end
