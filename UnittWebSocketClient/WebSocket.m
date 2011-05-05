//
//  WebSocket.m
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

#import "WebSocket.h"


@interface WebSocket(Private)
- (void) dispatchFailure:(NSError*) aError;
- (void) dispatchClosed:(NSError*) aWasClean;
- (void) dispatchOpened ;
- (void) dispatchMessageReceived:(NSString*) aMessage;
- (void) readNextMessage;
- (NSString*) buildOrigin;
- (NSString*) getRequest: (NSString*) aRequestPath;
- (NSData*) getSHA1:(NSData*) aPlainText;
- (void) generateSecKeys;
- (BOOL) isUpgradeResponse: (NSString*) aResponse;
- (NSString*) getServerProtocol:(NSString*) aResponse;
@end


@implementation WebSocket


NSString* const WebSocketException = @"WebSocketException";
NSString* const WebSocketErrorDomain = @"WebSocketErrorDomain";

enum 
{
    TagHandshake = 0,
    TagMessage = 1
};


@synthesize delegate;
@synthesize url;
@synthesize origin;
@synthesize readystate;
@synthesize timeout;
@synthesize tlsSettings;
@synthesize protocols;
@synthesize verifyAccept;
@synthesize serverProtocol;


#pragma mark Public Interface
- (void) open
{
    UInt16 port = isSecure ? 443 : 80;
    if (self.url.port)
    {
        port = [self.url.port intValue];
    }
    NSError* error = nil;
    BOOL successful = false;
    @try 
    {
        successful = [socket connectToHost:self.url.host onPort:port error:&error];
    }
    @catch (NSException *exception) 
    {
        error = [NSError errorWithDomain:WebSocketErrorDomain code:0 userInfo:exception.userInfo]; 
    }
    @finally 
    {
        if (!successful)
        {
            [self dispatchClosed:error];
        }
    }
}

- (void) close
{
    readystate = WebSocketReadyStateClosing;
    [socket disconnectAfterWriting];
}

