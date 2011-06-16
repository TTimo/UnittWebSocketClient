//
//  WebSocketFragment.h
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

#import <Foundation/Foundation.h>


enum 
{
    PayloadOpCodeIllegal = -1,
    PayloadOpCodeContinuation = 0,
    PayloadOpCodeText = 1,
    PayloadOpCodeBinary = 2,
    PayloadOpCodeClose = 8,
    PayloadOpCodePing = 9,
    PayloadOpCodePong = 10
};
typedef NSInteger PayloadOpCode;

enum 
{
    PayloadTypeUnknown = 0,
    PayloadTypeText = 1,
    PayloadTypeBinary = 2
};
typedef NSInteger PayloadType;


@interface WebSocketFragment : NSObject 
{
    BOOL finished;
    int mask;
    PayloadType payloadType;
    NSData* payloadData;
    PayloadOpCode opCode;
    NSData* fragment;
}

@property (nonatomic,assign) BOOL finished;
@property (nonatomic,readonly) BOOL hasMask;
@property (nonatomic,readonly) BOOL isControlFrame;
@property (nonatomic,readonly) BOOL isDataFrame;
@property (nonatomic,readonly) BOOL isValid;
@property (nonatomic,assign) int mask;
@property (nonatomic,assign) PayloadOpCode opCode;
@property (nonatomic,retain) NSData* payloadData;
@property (nonatomic,assign) PayloadType payloadType;
@property (nonatomic,retain) NSData* fragment;

+ (id) fragmentWithOpCode:(PayloadOpCode) aOpCode payload:(NSData*) aPayload;
+ (id) fragmentWithData:(NSData*) aData;
- (id) initWithOpCode:(PayloadOpCode) aOpCode payload:(NSData*) aPayload;
- (id) initWithData:(NSData*) aData;

@end
