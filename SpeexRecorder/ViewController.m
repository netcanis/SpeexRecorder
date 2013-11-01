//
//  ViewController.m
//  SpeexRecorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize player;
@synthesize recorder;

- (void)awakeFromNib
{
    player = new SpeexPlayer();
    recorder = new SpeexRecorder();
    
}
- (void)dealloc
{
    delete player;
    delete recorder;
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)StopRecoderDown:(UIButton *)sender {
   
    self.Record.enabled = YES;
    sender.enabled = NO;
    self.Play.enabled = YES;
    self.StopPlay.enabled = NO;
}

- (IBAction)RecordTouchDown:(UIButton *)sender {
    self.StopRecord.enabled = YES;
    sender.enabled = NO;
    self.Play.enabled = NO;
    self.StopPlay.enabled = NO;
}

- (IBAction)SliderChanged:(UISlider *)sender {
    
   int q =(int)(  sender.value *10.0);
    NSString *newText = [[NSString alloc] initWithFormat:@"%d",q];
    self.txtQ.text = newText;
    

}

- (IBAction)PlayDown:(UIButton *)sender {
    self.Record.enabled = NO;
    self.StopRecord.enabled = NO;
    sender.enabled = NO;
    
    self.StopPlay.enabled = YES;
}

- (IBAction)StopPlayDown:(UIButton *)sender {
    self.Record.enabled = YES;
//    self.StopRecord.enabled = NO;
    sender.enabled = NO;
    
    self.StopPlay.enabled = YES;
}
@end
