//
//  ViewController.m
//  RSScan
//
//  Created by Ron on 2021/12/28.
//  Copyright © 2021 Ron. All rights reserved.
//
//  MainPage: https://github.com/Ron-Samkulami/RSScan
//

#import "ViewController.h"
#import "RSScanView.h"

@interface ViewController ()
@property (nonatomic,strong) UILabel *resultLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpInterFace];
}


- (void)setUpInterFace {
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake((self.view.frame.size.width-100)/4, 100, 100, 30)];
    [btn setTitle:@"扫描二维码" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor redColor]];
    [btn setTag:1];
    [btn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    UIButton *odBtn = [[UIButton alloc] initWithFrame:CGRectMake((self.view.frame.size.width)/2, 100, 100, 30)];
    [odBtn setTitle:@"扫描条形码" forState:UIControlStateNormal];
    [odBtn setBackgroundColor:[UIColor redColor]];
    [odBtn setTag:2];
    [odBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:odBtn];
    
    _resultLabel = [[UILabel alloc] init];
    _resultLabel.frame = CGRectMake((self.view.frame.size.width-200)/2, 140, 200, 30);
    _resultLabel.textAlignment = NSTextAlignmentCenter;
    _resultLabel.text = @"扫描结果：";
    _resultLabel.textColor = [UIColor redColor];
    [self.view addSubview:_resultLabel];
}

- (void)btnClick:(UIButton *)sender {
    RSScanView *scanView=[[RSScanView alloc] init];
    switch (sender.tag) {
        case 1://扫描二维码
        {
            scanView.scanType = 0;
            scanView.isShowAdvertising = YES;
            scanView.resultBlock = ^(NSString *result) {
                self.resultLabel.text = result;
            };
            [scanView StartScan];
            scanView.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:scanView animated:YES completion:nil];
        }
            break;
            
        case 2://扫描条形码
        {
            scanView.scanType = 1;
            scanView.resultBlock = ^(NSString *result) {
                self.resultLabel.text = result;
            };
            [scanView StartScan];
            scanView.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:scanView animated:YES completion:nil];
        }
            break;
            
        default:
            break;
    }
}

@end
