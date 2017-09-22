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

#define BUFFER_SIZE 16384
#define READ_SIZE 1024*4
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
@property (nonatomic) float res;

@end

@implementation KeyIdViewController
@synthesize freq;
@synthesize mag;
@synthesize lock;
@synthesize res;
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
        self.res = (44100.0/BUFFER_SIZE);
        _finder = [[PeakFinder alloc] initWithFrequencyResolution:self.res];
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
    if (! (p1.frequency == 0.00)){
        self.keyLabel.text = [NSString stringWithFormat: @"Note %@",[self getNote:p1.frequency]];
    }else{
        self.keyLabel.text = @"No tone ! Increase volume!";
    }
  //  NSLog(@"%f",p1.frequency);
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

-(NSString*) getNote:(float)frequency{
    float res = self.res*2;
    
    if ( 110-res < frequency && frequency < 110+res){
        return @"A2";
    }else if ( 123-res < frequency && frequency < 123+res){
        return @"B2";
    }else if ( 131-res < frequency && frequency < 131+res){
        return @"C3";
    }else if ( 139-res < frequency && frequency < 139+res){
        return @"C#3";
    }else if ( 147-res < frequency && frequency < 147+res){
        return @"D3";
    }else if ( 156-res < frequency && frequency < 156+res){
        return @"D#3";
    }else if ( 165-res < frequency && frequency < 165+res){
        return @"E3";
    }else if ( 175-res < frequency && frequency < 175+res){
        return @"F3";
    }else if ( 185-res < frequency && frequency < 185+res){
        return @"F#3";
    }else if ( 196-res < frequency && frequency < 196+res){
        return @"G3";
    }else if ( 208-res < frequency && frequency < 208+res){
        return @"G#3";
    }else if ( 220-res < frequency && frequency < 220+res){
        return @"A3";
    }else if ( 233-res < frequency && frequency < 233+res){
        return @"A#3";
    }else if ( 247-res < frequency && frequency < 247+res){
        return @"B3";
    }
    
    else if ( 262-res < frequency && frequency < 262+res){
        return @"C4";
    }else if ( 277-res < frequency && frequency < 277+res){
        return @"C#4";
    }else if ( 294-res < frequency && frequency < 294+res){
        return @"D4";
    }else if ( 311-res < frequency && frequency < 311+res){
        return @"D#";
    }else if ( 330-res < frequency && frequency < 330+res){
        return @"E4";
    }else if ( 349-res < frequency && frequency < 349+res){
        return @"F4";
    }else if ( 370-res < frequency && frequency < 370+res){
        return @"F#4";
    }else if ( 392-res < frequency && frequency < 392+res){
        return @"G4";
    }else if ( 415-res < frequency && frequency < 415+res){
        return @"G#4";
    }else if ( 440-res < frequency  && frequency < 440+res){
        return @"A4";
    }else if ( 466-res < frequency && frequency < 466+res){
        return @"A#4";
    }else if ( 494-res < frequency && frequency < 494+res){
        return @"B4";
    }
    
    else if ( 523-res < frequency && frequency < 523+res){
        return @"C5";
    }else if ( 554-res < frequency && frequency < 554+res){
        return @"C#5";
    }else if ( 587-res < frequency && frequency < 587+res){
        return @"D5";
    }else if ( 622-res < frequency && frequency < 622+res){
        return @"D#5";
    }else if ( 659-res < frequency && frequency < 659+res){
        return @"E5";
    }else if ( 698-res < frequency && frequency < 698+res){
        return @"F5";
    }else if ( 740-res < frequency && frequency < 740+res){
        return @"F#5";
    }else if ( 784-res < frequency && frequency < 784+res){
        return @"G5";
    }else if ( 831-res < frequency && frequency < 831+res){
        return @"G#5";
    }else if ( 880-res < frequency && frequency < 880+res){
        return @"A5";
    }else if ( 932-res < frequency && frequency < 932+res){
        return @"A#5";
    }else if ( 988-res < frequency && frequency < 988+res){
        return @"B5";
    }
    
    else if ( 1047-res < frequency && frequency < 1047+res){
        return @"C6";
    }else if ( 1109-res < frequency && frequency < 1109+res){
        return @"C#6";
    }else if ( 1175-res < frequency && frequency < 1175+res){
        return @"D6";
    }else if ( 1245-res < frequency && frequency < 1245+res){
        return @"D#6";
    }else if ( 1319-res < frequency && frequency < 1319+res){
        return @"E6";
    }else if ( 1397-res < frequency && frequency < 1397+res){
        return @"F6";
    }else if ( 1480-res < frequency && frequency < 1480+res){
        return @"F#6";
    }else if ( 1568-res < frequency && frequency < 1568+res){
        return @"G6";
    }else if ( 1661-res < frequency && frequency < 1661+res){
        return @"G#6";
    }else if ( 1760-res < frequency && frequency < 1760+res){
        return @"A6";
    }else if ( 1865-res < frequency && frequency < 1865+res){
        return @"A#6";
    }else if ( 1976-res < frequency && frequency < 1976+res){
        return @"B6";
    }
    
    else if ( 2093-res < frequency && frequency < 2093+res){
        return @"C7";
    }else if ( 2217-res < frequency && frequency < 2217+res){
        return @"C#7";
    }else if ( 2349-res < frequency && frequency < 2349+res){
        return @"D7";
    }else if ( 2489-res < frequency && frequency < 2489+res){
        return @"D#7";
    }else if ( 2637-res < frequency  && frequency < 2637+res){
        return @"E7";
    }else if ( 2794-res < frequency && frequency < 2794+res){
        return @"F7";
    }else if ( 2960-res < frequency && frequency < 2960+res){
        return @"F#7";
    }else if ( 3136-res < frequency && frequency < 3136+res){
        return @"G7";
    }else if ( 3322-res < frequency && frequency < 3322+res){
        return @"G#7";
    }else if ( 3520-res < frequency && frequency < 3520+res){
        return @"A7";
    }else if ( 3729-res < frequency && frequency < 3729+res){
        return @"A#7";
    }else if ( 3951-res < frequency && frequency < 3951+res){
        return @"B7";
    }
    
    else if ( 4186-res < frequency && frequency < 4186+res){
        return @"C8";
    }else if ( 4435-res < frequency && frequency < 4435+res){
        return @"C#8";
    }else if ( 4699-res < frequency && frequency < 4699+res){
        return @"D8";
    }else if ( 4978-res < frequency && frequency < 4978+res){
        return @"D#8";
    }else if ( 5274-res < frequency && frequency < 5274+res){
        return @"E8";
    }else if ( 5588-res < frequency && frequency < 5588+res){
        return @"F8";
    }else if ( 5920-res < frequency && frequency < 5920+res){
        return @"F#8";
    }else if ( 6272-res < frequency && frequency < 6272+res){
        return @"G8";
    }else if ( 6645-res < frequency && frequency < 6645+res){
        return @"G#8";
    }else if ( 7040-res < frequency && frequency < 7040+res){
        return @"A8";
    }else if ( 7495-res < frequency && frequency < 7495+res){
        return @"A#8";
    }else if ( 7902-res < frequency && frequency < 7902+res){
        return @"B8";
    }else{
    return @"Out of tune";
    }
}


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}


@end
