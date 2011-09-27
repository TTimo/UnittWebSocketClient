//
//  WebSocketConnectConfig.m
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

#import "WebSocketConnectConfig.h"


@interface WebSocketConnectConfig()

- (NSString*) buildOrigin;
- (NSString*) buildHost;

@end


@implementation WebSocketConnectConfig


@synthesize version;
@synthesize maxPayloadSize;
@synthesize url;
@synthesize origin;
@synthesize host;
@synthesize timeout;
@synthesize closeTimeout;
@synthesize tlsSettings;
@synthesize protocols;
@synthesize verifySecurityKey;
@synthesize serverProtocol;
@synthesize isSecure;


NSString* const WebSocketConnectConfigException = @"WebSocketConnectConfigException";
NSString* const WebSocketConnectConfigErrorDomain = @"WebSocketConnectConfigErrorDomain";


#pragma mark Lifecycle
+ (id) webSocketWithURLString:(NSString*) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifySecurityKey:(BOOL) aVerifySecurityKey
{
    return [[[[self class] alloc] initWithURLString:aUrlString origin:aOrigin protocols:aProtocols tlsSettings:aTlsSettings verifySecurityKey:aVerifySecurityKey] autorelease];
}

- (id) initWithURLString:(NSString *) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifySecurityKey:(BOOL) aVerifySecurityKey
{
    self = [super init];
    if (self) 
    {
        //validate
        NSURL* tempUrl = [NSURL URLWithString:aUrlString];
        if (![tempUrl.scheme isEqualToString:@"ws"] && ![tempUrl.scheme isEqualToString:@"wss"]) 
        {
            [NSException raise:WebSocketConnectConfigException format:@"Unsupported protocol %@",tempUrl.scheme];
        }
        
        //apply properties
        url = [tempUrl retain];
        isSecure = [self.url.scheme isEqualToString:@"wss"];
        if (aOrigin)
        {
            origin = [aOrigin copy];
        }
        else
        {
            origin = [[self buildOrigin] copy];
        }
        host = [[self buildHost] copy];
        if (aProtocols)
        {
            protocols = [aProtocols retain];
        }
        if (aTlsSettings)
        {
            tlsSettings = [aTlsSettings retain];
        }
        verifySecurityKey = aVerifySecurityKey;
        self.timeout = 30.0;
        self.closeTimeout = 30.0;
        self.maxPayloadSize = 32*1024;
        self.version = WebSocketVersion07;
    }
    return self;
}

- (NSString*) buildOrigin
{
    if (self.url.port && [self.url.port intValue] != 80 && [self.url.port intValue] != 443)
    {
        return [NSString stringWithFormat:@"%@://%@:%i%@", isSecure ? @"https" : @"http", self.url.host, [self.url.port intValue], self.url.path ? self.url.path : @""];
    }
    
    return [NSString stringWithFormat:@"%@://%@%@", isSecure ? @"https" : @"http", self.url.host, self.url.path ? self.url.path : @""];
}

- (NSString*) buildHost
{
    if (self.url.port)
    {
        if ([self.url.port intValue] == 80 || [self.url.port intValue] == 443)
        {
            return self.url.host;
        }
        
        return [NSString stringWithFormat:@"%@:%i", self.url.host, [self.url.port intValue]];
    }
    
    return self.url.host;
}

-(void) dealloc 
{
    [url release];
    [origin release];
    [host release];
    [protocols release];
    [tlsSettings release];
    [super dealloc];
}

@end
