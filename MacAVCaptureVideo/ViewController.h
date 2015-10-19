//
//  ViewController.h
//  MacAVCaptureVideo
//
//  Created by wzw on 10/19/15.
//  Copyright (c) 2015 zhewei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacVideoCapEngine.h"

@interface ViewController : NSViewController
{
    CMacAVVideoCapEngine *m_pVideoCapEngine;
}

@property (assign) IBOutlet NSTextField *tfFPS;

@property (assign) IBOutlet NSTextField *tfDumpFile;
@property (assign) IBOutlet NSImageView *viewPreview;

- (IBAction)startCapture:(id)sender;
- (IBAction)stopCapture:(id)sender;

@end

