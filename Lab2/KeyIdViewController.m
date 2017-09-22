//
//  KeyIdViewController.m
//  Lab2
//
//  Created by Mandar Phadate on 9/22/17.
//  Copyright © 2017 Mandar Phadate. All rights reserved.
//

#import "KeyIdViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"
#import "PeakFinder.h"

#define BUFFER_SIZE 16384*2
#define READ_SIZE 1024*8
#define DISPLAY_SIZE 8000

@interface KeyIdViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property(strong, nonatomic)PeakFinder *finder;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property float freq;
@property float mag;
@property float maxMag;
@property BOOL lock;
@end

@implementation KeyIdViewController
@synthesize freq;
@synthesize mag;
@synthesize lock;
@synthesize maxMag;

-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:1
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:DISPLAY_SIZE];
    }
    return _graphHelper;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(PeakFinder*)finder{
    if (!_finder) {
        float res = 44100.0/BUFFER_SIZE;
        _finder = [[PeakFinder alloc] initWithFrequencyResolution:res];
        NSLog(@"Freq Res : %f",res);
    }
    return _finder;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
     __block KeyIdViewController * __weak  weakSelf = self;
    [self.graphHelper setScreenBoundsBottomHalf];

    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    

    
}

- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:READ_SIZE];
    
    for (int i=READ_SIZE; i < BUFFER_SIZE; i++){
        arrayData[i] = 0.0;
    }
    
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    NSArray *peaks = [self.finder getFundamentalPeaksFromBuffer: fftMagnitude
                                                     withLength:BUFFER_SIZE/2
                                                usingWindowSize:10
                                        andPeakMagnitudeMinimum:-5
                                                 aboveFrequency:100] ;
    
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:DISPLAY_SIZE
                     forGraphIndex:0
                 withNormalization:64.0
                     withZeroValue:-60];
    
    
    Peak *p1 = [peaks objectAtIndex:0];
    
    self.keyLabel.text = [NSString stringWithFormat: @"Peak %f",p1.frequency];
    
    [self.graphHelper update]; // update the graph

    free(arrayData);
    free(fftMagnitude);
    
    
    
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:YES];
    [self.audioManager pause];
}

- (IBAction)toggle:(UIButton *)sender {
    if ([self.audioManager playing]){
         [self.audioManager pause];
    }else{
         [self.audioManager play];
    }
}



- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}


@end
