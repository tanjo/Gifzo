//
//  DrawMouseBoxView.h
//  Gifzo
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@class DrawMouseBoxView;

@protocol DrawMouseBoxViewDelegate <NSObject>
- (void)startRecordingKeyDidPressedInView:(DrawMouseBoxView *)view withRect:(NSRect)rect screen:(NSScreen *)screen;
@end

@interface DrawMouseBoxView : NSView
@property(weak) id <DrawMouseBoxViewDelegate> delegate;
@property NSScreen *screen;
@property NSButton *button;
@end
