//
//  AppDelegate.h
//  Gifzo
//

#import <Cocoa/Cocoa.h>
#import "DrawMouseBoxView.h"
#import "Recorder.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, DrawMouseBoxViewDelegate, RecorderDelegate>
@property Recorder *recorder;
@end
