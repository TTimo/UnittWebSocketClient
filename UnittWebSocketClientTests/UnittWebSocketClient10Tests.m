//
//  UnittWebSocketClient10Tests.m
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

#import "UnittWebSocketClient10Tests.h"
#import "WebSocketFragment.h"


@implementation UnittWebSocketClient10Tests

@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate
- (void) didOpen
{
    NSLog(@"Did open");
    [self.ws sendText:@"Blue"];
}

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError
{
    NSLog(@"Status Code: %i", aStatusCode);
    NSLog(@"Close Message: %@", aMessage);
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
    ws = [[WebSocket10 webSocketWithURLString:@"ws://10.0.1.5:8080/testws/ws/test" delegate:self origin:nil protocols:[NSArray arrayWithObject:@"blue"] tlsSettings:nil verifyHandshake:YES] retain];
    ws.closeTimeout = 15.0;
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
    const unsigned char bytes[5] = {0x7f, 0x9f, 0x4d, 0x51, 0x58};
    NSData* sample = [NSData dataWithBytes:bytes length:5];
    NSData* unmaskedSample = [fragment unmask:fragment.mask data:sample];
    NSString* testText = [[[NSString alloc] initWithData:unmaskedSample encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(testText, @"Hello", @"Did not find the correct message.");
}

- (void) testRoundTrip
{
    [self.ws open];
    [self waitForSeconds:10.0];
    STAssertEqualObjects(self.response, @"Message: Blue", @"Did not find the correct phone.");
    [self.ws close:WebSocketCloseStatusMessageTooLarge message:@"woah"];
    [self waitForSeconds:10.0];
}

- (void) testUnmaskedText
{
    const unsigned char bytes[7] = {0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f};
    NSData* sample = [NSData dataWithBytes:bytes length:7];
    WebSocketFragment* fragment = [WebSocketFragment fragmentWithData:sample];
    STAssertTrue(fragment.isFinal, @"Did not set final bit.");
    STAssertEquals(fragment.payloadType, PayloadTypeText, @"Did not find the correct payloadtype.");
    STAssertFalse(fragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(fragment.payloadData, @"Did not build any payload data");
    NSString* message = [[[NSString alloc] initWithData:fragment.payloadData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(message, @"Hello", @"Did not find the correct message.");
}

- (void) testMaskedText
{
    const unsigned char bytes[11] = {0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58};
    NSData* sample = [NSData dataWithBytes:bytes length:11];
    WebSocketFragment* fragment = [WebSocketFragment fragmentWithData:sample];
    STAssertTrue(fragment.isFinal, @"Did not set final bit.");
    STAssertEquals(fragment.payloadType, PayloadTypeText, @"Did not find the correct payloadtype.");
    STAssertTrue(fragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(fragment.payloadData, @"Did not build any payload data");
    int correctMask = 0x37 << 24 | 0xfa << 16 | 0x21 << 8 | 0x3d;
    STAssertEquals(fragment.mask, correctMask, @"Did not find correct mask");
    NSString* message = [[[NSString alloc] initWithData:fragment.payloadData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(message, @"Hello", @"Did not find the correct message.");
    fragment = [WebSocketFragment fragmentWithOpCode:MessageOpCodeText isFinal:YES payload:[@"Hello" dataUsingEncoding:NSUTF8StringEncoding]];
    fragment.mask = correctMask;
    STAssertEquals(correctMask, fragment.mask, @"Did not apply correct mask");
    [fragment buildFragment];
    const unsigned char buffer[6];
    [fragment.fragment getBytes:&buffer length:6];
    for (int i = 0; i < 6; i++) 
    {
        STAssertEquals(bytes[i], buffer[i], @"Byte #%i is different. Should be '%x'. It was '%x'", i, bytes[i], buffer[i]);
    }
    NSData* messageData = [sample subdataWithRange:NSMakeRange(6, 5)];
    NSData* fragmentMessageData = [fragment.fragment subdataWithRange:NSMakeRange(6, 5)];
    STAssertEqualObjects(fragmentMessageData, messageData, @"Did not generate correct payload with mask.");
    STAssertEqualObjects(fragment.fragment, sample, @"Did not generate correct data.");
}

- (void) testFragmentedText
{
    const unsigned char firstBytes[5] = {0x01, 0x03, 0x48, 0x65, 0x6c};
    NSData* firstSample = [NSData dataWithBytes:firstBytes length:5];
    WebSocketFragment* firstFragment = [WebSocketFragment fragmentWithData:firstSample];
    STAssertFalse(firstFragment.isFinal, @"Did set final bit.");
    STAssertEquals(PayloadTypeText, firstFragment.payloadType, @"Did not find the correct payloadtype.");
    STAssertEquals(MessageOpCodeText, firstFragment.opCode, @"Did not set op code to text");
    STAssertFalse(firstFragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(firstFragment.payloadData, @"Did not build any payload data");
    const unsigned char secondBytes[4] = {0x80, 0x02, 0x6c, 0x6f};
    NSData* secondSample = [NSData dataWithBytes:secondBytes length:4];
    WebSocketFragment* secondFragment = [WebSocketFragment fragmentWithData:secondSample];
    STAssertTrue(secondFragment.isFinal, @"Did not set final bit.");
    STAssertEquals(MessageOpCodeContinuation, secondFragment.opCode, @"Did not set op code to continuation");
    STAssertFalse(secondFragment.hasMask, @"Did not find the correct has mask value.");
    STAssertNotNil(secondFragment.payloadData, @"Did not build any payload data");
    NSMutableData* messageData = [NSMutableData data];
    [messageData appendData:firstFragment.payloadData];
    [messageData appendData:secondFragment.payloadData];
    NSString* message = [[[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding] autorelease];
    STAssertEqualObjects(message, @"Hello", @"Did not find the correct message.");
}

- (void) testUnmaskedBinary
{
    const unsigned char bytes[4] = {0x82, 0x7E, 0x01, 0x00};
    NSData* sample = [NSData dataWithBytes:bytes length:4];
    WebSocketFragment* fragment = [WebSocketFragment fragmentWithData:sample];
    STAssertTrue(fragment.isFinal, @"Did not set final bit.");
    STAssertEquals(fragment.payloadType, PayloadTypeBinary, @"Did not find the correct payloadtype.");
    STAssertFalse(fragment.hasMask, @"Did not find the correct has mask value.");
}

- (void)dealloc {
    [response release];
    [ws release];
    [super dealloc];
}

@end
