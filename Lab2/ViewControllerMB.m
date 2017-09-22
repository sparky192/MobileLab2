//
//  ViewControllerMB.m
//  Lab2
//
//  Created by Mandar Phadate on 9/19/17.
//  Copyright © 2017 Mandar Phadate. All rights reserved.
//

#import "ViewControllerMB.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"
#import "PeakFinder.h"

#define DISPLAY_SIZE 8000
#define BUFFER_SIZE 16384
#define READ_SIZE 1024*4


@interface ViewControllerMB ()
@property (weak, nonatomic) IBOutlet UIView *settingsView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *settingsHeightConstraint;
@property (weak, nonatomic) IBOutlet UILabel *FreqLabel;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *dopplerLabel;
@property (weak, nonatomic) IBOutlet UILabel *ampCutoffLabel;

@property (weak, nonatomic) IBOutlet UISlider *ampCutoffSlider;
@property (strong, nonatomic) Novocaine* audioManager;
@property (nonatomic) float phaseIncrement;
@property (nonatomic) float frequency;
@property (nonatomic) float res;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic)PeakFinder *finder;
@property (weak, nonatomic) IBOutlet UILabel *detectedFreq;
@property (nonatomic) float ampCutoff;
@property BOOL isShowing;


@end

@implementation ViewControllerMB
@synthesize ampCutoff;
@synthesize res;
@synthesize isShowing;

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
        
        _finder = [[PeakFinder alloc] initWithFrequencyResolution:res];
        NSLog(@"Freq Res : %f",self.res);
    }
    return _finder;
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:YES];
    self.res = 44100.0/BUFFER_SIZE;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.settingsView.subviews setValue:@YES forKeyPath:@"hidden"];
    isShowing = NO;
    self.ampCutoff = 0;
    // Do any additional setup after loading the view.
    [self updateFrequencyInKhz:15]; // mid C
    
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block ViewControllerMB * __weak  wSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [wSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];

    
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float* data, UInt32 numFrames, UInt32 numChannels){
        for(int i=0;i<numFrames;i++){
            for(int j=0;j<numChannels;j++){
                data[i*numChannels+j] = sin(phase);
            }
            phase += self.phaseIncrement;
            
            if(phase>2*M_PI){
                phase -= 2*M_PI;
            }
        }
        
        
    }];
    
    [self.audioManager play];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:YES];
    
    
    [self.audioManager setOutputBlock: nil];
    
    [self.audioManager pause];
}

//-(void) prepareLabel {
//    self.FreqLabel.textColor = [UIColor whiteColor];
//    self.dopplerLabel.textColor = [UIColor whiteColor];
//    self.detectedFreq.textColor = [UIColor whiteColor];
//    self.ampCutoffLabel.textColor = [UIColor whiteColor];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)sliderDidSlide:(UISlider *)sender {
    
    [self updateFrequencyInKhz:sender.value];
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
                                                usingWindowSize:10
                                        andPeakMagnitudeMinimum:self.ampCutoff
                                                 aboveFrequency:5000] ;
    Peak *p1 = [peaks objectAtIndex:0];
    
    [self dopplerEffect:p1.index*self.res];
    self.detectedFreq.text = [NSString stringWithFormat:@"Detected F: %f",p1.index*self.res];
    
    
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
    
    
}

-(void) dopplerEffect: (float) freq {
    //float newFreq = freq / 1000; //converts to KHz
    if (freq == 0.0){
        self.dopplerLabel.text = [NSString stringWithFormat:@"Peak not found try lowering detection amplitude!"];
    } else if (freq > self.frequency + self.res) {
        self.dopplerLabel.text = [NSString stringWithFormat:@"Doppler Effect: Gesture Towards"];
    } else if (freq < self.frequency - self.res)  {
        self.dopplerLabel.text = [NSString stringWithFormat:@"Doppler Effect: Gesture Away"];
    }else if ( self.frequency - self.res < freq < self.frequency + self.res)  {
        self.dopplerLabel.text = [NSString stringWithFormat:@"Doppler Effect: No Gesture Detected"];
    }
   // NSLog(@"self.freq= %f   freq= %f",self.frequency,freq);
}

-(void)updateFrequencyInKhz:(float) freqInKHz {
    self.frequency = freqInKHz*1000.0;
    self.FreqLabel.text = [NSString stringWithFormat:@"%.4f kHz",freqInKHz];
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}
- (IBAction)changedAmpCutoff:(UISlider *)sender {
    self.ampCutoff = self.ampCutoffSlider.value;
    self.ampCutoffLabel.text = [NSString stringWithFormat:@"Cutoff Amp: %f",self.ampCutoff];
 }

-(void)viewSlideDown {
    [UIView animateWithDuration:0.3
                          delay: 0.0
                        options: UIViewAnimationOptionCurveLinear
                     animations:^{
                         [UIView setAnimationRepeatCount:0];
                         [UIView setAnimationRepeatAutoreverses:NO];
                         self.settingsHeightConstraint.constant = 225;
                         self.settingsView.frame= CGRectMake(50,250,72,72);
                     }
                     completion: ^(BOOL finished) {
                         [self.settingsView.subviews setValue:@NO forKeyPath:@"hidden"];
                     }];
}

-(void)viewSlideUp {
    [UIView animateWithDuration:0.3
                          delay: 0.0
                        options: UIViewAnimationOptionCurveLinear
                     animations:^{
                         [UIView setAnimationRepeatCount:0];
                         [UIView setAnimationRepeatAutoreverses:NO];
                         self.settingsHeightConstraint.constant = 0;
                         self.settingsView.frame= CGRectMake(0,100,0,0);
                     }
                     completion: ^(BOOL finished) {
                         
                     }];
}

- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (!isShowing) {
        [self viewSlideDown];
        isShowing = YES;
        
    } else {
        [self.settingsView.subviews setValue:@YES forKeyPath:@"hidden"];
        [self viewSlideUp];
        isShowing = NO;
    }
}

@end
