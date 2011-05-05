//
//  MyWebSocketDelegate.m
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

#import "MyWebSocketDelegate.h"


@implementation MyWebSocketDelegate

@synthesize response;

- (void) didOpen
{
    NSLog(@"Did open");
    [test.ws send:@"Blue"];
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

- (id) initWithTest: (UnittWebSocketClientTests*) aTest
{
    self = [super init];
    if (self) 
    {
        test = aTest;
    }
    return self;
}

- (void)dealloc 
{
    [response release];
    [super dealloc];
}

@end
