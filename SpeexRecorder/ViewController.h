//
//  ViewController.h
//  SpeexRecorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "SpeexPlayer.h"
#include "SpeexRecorder.h"



@interface ViewController : UIViewController 
    
@property (weak, nonatomic) IBOutlet UIProgressView *PVplay;
@property (weak, nonatomic) IBOutlet UIButton *Record;
@property (weak, nonatomic) IBOutlet UIButton *Play;
@property (weak, nonatomic) IBOutlet UITextField *txtQ;
@property (weak, nonatomic) IBOutlet UISlider *sQ;
@property (weak, nonatomic) IBOutlet UISegmentedControl *SCMode;
@property (weak, nonatomic) IBOutlet UITextField *TFFileLen;
@property (weak, nonatomic) IBOutlet UITextField *TFTimeLen;



@property (readonly) SpeexPlayer *player;
@property (readonly) SpeexRecorder *recorder;


- (IBAction)RecordTouchDown:(UIButton *)sender;
- (IBAction)SliderChanged:(UISlider *)sender;

- (IBAction)PlayDown:(UIButton *)sender;
- (IBAction)StopPlayDown:(UIButton *)sender;

@end
