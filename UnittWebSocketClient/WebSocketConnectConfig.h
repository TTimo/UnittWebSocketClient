//
//  WebSocketConnectConfig.h
//  UnittWebSocketClient
//
//  Created by Josh Morris on 9/26/11.
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
    WebSocketVersion07 = 7,
    WebSocketVersion08 = 8,
    WebSocketVersion10 = 10
};
typedef NSUInteger WebSocketVersion;


@interface WebSocketConnectConfig : NSObject
{
@private
    NSURL* url;
    NSString* origin;
    NSString* host;
    NSTimeInterval timeout;
    NSDictionary* tlsSettings;
    NSArray* protocols;
    NSString* serverProtocol;
    BOOL verifySecurityKey;
    NSUInteger maxPayloadSize;
    NSTimeInterval closeTimeout;
    WebSocketVersion version;
    BOOL isSecure;
}

/**
 * Version of the websocket specification.
 **/
@property(nonatomic,assign) WebSocketVersion version;

/**
 * Max size of the payload. Any messages larger will be sent as fragments.
 **/
@property(nonatomic,assign) NSUInteger maxPayloadSize;

/**
 * Timeout used for sending messages, not establishing the socket connection. A
 * value of -1 will result in no timeouts being applied.
 **/
@property(nonatomic,assign) NSTimeInterval timeout;

/**
 * Timeout used for the closing handshake. If this timeout is exceeded, the socket
 * will be forced closed. A value of -1 will result in no timeouts being applied.
 **/
@property(nonatomic,assign) NSTimeInterval closeTimeout;

/**
 * URL of the websocket
 **/
@property(nonatomic,readonly) NSURL* url;

/**
 * Indicates whether the websocket will be opened over a secure connection
 **/
@property(nonatomic,readonly) BOOL isSecure;

/**
 * Origin is used more in a browser setting, but it is intended to prevent cross-site scripting. If
 * nil, the client will fill this in using the url provided by the websocket.
 **/
@property(nonatomic,readonly) NSString* origin;

/**
 * The host string is created from the url.
 **/
@property(nonatomic,readonly) NSString* host;


/**
 * Settings for securing the connection using SSL/TLS.
 * 
 * The possible keys and values for the TLS settings are well documented.
 * Some possible keys are:
 * - kCFStreamSSLLevel
 * - kCFStreamSSLAllowsExpiredCertificates
 * - kCFStreamSSLAllowsExpiredRoots
 * - kCFStreamSSLAllowsAnyRoot
 * - kCFStreamSSLValidatesCertificateChain
 * - kCFStreamSSLPeerName
 * - kCFStreamSSLCertificates
 * - kCFStreamSSLIsServer
 * 
 * Please refer to Apple's documentation for associated values, as well as other possible keys.
 * 
 * If the value is nil or an empty dictionary, then the websocket cannot be secured.
 **/
@property(nonatomic,readonly) NSDictionary* tlsSettings;

/**
 * The subprotocols supported by the client. Each subprotocol is represented by an NSString.
 **/
@property(nonatomic,readonly) NSArray* protocols;

/**
 * True if the client should verify the handshake security key sent by the server. Since many of
 * the web socket servers may not have been updated to support this, set to false to ignore
 * and simply accept the connection to the server.
 **/
@property(nonatomic,readonly) BOOL verifySecurityKey; 

/**
 * The subprotocol selected by the server, nil if none was selected
 **/
@property(nonatomic,copy) NSString* serverProtocol;


+ (id) webSocketWithURLString:(NSString*) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifySecurityKey:(BOOL) aVerifySecurityKey;
- (id) initWithURLString:(NSString *) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifySecurityKey:(BOOL) aVerifySecurityKey;

extern NSString *const WebSocketConnectConfigException;
extern NSString *const WebSocketConnectConfigErrorDomain;

@end