- (void) send:(NSString*) aMessage
{
    NSMutableData* data = [NSMutableData data];
    [data appendBytes:"\x00" length:1];
    [data appendData:[aMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendBytes:"\xFF" length:1];
    [socket writeData:data withTimeout:self.timeout tag:TagMessage];
}

#pragma mark Internal Web Socket Logic
- (void) readNextMessage 
{
    [socket readDataToData:[NSData dataWithBytes:"\xFF" length:1] withTimeout:self.timeout tag:TagMessage];
}

- (NSData*) getSHA1:(NSData*) aPlainText 
{
    CC_SHA1_CTX ctx;
    uint8_t * hashBytes = NULL;
    NSData * hash = nil;
    
    // Malloc a buffer to hold hash.
    hashBytes = malloc( CC_SHA1_DIGEST_LENGTH * sizeof(uint8_t) );
    memset((void *)hashBytes, 0x0, CC_SHA1_DIGEST_LENGTH);
    
    // Initialize the context.
    CC_SHA1_Init(&ctx);
    // Perform the hash.
    CC_SHA1_Update(&ctx, (void *)[aPlainText bytes], [aPlainText length]);
    // Finalize the output.
    CC_SHA1_Final(hashBytes, &ctx);
    
    // Build up the SHA1 blob.
    hash = [NSData dataWithBytes:(const void *)hashBytes length:(NSUInteger)CC_SHA1_DIGEST_LENGTH];
    
    if (hashBytes) free(hashBytes);
    
    return hash;
}

- (NSString*) getRequest: (NSString*) aRequestPath
{
    [self generateSecKeys];
    if (self.protocols && self.protocols.count > 0)
    {
        //build protocol fragment
        NSMutableString* protocolFragment = [NSMutableString string];
        for (NSString* item in protocols)
        {
            if ([protocolFragment length] > 0) 
            {
                [protocolFragment appendString:@", "];
            }
            [protocolFragment appendString:item];
        }
        
        //return request with protocols
        if ([protocolFragment length] > 0)
        {
            return [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\n"
                    "Upgrade: WebSocket\r\n"
                    "Connection: Upgrade\r\n"
                    "Host: %@\r\n"
                    "Origin: %@\r\n"
                    "Sec-WebSocket-Protocol: %@\r\n"
                    "Sec-WebSocket-Key: %@\r\n"
                    "Sec-WebSocket-Version: 7\r\n"
                    "\r\n",
                    aRequestPath, self.url.host, self.origin, protocolFragment, wsSecKey];
        }
    }
    
    //return request normally
    return [NSString stringWithFormat:@"GET %@ HTTP/1.1\r\n"
            "Upgrade: WebSocket\r\n"
            "Connection: Upgrade\r\n"
            "Host: %@\r\n"
            "Origin: %@\r\n"
            "Sec-WebSocket-Key: %@\r\n"
            "Sec-WebSocket-Version: 7\r\n"
            "\r\n",
            aRequestPath, self.url.host, self.origin, wsSecKey];
}

- (void) generateSecKeys
{
    NSString* initialString = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
    NSData *data = [initialString dataUsingEncoding:NSUTF8StringEncoding];
	NSString* key = [data base64EncodedString];
    wsSecKey = [key copy];
    key = [NSString stringWithFormat:@"%@%@", wsSecKey, @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"];
    data = [self getSHA1:[key dataUsingEncoding:NSUTF8StringEncoding]];
    key = [data base64EncodedString];
    wsSecKeyHandshake = [key copy];
}

- (BOOL) isUpgradeResponse: (NSString*) aResponse
{
    //a HTTP 101 response is the only valid one
    if ([aResponse hasPrefix:@"HTTP/1.1 101"])
    {        
        //continuing verifying that we are upgrading
        NSArray *listItems = [aResponse componentsSeparatedByString:@"\r\n"];
        BOOL foundUpgrade = NO;
        BOOL foundConnection = NO;
        BOOL verifiedAccept = !verifyAccept;
        
        //loop through headers testing values
        for (NSString* item in listItems) 
        {
            //search for -> Upgrade: websocket & Connection: Upgrade
            if ([item rangeOfString:@"Upgrade" options:NSCaseInsensitiveSearch].length)
            {
                if (!foundUpgrade) 
                {
                    foundUpgrade = [item rangeOfString:@"WebSocket" options:NSCaseInsensitiveSearch].length;
                }
                if (!foundConnection) 
                {
                    foundConnection = [item rangeOfString:@"Connection" options:NSCaseInsensitiveSearch].length;
                }
            }
            
            //if we are verifying - do so
            if (!verifiedAccept && [item rangeOfString:@"Sec-WebSocket-Accept" options:NSLiteralSearch].length)
            {
                //grab the key
                NSRange range = [item rangeOfString:@":" options:NSLiteralSearch];
                NSString* value = [item substringFromIndex:range.length + range.location];
                value = [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
                verifiedAccept = [wsSecKeyHandshake isEqualToString:value];
            }
            
            //if we have what we need, get out
            if (foundUpgrade && foundConnection && verifiedAccept)
            {
                return true;
            }
        }
    }
    
    return false;
}

- (NSString*) getServerProtocol:(NSString*) aResponse
{
    //loop through headers looking for the protocol    
    NSArray *listItems = [aResponse componentsSeparatedByString:@"\r\n"];
    for (NSString* item in listItems) 
    {
        //if this is the protocol - return the value
        if ([item rangeOfString:@"Sec-WebSocket-Protocol" options:NSCaseInsensitiveSearch].length)
        {
            NSRange range = [item rangeOfString:@":" options:NSLiteralSearch];
            NSString* value = [item substringFromIndex:range.length + range.location];
            return [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        }
    }
    
    return nil;
}


#pragma mark Web Socket Delegate
- (void) dispatchFailure:(NSError*) aError 
{
    if(delegate) 
    {
        [delegate didReceiveError:aError];
    }
}

- (void) dispatchClosed:(NSError*) aError
{
    if (delegate)
    {
        [delegate didClose: aError];
        [aError release];
    }
}

- (void) dispatchOpened 
{
    if (delegate) 
    {
        [delegate didOpen];
    }
}

- (void) dispatchMessageReceived:(NSString*) aMessage 
{
    if (delegate)
    {
        [delegate didReceiveMessage:aMessage];
    }
}


#pragma mark AsyncSocket Delegate
- (void) onSocketDidDisconnect:(AsyncSocket*) aSock 
{
    readystate = WebSocketReadyStateClosed;
    [self dispatchClosed: closingError];
}

- (void) onSocket:(AsyncSocket *) aSocket willDisconnectWithError:(NSError *) aError
{
    switch (self.readystate) 
    {
        case WebSocketReadyStateOpen:
        case WebSocketReadyStateConnecting:
            readystate = WebSocketReadyStateClosing;
            [self dispatchFailure:aError];
        case WebSocketReadyStateClosing:
            closingError = [aError retain]; 
    }
}

- (void) onSocket:(AsyncSocket*) aSocket didConnectToHost:(NSString*) aHost port:(UInt16) aPort 
{
    //start TLS if this is a secure websocket
    if (isSecure)
    {
        // Configure SSL/TLS settings
        NSDictionary *settings = self.tlsSettings;
        
        //seed with defaults if missing
        if (!settings)
        {
            settings = [NSMutableDictionary dictionaryWithCapacity:3];
        }
        
        [socket startTLS:settings];
    }
    
    //continue with handshake
    NSString *requestPath = self.url.path;
    if (self.url.query) 
    {
        requestPath = [requestPath stringByAppendingFormat:@"?%@", self.url.query];
    }
    //@todo: handle protocol and security key
    NSString* getRequest = [self getRequest: requestPath];
    [aSocket writeData:[getRequest dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.timeout tag:TagHandshake];
}

- (void) onSocket:(AsyncSocket*) aSocket didWriteDataWithTag:(long) aTag 
{
    if (aTag == TagHandshake) 
    {
        [aSocket readDataToData:[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.timeout tag:TagHandshake];
    }
}

- (void) onSocket: (AsyncSocket*) aSocket didReadData:(NSData*) aData withTag:(long) aTag 
{
    if (aTag == TagHandshake) 
    {
        NSString* response = [[[NSString alloc] initWithData:aData encoding:NSASCIIStringEncoding] autorelease];
        if ([self isUpgradeResponse: response]) 
        {
            //grab protocol from server
            NSString* protocol = [self getServerProtocol:response];
            if (protocol)
            {
                serverProtocol = [protocol copy];
            }
            
            //handle state & delegates
            readystate = WebSocketReadyStateOpen;
            [self dispatchOpened];
            [self readNextMessage];
        } 
        else 
        {
            [self dispatchFailure:[NSError errorWithDomain:WebSocketErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:@"Bad handshake" forKey:NSLocalizedFailureReasonErrorKey]]];
        }
    } 
    else if (aTag == TagMessage) 
    {
        char firstByte = 0xFF;
        [aData getBytes:&firstByte length:1];
        if (firstByte != 0x00) return; // Discard message
        NSString* message = [[[NSString alloc] initWithData:[aData subdataWithRange:NSMakeRange(1, [aData length]-2)] encoding:NSUTF8StringEncoding] autorelease];
        [self dispatchMessageReceived:message];
        [self readNextMessage];
    }
}


#pragma mark Lifecycle
+ (id) webSocketWithURLString:(NSString*) aUrlString delegate:(id<WebSocketDelegate>) aDelegate origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifyAccept:(BOOL) aVerifyAccept
{
    return [[[WebSocket alloc] initWithURLString:aUrlString delegate:aDelegate origin:aOrigin protocols:aProtocols tlsSettings:aTlsSettings verifyAccept:aVerifyAccept] autorelease];
}

- (id) initWithURLString:(NSString *) aUrlString delegate:(id<WebSocketDelegate>) aDelegate origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings verifyAccept:(BOOL) aVerifyAccept
{
    self = [super init];
    if (self) 
    {
        //validate
        NSURL* tempUrl = [NSURL URLWithString:aUrlString];
        if (![tempUrl.scheme isEqualToString:@"ws"] && ![tempUrl.scheme isEqualToString:@"wss"]) 
        {
            [NSException raise:WebSocketException format:[NSString stringWithFormat:@"Unsupported protocol %@",tempUrl.scheme]];
        }
        
        //apply properties
        url = [tempUrl retain];
        self.delegate = aDelegate;
        isSecure = [self.url.scheme isEqualToString:@"wss"];
        if (aOrigin)
        {
            origin = [aOrigin copy];
        }
        else
        {
            origin = [[self buildOrigin] copy];
        }
        if (aProtocols)
        {
            protocols = [aProtocols retain];
        }
        if (aTlsSettings)
        {
            tlsSettings = [aTlsSettings retain];
        }
        verifyAccept = aVerifyAccept;
        socket = [[AsyncSocket alloc] initWithDelegate:self];
        self.timeout = 30.0;
    }
    return self;
}

- (NSString*) buildOrigin
{
    return [NSString stringWithFormat:@"%@://%@%@", isSecure ? @"https" : @"http", self.url.host, self.url.path ? self.url.path : @""];
}

-(void) dealloc 
{
    socket.delegate = nil;
    [socket disconnect];
    [socket release];
    [delegate release];
    [url release];
    [origin release];
    [closingError release];
    [protocols release];
    [tlsSettings release];
    [super dealloc];
}

@end
