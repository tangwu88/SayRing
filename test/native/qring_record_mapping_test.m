#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingRecordMapping.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        assert(QRingMeasurementValues(@"heart_rate", @72));
        assert(!QRingMeasurementValues(@"heart_rate", @1));
        assert(QRingMeasurementValues(@"blood_oxygen", @97));
        assert(!QRingMeasurementValues(@"blood_oxygen", @1));
        assert(fabs([QRingMeasurementValues(@"body_temperature", @356)[@"value"] doubleValue] - 35.6) < 1e-9);
        assert(!QRingMeasurementValues(@"body_temperature", @35.6));
        assert(!QRingMeasurementValues(@"body_temperature", @1));
        assert(!QRingMeasurementValues(@"body_temperature", @3560));
        assert(!QRingMeasurementValues(@"body_temperature", @(NAN)));
        assert(!QRingMeasurementValues(@"body_temperature", @"35.6"));
        assert(QRingMeasurementValues(@"blood_pressure", @{@"sbp": @"120", @"dbp": @"80"}));
        assert(!QRingMeasurementValues(@"blood_pressure", @{@"sbp": @"80", @"dbp": @"120"}));
        assert(!QRingMeasurementValues(@"stress", @101));
        // Synthetic reproduction of the pinned 260918 SDK's stress completion
        // wrapper. These are adapter fixtures, not readings from a person.
        assert([QRingMeasurementValues(@"stress", @{@"sbp": @42, @"dbp": @0})[@"value"] intValue] == 42);
        assert([QRingMeasurementValues(@"stress", @42)[@"value"] intValue] == 42);
        assert(QRingMeasurementValues(@"stress", @{@"sbp": @1, @"dbp": @0}));
        assert(QRingMeasurementValues(@"stress", @{@"sbp": @100, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @0, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @101, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @255, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @(NAN), @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @90, @"dbp": @60}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @42}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @42, @"dbp": @0, @"extra": @1}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @"42", @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @42, @"dbp": @"0"}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @YES, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"stress", @{@"sbp": @42, @"dbp": NSNull.null}));
        assert(!QRingMeasurementValues(@"heart_rate", @{@"sbp": @42, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"blood_pressure", @{@"sbp": @42, @"dbp": @0}));
        assert(!QRingMeasurementValues(@"unknown", @30));

        NSDate *start = [NSDate dateWithTimeIntervalSince1970:1790726400];
        NSDate *slot1 = [start dateByAddingTimeInterval:900];
        NSDate *slot2 = [start dateByAddingTimeInterval:1800];
        NSDate *end = [start dateByAddingTimeInterval:86400];
        NSDictionary *(^slot)(NSDate *, NSNumber *, NSNumber *, NSNumber *) = ^NSDictionary *(NSDate *date, NSNumber *steps, NSNumber *meters, NSNumber *kcal) {
            return @{@"date": date, @"steps": steps, @"distance": meters, @"calories": kcal};
        };
        NSArray *input = @[
            slot(slot2, @20, @15, @0.8), slot(slot1, @10, @7, @0.4),
            slot(slot1, @10, @7, @0.4), // repeated packet
            slot(slot1, @8, @6, @0.3), // stale duplicate
            slot(end, @999, @999, @999), // another day
            slot([start dateByAddingTimeInterval:-1], @999, @999, @999),
            slot([start dateByAddingTimeInterval:2700], @999, @999, @999), // future
            slot(start, @(-1), @0, @0),
        ];
        NSArray *samples = QRingCumulativeActivitySamples(input, start, end, slot2);
        assert(samples.count == 2);
        assert([samples[0][@"date"] isEqual:slot1]);
        assert([samples[0][@"steps"] intValue] == 10);
        assert([samples[1][@"steps"] intValue] == 30);
        assert(fabs([samples[1][@"distance"] doubleValue] - 0.022) < 1e-9);
        assert(fabs([samples[1][@"calories"] doubleValue] - 1.2) < 1e-9);
        assert([samples isEqual:QRingCumulativeActivitySamples(input, start, end, slot2)]);
        assert(QRingCumulativeActivitySamples(@[], start, end, slot2).count == 0);
        assert([QRingCumulativeActivitySamples(@[slot(start, @0, @0, @0)], start, end, slot2)[0][@"steps"] intValue] == 0);
        NSDictionary *(^segment)(int, int, int) = ^NSDictionary *(int type, int offset, int duration) {
            return @{@"type": @(type), @"begin": [start dateByAddingTimeInterval:offset * 60],
                     @"end": [start dateByAddingTimeInterval:(offset + duration) * 60], @"minutes": @(duration)};
        };
        NSDictionary *sleep = QRingSleepStageValues(@[segment(2, 0, 120), segment(3, 120, 60), segment(4, 180, 30),
            segment(1, 210, 10), segment(5, 220, 50), segment(3, 120, 60)]);
        assert([sleep[@"value"] doubleValue] == 3.5);
        assert([sleep[@"lightHours"] doubleValue] == 2);
        assert([sleep[@"deepHours"] doubleValue] == 1);
        assert([sleep[@"remHours"] doubleValue] == 0.5);
        assert([sleep[@"awakeMinutes"] doubleValue] == 10);
        assert(!QRingSleepStageValues(@[]));
        assert(!QRingSleepStageValues(@[segment(5, 0, 60)]));
        assert(!QRingSleepStageValues(@[segment(2, 0, 900), segment(3, 900, 900)]));
        NSDictionary *overlap = QRingSleepStageValues(@[segment(3, 0, 60), segment(2, 30, 60)]);
        assert([overlap[@"deepHours"] doubleValue] == 0.5);
        assert([overlap[@"lightHours"] doubleValue] == 0.5);
        assert([overlap[@"value"] doubleValue] == 1);
        assert([QRingSleepStageValues(@[segment(3, 0, 60), segment(3, 30, 60)])[@"deepHours"] doubleValue] == 1.5);
        NSDate *readAt = [start dateByAddingTimeInterval:86400];
        NSDictionary *timeline = QRingSleepTimeline(@[segment(3, 0, 60)], @[segment(2, 600, 30)],
            @"qring:device", @"2026-10-01", @"+08:00", readAt);
        assert([timeline[@"sessions"] count] == 2);
        assert([timeline[@"sessions"][0][@"kind"] isEqual:@"night"]);
        assert([timeline[@"sessions"][1][@"kind"] isEqual:@"nap"]);
        assert([timeline[@"sessions"][0][@"rawSegments"] count] == 1);
        assert([NSJSONSerialization dataWithJSONObject:timeline options:0 error:nil]);
        assert(!QRingSleepTimelineHasConflictingSessions(timeline));
        assert(QRingSleepTimelineHasConflictingSessions(QRingSleepTimeline(@[segment(3, 0, 60)], @[segment(2, 30, 30)],
            @"qring:device", @"2026-10-01", @"+08:00", readAt)));
        assert(QRingSleepTimelineHasConflictingSessions(QRingSleepTimeline(@[segment(3, 0, 900), segment(5, 900, 900)], @[],
            @"qring:device", @"2026-10-01", @"+08:00", [start dateByAddingTimeInterval:3 * 86400])));
        NSDictionary *empty = QRingSleepTimeline(@[], @[], @"qring:device", @"2026-10-01", @"+08:00", readAt);
        assert([empty[@"sessions"] count] == 0);
        NSISO8601DateFormatter *requestFormatter = [NSISO8601DateFormatter new];
        NSDate *requestStart = [requestFormatter dateFromString:@"2026-10-01T00:00:00+08:00"];
        NSDictionary *requestDay = QRingSleepRequestContext(requestStart, [NSTimeZone timeZoneWithName:@"Asia/Shanghai"]);
        NSDictionary *laterPhoneDay = QRingSleepRequestContext([requestStart dateByAddingTimeInterval:2 * 86400],
            [NSTimeZone timeZoneWithName:@"America/New_York"]);
        assert(![requestDay[@"sdkDate"] isEqual:laterPhoneDay[@"sdkDate"]]);
        assert(![requestDay[@"timezone"] isEqual:laterPhoneDay[@"timezone"]]);
        NSDictionary *lateTimeline = QRingSleepTimeline(@[segment(3, 0, 60)], @[], @"qring:device",
            requestDay[@"sdkDate"], requestDay[@"timezone"], [requestStart dateByAddingTimeInterval:2 * 86400]);
        assert([lateTimeline[@"sdkDate"] isEqual:@"2026-10-01"]);
        assert([lateTimeline[@"timezone"] isEqual:@"+08:00"]);
        assert([requestDay[@"dayStart"] isEqual:requestStart]);
        puts("QRing Foundation mapping assertions passed (synthetic inputs, not hardware acceptance)");
    }
    return 0;
}
