//
//  UnittWebSocketClient07Tests.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/19/11.
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

#import "UnittWebSocketClient07Tests.h"
#import "WebSocketFragment.h"


@implementation UnittWebSocketClient07Tests

@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate
- (void) didOpen
{
    NSLog(@"Did open");
    [self.ws sendText:@"Blue"];
}

- (void) didClose: (NSError*) aError
{
    NSLog(@"Error: %@", [aError localizedDescription]);
}

- (void) didReceiveError: (NSError*) aError
{
    NSLog(@"Error: %@", [aError localizedDescription]);
}

- (void) didReceiveTextMessage: (NSString*) aMessage
{
    NSLog(@"Did receive message:%@", aMessage);
    if (aMessage)
    {
        response = [aMessage copy];
    }
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage
{
    NSLog(@"Did receive binary message:%@", aMessage);
}

#pragma mark Test
- (void)setUp
{
    [super setUp];
    ws = [[WebSocket webSocketWithURLString:@"ws://10.0.1.5:8080/testws/ws/test" delegate:self origin:nil protocols:[NSArray arrayWithObject:@"chat"] tlsSettings:nil verifyHandshake:YES] retain];
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

- (void) testMasking
{
    //test two way
    WebSocketFragment* fragment = [[WebSocketFragment alloc] init];
    fragment.mask = [fragment generateMask];
    NSString* text = @"Hello";
    NSData* masked = [fragment mask:fragment.mask data:[text dataUsingEncoding:NSUTF8StringEncoding]];
    NSData* unmasked = [fragment unmask:fragment.mask data:masked];
    NSString* finalText = [[[NSString alloc] initWithData:unmasked encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(text, finalText, @"Masking is not two-way");
    
    //test spec
    fragment.mask = 0x37 << 24 | 0xfa << 16 | 0x21 << 8 | 0x3d;
    const char bytes[5] = {0x7f, 0x9f, 0x4d, 0x51, 0x58};
    NSData* sample = [NSData dataWithBytes:bytes length:5];
    NSData* unmaskedSample = [fragment unmask:fragment.mask data:sample];
    NSString* testText = [[[NSString alloc] initWithData:unmaskedSample encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(testText, @"Hello", @"Did not find the correct message.");
}

- (void) notestRoundTrip
{
    [self.ws open];
    [self waitForSeconds:120.0];
    STAssertEqualObjects(self.response, @"Message: Blue", @"Did not find the correct phone.");
}

- (void) notestUnmaskedText
{
    const char bytes[7] = {0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f};
    NSData* sample = [NSData dataWithBytes:bytes length:7];
    WebSocketFragment* fragment = [WebSocketFragment fragmentWithData:sample];
    STAssertEquals(fragment.payloadType, PayloadTypeText, @"Did not find the correct payloadtype.");
    STAssertFalse(fragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(fragment.payloadData, @"Did not build any payload data");
    NSString* message = [[[NSString alloc] initWithData:fragment.payloadData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(message, @"Hello", @"Did not find the correct message.");
}

- (void) notestMaskedText
{
    const char bytes[11] = {0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58};
    NSData* sample = [NSData dataWithBytes:bytes length:11];
    WebSocketFragment* fragment = [WebSocketFragment fragmentWithData:sample];
    STAssertEquals(fragment.payloadType, PayloadTypeText, @"Did not find the correct payloadtype.");
    STAssertTrue(fragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(fragment.payloadData, @"Did not build any payload data");
    
    WebSocketFragment* fragment2 = [WebSocketFragment fragmentWithOpCode:MessageOpCodeText isFinal:YES payload:[[NSString stringWithString:@"Hello"] dataUsingEncoding:NSUTF8StringEncoding]];
    NSData* sample2 = [NSData dataWithData:fragment2.fragment];
    WebSocketFragment* fragment3 = [WebSocketFragment fragmentWithData:fragment2.fragment];
    NSString* test = [[[NSString alloc] initWithData:fragment3.payloadData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(sample, sample2, "@Did not build the correct fragment");
    NSString* message = [[[NSString alloc] initWithData:fragment.payloadData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(message, @"Hello", @"Did not find the correct message.");
}

- (void) testFragmentedText
{
    
}

- (void) testUnmaskedBinary
{
    
}

- (void) testMaskedBinary
{
    
}

@end
