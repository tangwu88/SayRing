#import <Foundation/Foundation.h>
// Runs production history bookkeeping and scheduling, with no SDK/hardware.
typedef void (^FlutterResult)(id);
static BOOL SRActivitySleepMetricAllowed(NSString *metric) { return ![metric isEqual:@"blocked"]; }
static NSUInteger checked;
static void check(BOOL value) { checked++; if (!value) { fputs("History assertion failed\n", stderr); exit(1); } }
@interface HistoryBridge : NSObject
@property(nonatomic, copy) FlutterResult pendingSync;
@property(nonatomic) NSUInteger syncGeneration;
@property(nonatomic, strong) NSMutableArray *syncRecords;
@property(nonatomic, strong) NSMutableDictionary *syncStatuses;
@property(nonatomic, strong) NSMutableDictionary *syncCompletedDays;
@property(nonatomic, strong) NSMutableArray *schedule;
- (void)noteHistory:(NSString *)metric day:(NSInteger)day failed:(BOOL)failed;
- (void)syncDay:(NSInteger)day phase:(NSInteger)phase;
- (void)advanceSyncDay:(NSInteger)day phase:(NSInteger)phase;
- (void)finishHealthSync;
- (void)finishTimedOutHealthSyncForGeneration:(NSUInteger)generation;
@end
@implementation HistoryBridge
- (void)syncDay:(NSInteger)day phase:(NSInteger)phase {
 if (day >= 7) { if (phase == 0) [self syncDay:0 phase:2]; return; }
 [self.schedule addObject:@[@(day),@(phase)]];
 [self advanceSyncDay:day phase:phase];
}
// ACTUAL_HISTORY_METHODS
@end
static HistoryBridge *make(void) {
 HistoryBridge *b=[HistoryBridge new]; b.syncGeneration=7;
 b.syncRecords=[NSMutableArray new];b.syncStatuses=[@{@"steps":@"pending",@"sleep":@"pending"} mutableCopy];
 b.syncCompletedDays=[NSMutableDictionary new];b.schedule=[NSMutableArray new];return b;
}
int main(void) { @autoreleasepool {
 HistoryBridge *b=make();
 [b noteHistory:@"steps" day:0 failed:NO];check([b.syncStatuses[@"steps"] isEqual:@"pending"]);
 for(int i=0;i<7;i++) [b noteHistory:@"steps" day:0 failed:NO];
 check([b.syncStatuses[@"steps"] isEqual:@"pending"]);
 [b.syncRecords addObject:@{@"type":@"steps",@"value":@123}];
 for(int i=1;i<7;i++) [b noteHistory:@"steps" day:i failed:NO];
 check([b.syncStatuses[@"steps"] isEqual:@"complete"]);
 for(int i=0;i<7;i++) [b noteHistory:@"sleep" day:i failed:NO];
 check([b.syncStatuses[@"sleep"] isEqual:@"no_data"]);
 [b noteHistory:@"blocked" day:0 failed:NO];check(!b.syncStatuses[@"blocked"]);
 b=make();[b noteHistory:@"sleep" day:3 failed:YES];
 for(int i=0;i<7;i++) [b noteHistory:@"sleep" day:i failed:NO];
 check([b.syncStatuses[@"sleep"] isEqual:@"partial"]);
 __block NSDictionary *result=nil;__block NSUInteger replies=0;
 b.pendingSync=^(id value){result=value;replies++;};
 NSDictionary *raw=@{@"type":@"steps",@"value":@321};[b.syncRecords addObject:raw];
 [b finishTimedOutHealthSyncForGeneration:6];check(replies==0 && b.pendingSync!=nil);
 [b finishTimedOutHealthSyncForGeneration:7];
 check(replies==1 && b.pendingSync==nil && b.syncGeneration==8);
 check([result[@"records"] isEqual:@[raw]]);
 check([result[@"statuses"][@"steps"] isEqual:@"partial"]);
 check([result[@"statuses"][@"sleep"] isEqual:@"partial"]);
 [b finishTimedOutHealthSyncForGeneration:7];check(replies==1);
 b=make(); [b syncDay:0 phase:0];check(b.schedule.count==49);
 for(int i=0;i<14;i++)check([b.schedule[i] isEqual:@[@(i/2),@(i%2)]]);
 for(int i=14;i<49;i++)check([b.schedule[i] isEqual:@[@((i-14)/5),@((i-14)%5+2)]]);
 printf("QRing actual history bookkeeping: %lu assertions passed\n",(unsigned long)checked);
 } return 0; }
