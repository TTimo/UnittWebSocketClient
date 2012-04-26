//
//  Created by jmorris on 2/13/12.
//


#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "WebSocket.h"


enum
{
    AutobahnTestStateGettingTestCount = 0, //getting the number of test cases to run
    AutobahnTestStateExecutingTest = 1, //executing a test case
    AutobahnTestStateUpdateReport = 2 //update report after each test case
};
typedef NSUInteger AutobahnTestState;


@interface AutobahnTest : SenTestCase<WebSocketDelegate>
{
    WebSocket* ws;
    WebSocketConnectConfig* config;
    int totalTests;
    int currentTest;
    AutobahnTestState testState;
    NSArray* testNames;
}


@property(nonatomic, retain) WebSocket* ws;
@property(nonatomic) int totalTests;
@property(nonatomic) int currentTest;
@property(nonatomic) AutobahnTestState testState;
@property(nonatomic, retain) WebSocketConnectConfig *config;


- (void) runNextTest;
- (void) runUpdate;
- (void) waitForSeconds: (NSTimeInterval) aSeconds;


@end