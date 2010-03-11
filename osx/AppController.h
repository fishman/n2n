//
//  AppController.h
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "n2nThread.h"

@interface AppController : NSObject {
    N2NThread *n2nThread;
    NSConnection *serverConnection;
}

@end
