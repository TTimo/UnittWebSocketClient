//
//  WebSocketFragment.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/12/11.
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

#import "WebSocketFragment.h"


@interface WebSocketFragment()

@property (nonatomic,readonly) BOOL isDataValid;

- (int) generateMask;
- (NSData*) mask:(int) aMask data:(NSData*) aData;
- (NSData*) mask:(int) aMask data:(NSData*) aData range:(NSRange) aRange;
- (NSData*) unmask:(int) aMask data:(NSData*) aData;
- (NSData*) unmask:(int) aMask data:(NSData*) aData range:(NSRange) aRange;
- (void) parseData;
- (void) parseContentFrom:(int) aIndex length:(long long) aLength;
- (void) buildFragment;

@end


@implementation WebSocketFragment

@synthesize finished;
@synthesize mask;
@synthesize opCode;
@synthesize payloadData;
@synthesize payloadType;
@synthesize fragment;


#pragma mark Properties
- (BOOL) hasMask
{
    return self.mask != 0;
}

- (int) generateMask
{
    return arc4random();
}

- (BOOL) isControlFrame
{
    return self.opCode == PayloadOpCodeClose || self.opCode == PayloadOpCodePing || self.opCode == PayloadOpCodePong;
}

- (BOOL) isDataFrame
{
    return self.opCode == PayloadOpCodeContinuation || self.opCode == PayloadOpCodeText || self.opCode == PayloadOpCodeBinary;
}

- (BOOL) isValid
{
    return (self.isDataValid && self.isDataFrame) || self.isControlFrame;
}

- (BOOL) isDataValid
{
    return self.payloadData && [self.payloadData length];
}


#pragma mark Parsing
- (void) parseContentFrom:(int) aIndex length:(long long) aLength
{
    if ([self.fragment length] >= aIndex + aLength)
    {
        if (self.hasMask) 
        {
            self.payloadData = [self mask:self.mask data:self.fragment range:NSMakeRange(aIndex, aLength)];
        }
        else
        {
            self.payloadData = [self.fragment subdataWithRange:NSMakeRange(aIndex, aLength)];
        }
    }
}

- (void) parseData
{
    //get header data bits
    int bufferLength = 14;
    if ([self.fragment length] < bufferLength)
    {
        bufferLength = [self.fragment length];
    }
    char buffer[bufferLength];
    [self.fragment getBytes:&buffer length:bufferLength];
    
    //determine opcode
    if (bufferLength > 0) 
    {
        int index = 0;
        self.opCode = buffer[index++] & 0x0F;
        
        //handle data depending on opcode
        switch (self.opCode) 
        {
            case PayloadOpCodeText:
                self.payloadType = PayloadTypeText;
                break;
            case PayloadOpCodeBinary:
                self.payloadType = PayloadTypeBinary;
                break;
        }
        
        //handle content, if any
        if (self.isDataFrame)
        {        
            if (bufferLength > 1)
            {
                //do we have a mask
                BOOL hasMask = buffer[index] & 0x80;
                
                //get payload length
                long long dataLength = buffer[index++] & 0x7F;
                if (dataLength == 126)
                {
                    if (bufferLength > 3)
                    {
                        dataLength = buffer[index++] << 8 | buffer[index++];
                    }
                }
                else if (dataLength == 127)
                {
                    if (bufferLength > 8)
                    {
                        dataLength = buffer[index++] << 24 | buffer[index++] << 16 | buffer[index++] << 8 | buffer[index++];
                        dataLength = dataLength << 32 | buffer[index++] << 24 | buffer[index++] << 16 | buffer[index++] << 8 | buffer[index++];
                    }                    
                }
                
                //if applicable, set mask value
                if (hasMask)
                {                    
                    //grab mask
                    if (bufferLength > index + 3)
                    {
                        self.mask = buffer[index++] << 24 | buffer[index++] << 16 | buffer[index++] << 8 | buffer[index++];
                    }
                }
                
                //we have our data, parse the contents
                [self parseContentFrom:index length:dataLength];
            }
        } 
    }
}

