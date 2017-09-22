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

#define DISPLAY_SIZE 8000
#define BUFFER_SIZE 16384
#define READ_SIZE 1024*4


@interface ViewControllerMA ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (weak, nonatomic) IBOutlet UILabel *FreqLabel;
@property (weak, nonatomic) IBOutlet UILabel *Freq2;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (weak, nonatomic) IBOutlet UISlider *ampSlider;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property(strong, nonatomic)PeakFinder *finder;
@property float freq;
@property float mag;
@property float maxMag;
@property BOOL lock;
@end



@implementation ViewControllerMA
@synthesize freq;
@synthesize mag;
@synthesize lock;
@synthesize maxMag;


#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:2
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:DISPLAY_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}


-(PeakFinder*)finder{
    if (!_finder) {
        float res = 44100.0/BUFFER_SIZE;
        _finder = [[PeakFinder alloc] initWithFrequencyResolution:res];
        NSLog(@"Freq Res : %f",res);
    }
    return _finder;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    CGFloat angel = -(M_PI/2);
    self.ampSlider.transform = CGAffineTransformMakeRotation(angel);
    lock = NO;
    
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
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
//    float* arrayDataPadded = malloc(sizeof(float)*PADDED_SIZE);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:READ_SIZE];
    
    for (int i=READ_SIZE; i < BUFFER_SIZE; i++){
//        if (i < BUFFER_SIZE)
//            arrayDataPadded[i]  = arrayData[i];
//        else{
            arrayData[i] = 0.0;
//        }
    }
    
    
    //send off for graphing
    [self.graphHelper setGraphData:arrayData
                    withDataLength:DISPLAY_SIZE
                     forGraphIndex:0];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // graph the FFT Data
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:DISPLAY_SIZE
                     forGraphIndex:1
                 withNormalization:64.0
                     withZeroValue:-60];
    
    
    
    
    NSArray *peaks = [self.finder getFundamentalPeaksFromBuffer: fftMagnitude
                                                     withLength:BUFFER_SIZE/2
                                                usingWindowSize:20
                                        andPeakMagnitudeMinimum:mag
                                                 aboveFrequency:150] ;
    Peak *p1 = [peaks objectAtIndex:0];
    
    
    //float freq = [[peaks objectAtIndex:0] ge];
  //  float x = p1.frequency*0.90909;
    
    if(!lock){
       self.FreqLabel.text = [NSString stringWithFormat:@"F1: %f" , p1.frequency];

        if([peaks count] >1){
            Peak *p2 = [peaks objectAtIndex:1];
            self.Freq2.text = [NSString stringWithFormat:@"F2: %f", p2.frequency];
        }else{
            self.Freq2.text = [NSString stringWithFormat:@"F2: 0.000000" ];
        }
    }else{
        
        if( p1.magnitude > mag){
            self.FreqLabel.text = [NSString stringWithFormat:@"F1: %f" , p1.frequency];
            if([peaks count] >1){
                Peak *p2 = [peaks objectAtIndex:1];
                self.Freq2.text = [NSString stringWithFormat:@"F2: %f", p2.frequency];
            }else{
                self.Freq2.text = [NSString stringWithFormat:@"F2: 0.000000" ];
            }
        }
        
    }
    
    
    
    
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
    //free(arrayDataPadded);
    
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}

- (IBAction)setAmpThrashold:(UISlider *)sender {
    mag = self.ampSlider.value;
    NSLog(@"Amp Threshold Set to : %f", mag);
}
- (IBAction)toggleFreqLock:(UIButton *)sender {
    if(lock){
        lock = NO;
    }
    else{
        lock = YES;
        mag = 0;
    }
    NSLog(@"Toggle : %d",lock);
}

@end
