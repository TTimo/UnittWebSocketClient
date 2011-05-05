//
//  UnittWebSocketClientTests.m
//  UnittWebSocketClientTests
//
//  Created by Josh Morris on 5/2/11.
//  Copyright 2011 UnitT Software. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License. You may obtain a copy of
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "UnittWebSocketClientTests.h"
#import "WebSocket.h"
#import "MyWebSocketDelegate.h"


@implementation UnittWebSocketClientTests

@synthesize ws;

- (void)setUp
{
    [super setUp];
    
    MyWebSocketDelegate* delegate = [[[MyWebSocketDelegate alloc] initWithTest:self] autorelease];
    //we are not going to verifyAccept since Jetty is using prior web socket implementation
    ws = [WebSocket webSocketWithURLString:@"ws://10.0.1.5:8080/testws/ws/test" delegate:delegate origin:nil protocols:nil tlsSettings:nil verifyAccept:false];
}

- (void)tearDown
{    
    [ws release];
    [super tearDown];
}

- (void) waitForSeconds: (NSTimeInterval) aSeconds
{
    NSDate *secondsFromNow = [NSDate dateWithTimeIntervalSinceNow:aSeconds];
    [[NSRunLoop currentRunLoop] runUntilDate:secondsFromNow];
}

- (void) testExample
{
    [self.ws open];
    [self waitForSeconds:360.0];
    STAssertEqualObjects(((MyWebSocketDelegate*) ws.delegate).response, @"Message: Blue", @"Did not find the correct phone.");
}

@end