- (void) buildFragment
{
    NSMutableData* temp = [NSMutableData data];
    
    //build fin & reserved
    char byte = self.finished ? 0x80 : 0x0;
    
    //build opmask
    byte |= self.opCode;
    
    //push first byte
    [temp appendBytes:&byte length:1];
    
    //use mask
    byte = 0x80;
    
    //payload length
    long long payloadLength = [self.payloadData length];
    if (payloadLength < 125)
    {
        byte |= (int) payloadLength;
    }
    else if (payloadLength <= INT16_MAX)
    {
        byte |= 126;
        [temp appendBytes:&byte length:1];
        byte = payloadLength & 0xFF00;
        [temp appendBytes:&byte length:1];
        byte = payloadLength & 0xFF;
        [temp appendBytes:&byte length:1];
    }
    else if (payloadLength <= INT64_MAX)
    {
        byte |= 127;
        [temp appendBytes:&byte length:1];
        [temp appendBytes:&payloadLength length:8];
    }
    
    //mask
    int32_t maskValue = self.mask;
    [temp appendBytes:&maskValue length:4];
    
    //payload data
    [temp appendData:self.payloadData];
    self.fragment = temp;
}

- (NSData*) mask:(int) aMask data:(NSData*) aData
{
    return [self mask:aMask data:aData range:NSMakeRange(0, [aData length])];
}

- (NSData*) mask:(int) aMask data:(NSData*) aData range:(NSRange) aRange
{
    NSMutableData* result = [NSMutableData data];
    char maskBytes[4];
    maskBytes[0] = (int)((aMask >> 24) & 0xFF) ;
    maskBytes[1] = (int)((aMask >> 16) & 0xFF) ;
    maskBytes[2] = (int)((aMask >> 8) & 0XFF);
    maskBytes[3] = (int)((aMask & 0XFF));
    char current;
    int index = aRange.location;
    int end = aRange.location + aRange.length;
    if (end > [aData length])
    {
        end = [aData length];
    }
    while (index < end) 
    {
        //set current byte
        [aData getBytes:&current range:NSMakeRange(index, 1)];
        
        //mask
        current = current ^ maskBytes[index % 4];
        
        //append result & continue
        index++;
        [result appendBytes:&current length:1];
    }
    return result;
}

- (NSData*) unmask:(int) aMask data:(NSData*) aData
{
    return [self unmask:aMask data:aData range:NSMakeRange(0, [aData length])];
}

- (NSData*) unmask:(int) aMask data:(NSData*) aData range:(NSRange) aRange
{
    return [self mask:aMask data:aData range:aRange];
}


#pragma mark Lifecycle
+ (id) fragmentWithOpCode:(PayloadOpCode) aOpCode payload:(NSData*) aPayload 
{
    id result = [[[self class] alloc] initWithOpCode:aOpCode payload:aPayload];
    
    return [result autorelease];
}

+ (id) fragmentWithData:(NSData*) aData
{
    id result = [[[self class] alloc] initWithData:aData];
    
    return [result autorelease];
}

- (id) initWithOpCode:(PayloadOpCode) aOpCode payload:(NSData*) aPayload
{
    self = [super init];
    if (self)
    {
        self.mask = [self generateMask];
        self.opCode = aOpCode;
        self.payloadData = aPayload;
        [self buildFragment];
    }
    return self;
}

- (id) initWithData:(NSData*) aData
{
    self = [super init];
    if (self)
    {
        self.opCode = PayloadOpCodeIllegal;
        self.fragment = aData;
        [self parseData];
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.opCode = PayloadOpCodeIllegal;
    }
    return self;
}

- (void) dealloc
{
    [payloadData release];
    [fragment release];
    
    [super dealloc];
}

@end
