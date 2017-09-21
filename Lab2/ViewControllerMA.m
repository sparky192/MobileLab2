//
//  ViewController.m
//  Lab2
//
//  Created by Mandar Phadate on 9/19/17.
//  Copyright © 2017 Mandar Phadate. All rights reserved.
//

#import "ViewControllerMA.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"
#import "PeakFinder.h"

#define DISPLAY_SIZE 2048
#define BUFFER_SIZE 2048*2
#define PADDED_SIZE 14700*2

@interface ViewControllerMA ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (weak, nonatomic) IBOutlet UILabel *FreqLabel;
@property (weak, nonatomic) IBOutlet UILabel *Freq2;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property(strong, nonatomic)PeakFinder *finder;
@property float freq;
@end



@implementation ViewControllerMA
@synthesize freq;

#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:PADDED_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:2
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:PADDED_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:PADDED_SIZE];
    }
    
    return _fftHelper;
}


-(PeakFinder*)finder{
    if (!_finder) {
        _finder = [[PeakFinder alloc] initWithFrequencyResolution:3.0];
    }
    return _finder;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block ViewControllerMA * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*PADDED_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*PADDED_SIZE/2);
    float* arrayDataPadded = malloc(sizeof(float)*PADDED_SIZE);
    
    [self.buffer fetchFreshData:arrayDataPadded withNumSamples:PADDED_SIZE];
    
//    for (int i=0; i < PADDED_SIZE; i++){
//        if (i < BUFFER_SIZE)
//            arrayDataPadded[i]  = arrayData[i];
//        else{
//            arrayDataPadded[i] = 0.00001;
//        }
//    }
    
    
    //send off for graphing
    [self.graphHelper setGraphData:arrayDataPadded
                    withDataLength:DISPLAY_SIZE
                     forGraphIndex:0];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayDataPadded
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // graph the FFT Data
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:DISPLAY_SIZE/2
                     forGraphIndex:1
                 withNormalization:64.0
                     withZeroValue:-60];
    
    
    
    
    NSArray *peaks = [self.finder getFundamentalPeaksFromBuffer: fftMagnitude withLength:PADDED_SIZE/2 usingWindowSize:10 andPeakMagnitudeMinimum:-10 aboveFrequency:500] ;
    Peak *p1 = [peaks objectAtIndex:0];
    
    
    //float freq = [[peaks objectAtIndex:0] ge];
   self.FreqLabel.text = [NSString stringWithFormat:@"F1: %f", p1.frequency];
    NSLog(@" Freq : %@",[peaks objectAtIndex:1]);
    if(![peaks objectAtIndex:1]){
        Peak *p2 = [peaks objectAtIndex:1];
        self.Freq2.text = [NSString stringWithFormat:@"F2: %f", p2.frequency];
        
    }
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
    free(arrayDataPadded);
    
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}


@end
