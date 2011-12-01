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

#import "UnittWebSocketClient00Tests.h"

@implementation UnittWebSocketClient00Tests

@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate
- (void) didOpen
{
    NSLog(@"Did open");
    [self.ws send:@"Blue"];
}

- (void) didClose: (NSError*) aError
{
    NSLog(@"Error: %@", [aError localizedDescription]);
}

- (void) didReceiveError: (NSError*) aError
{
    NSLog(@"Error: %@", [aError localizedDescription]);
}

- (void) didReceiveMessage: (NSString*) aMessage
{
    NSLog(@"Did receive message:%@", aMessage);
    if (aMessage)
    {
        response = [aMessage copy];
    }
}

#pragma mark Test
- (void)setUp
{
    [super setUp];
    
    ws = [[WebSocket00 webSocketWithURLString:@"ws://echo.websocket.org/" delegate:self origin:@"http://www.websocket.org" protocols:nil tlsSettings:nil verifyHandshake:YES] retain];
}

- (void)tearDown
{    
    [ws release];
    [response release];
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
    [self waitForSeconds:10.0];
    STAssertEqualObjects(self.response, @"Blue", @"Did not find the correct message value.");
}

- (void)dealloc {
    [response release];
    [super dealloc];
}

@end
