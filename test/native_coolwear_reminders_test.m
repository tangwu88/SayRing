#import <Foundation/Foundation.h>
#import "../ios/Runner/CoolWearReminders.h"
int main(void) {
    @autoreleasepool {
        NSCAssert(!CoolWearReminderSnapshot(123, @{}), @"Missing became off");
        NSCAssert(!CoolWearReminderSnapshot(123, @{@"onoff":@2}), @"Invalid became enabled");
        NSCAssert(CoolWearReminderSnapshot(123, @{@"onoff":@0}) != nil, @"Actual off lost");
        for (NSUInteger mask = 0; mask <= 255; mask++) {
            uint8_t bytes[7] = {0, 1, (uint8_t)(mask | 128), 8, 0, 20, 0};
            NSData *original = [NSData dataWithBytes:bytes length:7];
            NSData *preserved = CoolWearPreserveSedentaryRepeat(original, mask);
            NSCAssert(preserved.length == 7 && ((const uint8_t *)preserved.bytes)[2] == mask, @"Exact repeat byte changed");
            for (NSUInteger i = 0; i < 7; i++) if (i != 2) NSCAssert(((const uint8_t *)preserved.bytes)[i] == bytes[i], @"Unrelated schedule byte changed");
            NSCAssert(((const uint8_t *)original.bytes)[2] == (mask | 128), @"SDK buffer mutated");
        }
        NSCAssert(!CoolWearPreserveSedentaryRepeat([NSData data], 0), @"Unexpected SDK format accepted");
        NSDictionary *raw = @{@"isOpen":@1, @"startHour":@8, @"startMin":@0, @"endHour":@24,
            @"endMin":@0, @"week_repeat":@255, @"noon_onoff":@1};
        NSDictionary *read = CoolWearReminderSnapshot(114, raw);
        NSCAssert([read[@"endMinutes"] integerValue] == 1440, @"End of day lost");
        NSDictionary *changed = CoolWearReminderChange(114, read, @{@"enabled":@NO, @"startMinutes":@480, @"endMinutes":@1440});
        NSCAssert([changed[@"repeatMask"] isEqual:@255] && [changed[@"noonOff"] isEqual:@1], @"Unedited schedule overwritten");
        NSCAssert([read[@"enabled"] boolValue], @"Input snapshot mutated");
        NSCAssert(!CoolWearReminderChange(114, read, @{@"enabled":@1, @"startMinutes":@480, @"endMinutes":@1440}), @"Integer accepted as Boolean");
        NSCAssert(!CoolWearReminderMinutes(@24, @1), @"Invalid 24:01 accepted");
        NSDictionary *drink = CoolWearReminderSnapshot(126, @{@"onoff":@1, @"startHour":@8, @"startMin":@0,
            @"endHour":@22, @"endMin":@0, @"interval":@2});
        NSCAssert([drink[@"intervalMinutes"] isEqual:@120], @"Vendor interval divided incorrectly");
        NSCAssert(!CoolWearReminderChange(126, drink, @{@"enabled":@YES, @"startMinutes":@480, @"endMinutes":@1320, @"intervalMinutes":@45}), @"Unsupported interval sent");
        for (NSUInteger day = 1; day <= 7; day++) {
            NSArray *days = @[@(day)];
            NSCAssert([CoolWearReminderDays(CoolWearReminderMask(days).unsignedIntegerValue) isEqual:days], @"Weekday mapping wrong");
        }
        NSCAssert(!CoolWearReminderMask(@[@1,@1]), @"Duplicate day accepted");
        NSCAssert(CoolWearReminderSnapshot(106, @{@"alarm_infos":@[]}) != nil, @"SDK empty alarm list rejected");
        NSDictionary *alarm = CoolWearReminderSnapshot(106, @{@"alarm_infos":@[
            @{@"alarmType":@0, @"repeatDay":@255, @"hour":@8, @"min":@30, @"status":@1, @"name":@""},
            @{@"alarmType":@0, @"repeatDay":@127, @"hour":@9, @"min":@0, @"status":@0, @"name":@""}]});
        NSCAssert(alarm != nil, @"Valid alarm lost");
        NSDictionary *next = CoolWearAlarmChange(alarm, @{@"operation":@"update", @"id":@"0", @"enabled":@NO,
            @"hour":@8, @"minute":@30, @"repeatDays":@[@1,@2,@3,@4,@5,@6,@7], @"label":@""});
        NSCAssert([next[@"items"][1] isEqual:alarm[@"items"][1]], @"Other alarm lost");
        NSCAssert(!CoolWearAlarmChange(alarm, @{@"operation":@"delete", @"id":@"999"}), @"Unknown slot removed");
        NSCAssert(!CoolWearReminderSnapshot(106, @{@"alarm_infos":@[@{@"hour":@8}]}), @"Malformed alarm silently skipped");
        NSCAssert(!CoolWearReminderSnapshot(106, @{@"alarm_infos":@[@{@"alarmType":@518, @"repeatDay":@255, @"hour":@8, @"min":@30, @"status":@1, @"name":@""}]}), @"Unverified variant accepted");
        puts("CoolWear reminder contracts passed");
    }
}
