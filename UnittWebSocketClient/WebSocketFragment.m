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

@end


@implementation WebSocketFragment

@synthesize isFinal;
@synthesize mask;
@synthesize opCode;
@synthesize payloadData;
@synthesize payloadType;
@synthesize fragment;
@synthesize messageLength;


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
    return self.opCode == MessageOpCodeClose || self.opCode == MessageOpCodePing || self.opCode == MessageOpCodePong;
}

- (BOOL) isDataFrame
{
    return self.opCode == MessageOpCodeContinuation || self.opCode == MessageOpCodeText || self.opCode == MessageOpCodeBinary;
}

- (BOOL) isValid
{
    return (self.isDataValid && self.isDataFrame) || self.isControlFrame;
}

- (BOOL) isDataValid
{
    return self.payloadData && [self.payloadData length];
}

- (NSUInteger) messageLength
{
    if (fragment && payloadStart) 
    {
        return payloadStart + payloadLength;
    }
    
    return 0;
}


#pragma mark Parsing
+ (PayloadLength) getPayloadLengthFromHeader:(NSData*) aHeader
{    
    if ([aHeader length] > 1)
    {
        char byte;
        [aHeader getBytes:&byte range:NSMakeRange(1, 1)];
        if (byte <= 125)
        {   
            return PayloadLengthMinimum;
        }
        if (byte == 126)
        {
            return PayloadLengthShort;
        }
        else if (byte == 127)
        {
            return PayloadLengthLong;                  
        }
    }
    
    return PayloadLengthIllegal;
}

+ (BOOL) getIsMaskedFromHeader:(NSData*) aHeader
{
    if ([aHeader length] > 1)
    {
        char byte;
        [aHeader getBytes:&byte range:NSMakeRange(1, 1)];
        return byte & 0x80;
    }
    
    return NO;
}

+ (MessageOpCode) getOpCodeFromHeader:(NSData*) aHeader
{
    if ([aHeader length] > 0)
    {
        char byte;
        [aHeader getBytes:&byte length:1];
        return byte & 0x0F;
    }
    
    return MessageOpCodeIllegal;
}

+ (int) getHeaderLengthFromHeader:(NSData*) aHeader
{
    BOOL hdrIsMasked = [self getIsMaskedFromHeader:aHeader];
    PayloadLength hdrPayloadLength = [self getPayloadLengthFromHeader:aHeader];
    
    int size = 2;
    
    //get payload length options
    switch (hdrPayloadLength) 
    {
        case PayloadLengthShort:
            size += 2;
            break;
        case PayloadLengthLong:
            size += 6;
            break;
    }
    
    //get mask option
    if (hdrIsMasked)
    {
        size += 4;
    }
    
    return size;
}

- (void) parseContent
{
    if ([self.fragment length] >= payloadStart + payloadLength)
    {
        if (self.hasMask) 
        {
            self.payloadData = [self mask:self.mask data:self.fragment range:NSMakeRange(payloadStart, payloadLength)];
        }
        else
        {
            self.payloadData = [self.fragment subdataWithRange:NSMakeRange(payloadStart, payloadLength)];
        }
    }
}

- (void) parseHeader
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
            case MessageOpCodeText:
                self.payloadType = PayloadTypeText;
                break;
            case MessageOpCodeBinary:
                self.payloadType = PayloadTypeBinary;
                break;
        }
        
        //handle content, if any     
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
            
            payloadStart = index;
            payloadLength = dataLength;
        }
    }
}

- (void) buildFragment
{
    NSMutableData* temp = [NSMutableData data];
    
    //build fin & reserved
    char byte = self.isFinal ? 0x80 : 0x0;
    
    //build opmask
    byte |= self.opCode;
    
    //push first byte
    [temp appendBytes:&byte length:1];
    
    //use mask
    byte = 0x80;
    
    //payload length
    long long fullPayloadLength = [self.payloadData length];
    if (fullPayloadLength <= 125)
    {
        byte |= (int) fullPayloadLength;
    }
    else if (fullPayloadLength <= INT16_MAX)
    {
        byte |= 126;
        [temp appendBytes:&byte length:1];
        short shortLength = fullPayloadLength & 0xFFFF;
        [temp appendBytes:&shortLength length:2];
    }
    else if (fullPayloadLength <= INT64_MAX)
    {
        byte |= 127;
        [temp appendBytes:&byte length:1];
        [temp appendBytes:&fullPayloadLength length:8];
    }
    
    //mask
    int32_t maskValue = self.mask;
    [temp appendBytes:&maskValue length:4];
    
    //payload data
    payloadStart = [temp length];
    payloadLength = fullPayloadLength;
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
+ (id) fragmentWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload 
{
    id result = [[[self class] alloc] initWithOpCode:aOpCode isFinal:aIsFinal payload:aPayload];
    
    return [result autorelease];
}

+ (id) fragmentWithData:(NSData*) aData
{
    id result = [[[self class] alloc] initWithData:aData];
    
    return [result autorelease];
}

- (id) initWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload
{
    self = [super init];
    if (self)
    {
        self.mask = [self generateMask];
        self.opCode = aOpCode;
        if (self.opCode == MessageOpCodeContinuation)
        {
            self.isFinal = NO;
        }
        else
        {
            self.isFinal = YES;
        }
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
        self.opCode = MessageOpCodeIllegal;
        self.fragment = aData;
        [self parseHeader];
        if (messageLength <= [aData length])
        {
            [self parseContent];
        }
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.opCode = MessageOpCodeIllegal;
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
