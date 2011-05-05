//
//  WebSocket.h
//  UnittWebSocketClient
//
//  Created by Josh Morris on 5/3/11.
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
#import "AsyncSocket.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "NSData+Base64.h"


enum 
{
    WebSocketReadyStateConnecting = 0,
    WebSocketReadyStateOpen = 1,
    WebSocketReadyStateClosing = 2,
    WebSocketReadyStateClosed = 3
};
typedef NSUInteger WebSocketReadyState;

@protocol WebSocketDelegate <NSObject>

- (void) didOpen;
- (void) didClose: (NSError*) aError;

- (void) didReceiveError: (NSError*) aError;
- (void) didReceiveMessage: (NSString*) aMessage;

@end

@interface WebSocket : NSObject 
{
@private
    id<WebSocketDelegate> delegate;
    NSURL* url;
    NSString* origin;
    AsyncSocket* socket;
    WebSocketReadyState readystate;
    NSError* closingError;
    BOOL isSecure;
    NSTimeInterval timeout;
    NSDictionary* tlsSettings;
    NSArray* protocols;
    NSString* serverProtocol;
    NSString* wsSecKey;
    NSString* wsSecKeyHandshake;
    BOOL verifyAccept;
}


@property(nonatomic,retain) id<WebSocketDelegate> delegate;
@property(nonatomic,assign) NSTimeInterval timeout;
@property(nonatomic,readonly) NSURL* url;
@property(nonatomic,readonly) NSString* origin;
@property(nonatomic,readonly) WebSocketReadyState readystate;
@property(nonatomic,readonly) NSDictionary* tlsSettings;
@property(nonatomic,readonly) NSArray* protocols;
@property(nonatomic,readonly) BOOL verifyAccept;
@property(nonatomic,readonly) NSString* serverProtocol;

+ (id)webSocketWithURLString:(NSString*) aUrlString delegate:(id<WebSocketDelegate>) aDelegate origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifyAccept:(BOOL) aVerifyAccept;
- (id)initWithURLString:(NSString*) aUrlString delegate:(id<WebSocketDelegate>) aDelegate origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifyAccept:(BOOL) aVerifyAccept;

- (void)open;
- (void)close;
- (void)send:(NSString*)message;


extern NSString *const WebSocketException;
extern NSString *const WebSocketErrorDomain;

@end
