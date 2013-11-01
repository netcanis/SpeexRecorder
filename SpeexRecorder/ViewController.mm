//
//  ViewController.m
//  SpeexRecorder
//
//  Created by ChenXJ on 13-10-23.
//  Copyright (c) 2013年 Yuantel.com. All rights reserved.
//

#import "ViewController.h"


//@interface ViewController ()

//@end

@implementation ViewController

@synthesize player;
@synthesize recorder;

@synthesize PVplay;
@synthesize Record;
@synthesize Play;
@synthesize txtQ;
@synthesize sQ;
@synthesize SCMode;
@synthesize TFFileLen;
@synthesize TFTimeLen;


- (void)dealloc
{
    delete player;
    delete recorder;
 //  [super dealloc];
    NSLog(@"dealloc");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    
    player = new SpeexPlayer();
    recorder = new SpeexRecorder();
    
    self.sQ.value = 0.1;
    int q =(int)(  self.sQ.value *10.0);
    NSString *newText = [[NSString alloc] initWithFormat:@"%d",q];
    self.txtQ.text = newText;
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackQueueStopped:) name:@"playbackQueueStopped" object:nil];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)RecordTouchDown:(UIButton *)sender {
                                                                                                                
    if(recorder->isRecording())
    {
        recorder->stop();
        self.Play.enabled = YES;
        [sender setTitle:@"录音" forState:UIControlStateNormal];
        double len = recorder->getRecordTime()/1000.0;
        self.TFTimeLen.text = [[NSString alloc] initWithFormat:@"%.3f秒",len];
        self.TFFileLen.text = [[NSString alloc] initWithFormat:@"%ld",recorder->getFileLength()];

    }
    else
    {
//        NSString *fileName = [NSTemporaryDirectory() stringByAppendingPathComponent: @"record.spx"];
        NSString *fileName = [self pathForFileInDocumentWithFileName:@"record.spx"];
        int compression =(int)(self.sQ.value  *10.0);
        int modeID = self.SCMode.selectedSegmentIndex;
     //   printf("modeid=%d\n",self.SCMode.selectedSegmentIndex);
        if(recorder->record([fileName UTF8String],compression,modeID))
        {
            
            self.Play.enabled = NO;
            [sender setTitle:@"停止" forState:UIControlStateNormal];
        }
        else
        {
            printf("录音失败！\n");
        }
        self.TFTimeLen.text = @"";
    }
}

- (IBAction)SliderChanged:(UISlider *)sender {
    
   int q =(int)(  sender.value *10.0);
    NSString *newText = [[NSString alloc] initWithFormat:@"%d",q];
    self.txtQ.text = newText;
    

}
- (void)playbackQueueStopped:(NSNotification *)note
{
    
	[self.Play setTitle:@"放音" forState: UIControlStateNormal];
    
	self.Record.enabled = YES;
}

- (IBAction)PlayDown:(UIButton *)sender {
   
    
    if(player->IsRunning())
    {
        
        
        player->stop();
        self.Record.enabled = YES;
        [self.Play setTitle:@"放音" forState: UIControlStateNormal];
        
    }
    else
    {
//        NSString *fileName = [NSTemporaryDirectory() stringByAppendingPathComponent: @"record.spx"];
        NSString *fileName = [self pathForFileInDocumentWithFileName:@"record.spx"];
    
        if(player->play([fileName UTF8String]))
        {
            
            self.Record.enabled = NO;
            [self.Play setTitle:@"停止" forState:UIControlStateNormal];
    
        }
    }
}

- (NSString *)pathForFileInDocumentWithFileName:(NSString *)fileName
{
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [pathArray objectAtIndex:0];
    return [docPath stringByAppendingPathComponent:fileName];
}


@end
