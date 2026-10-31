#import <Foundation/Foundation.h>
#import <stdio.h>
#import <string.h>
#import SAY_RING_QRING_CAMERA_POLICY_HEADER
#import "QRingGesturePolicy.h"

static NSInteger checks;
#define CHECK(condition, message) do { \
    checks++; \
    if (!(condition)) { \
        fprintf(stderr, "FAIL: %s (line %d)\n", message, __LINE__); \
        return 1; \
    } \
} while (0)

static NSDictionary *snapshot(NSInteger mode, NSInteger strength, BOOL touch,
                              NSInteger duration, BOOL screenTouch) {
#if SAY_RING_QRING_LEGACY_CAMERA_POLICY
    // Keep the old implementation intact: the legacy policy had no distinction
    // between ordinary touch and screen touch. This adapter only supplies arity.
    (void)screenTouch;
    return QRingCameraSnapshot(mode, strength, touch, duration);
#else
    return QRingCameraSnapshot(mode, strength, touch, duration, screenTouch);
#endif
}

static BOOL isBoolean(id value) {
    return value && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static int ordinaryTouch(void) {
    for (NSInteger mode = 0; mode <= 9; mode++) {
        for (NSNumber *duration in @[@1, @10]) {
            NSDictionary *raw = snapshot(mode, 0, YES, duration.integerValue, NO);
            CHECK(raw != nil, "ordinary touch callback with reserved strength=0 must be accepted");
            CHECK([raw[@"mode"] integerValue] == mode, "original firmware mode must be retained");
            CHECK([raw[@"strength"] isEqual:@0], "reserved zero must not become a fabricated strength");
            CHECK([raw[@"duration"] isEqual:duration], "original sleep duration must be retained");
            CHECK([raw[@"touch"] boolValue] && isBoolean(raw[@"touch"]), "touch must remain a Flutter boolean");
            CHECK([raw[@"enabled"] boolValue] == (mode == 5), "only firmware photo mode enables camera control");
        }
    }
    return 0;
}

static int boundaries(void) {
    for (NSNumber *touchValue in @[@NO, @YES]) {
        BOOL touch = touchValue.boolValue;
        for (NSNumber *screenValue in @[@NO, @YES]) {
            BOOL screen = screenValue.boolValue;
            NSInteger duration = touch ? 1 : 0;
            for (NSNumber *mode in @[@0, @9]) {
                for (NSNumber *strength in @[@1, @10]) {
                    NSDictionary *raw = snapshot(mode.integerValue, strength.integerValue,
                                                  touch, duration, screen);
                    CHECK(raw != nil, "existing valid mode and strength endpoints must remain accepted");
                    CHECK([raw[@"strength"] isEqual:strength], "valid strength must not be normalized");
                    CHECK([raw[@"duration"] integerValue] == duration, "gesture reserved duration must be preserved");
                }
            }
            for (NSNumber *mode in @[@(-1), @10, @(NSIntegerMin), @(NSIntegerMax)]) {
                CHECK(snapshot(mode.integerValue, 1, touch, duration, screen) == nil,
                      "out-of-range firmware mode must be rejected");
            }
            for (NSNumber *strength in @[@(-1), @11, @(NSIntegerMin), @(NSIntegerMax)]) {
                CHECK(snapshot(5, strength.integerValue, touch, duration, screen) == nil,
                      "negative or excessive strength must be rejected for every control type");
            }
            if (screen) {
                CHECK(snapshot(5, 0, touch, duration, screen) == nil,
                      "screen-touch zero strength must remain invalid");
            }
            if (touch) {
                for (NSNumber *badDuration in @[@(-1), @0, @11, @(NSIntegerMin), @(NSIntegerMax)]) {
                    CHECK(snapshot(5, 1, YES, badDuration.integerValue, screen) == nil,
                          "touch sleep duration outside 1...10 must be rejected");
                    CHECK(snapshot(5, 0, YES, badDuration.integerValue, screen) == nil,
                          "reserved strength must not bypass touch duration validation");
                }
                CHECK(snapshot(5, 1, YES, 10, screen) != nil,
                      "maximum valid touch duration must remain accepted");
            }
        }
    }
    return 0;
}

static int closedGesture(void) {
    // XR/R8 returned these values through getGestureControl with NSError=nil.
    // A later first-enable read returned mode=1, strength=1 (tested below).
    NSDictionary *raw = snapshot(0, 0, NO, 0, NO);
    CHECK(raw != nil, "successful closed gesture callback with zero strength must be accepted");
    CHECK([raw[@"mode"] isEqual:@0], "observed closed mode must be retained");
    CHECK([raw[@"strength"] isEqual:@0], "closed gesture strength must not become a fabricated default");
    CHECK([raw[@"duration"] isEqual:@0], "gesture reserved duration must remain zero");
    CHECK(![raw[@"touch"] boolValue] && isBoolean(raw[@"touch"]), "gesture must not be mislabeled as touch");
    CHECK(![raw[@"enabled"] boolValue], "closed gesture must not enable the camera");
    NSArray *modes = @[@0, @1, @2, @4];
    NSDictionary *value = QRingGestureSnapshot(raw, modes);
    CHECK(value != nil && [value[@"confirmedMode"] isEqual:@0], "closed gesture must display as confirmed off");
    CHECK([value[@"rawMode"] isEqual:@0] && [value[@"strength"] isEqual:@0], "presentation must preserve observed raw values");
    CHECK(isBoolean(value[@"enabled"]) && ![value[@"enabled"] boolValue], "closed state must remain a real false boolean");
    CHECK(isBoolean(value[@"readbackVerified"]) && [value[@"readbackVerified"] boolValue], "successful read must remain confirmed");
    CHECK([value[@"availableModes"] isEqual:modes], "zero strength must not invent or remove supported modes");
    return 0;
}

static int gestureModes(void) {
    NSArray *rawModes = @[@0, @2, @1, @4, @5, @6];
    NSArray *availableModes = @[@0, @1, @4];
    for (NSInteger appMode = 0; appMode < 6; appMode++) {
        NSInteger rawMode = [rawModes[appMode] integerValue];
        CHECK(QRingGestureRawMode(appMode) == rawMode, "App-to-firmware mode mapping changed");
        CHECK(QRingGestureAppMode(rawMode) == appMode, "firmware-to-App mode mapping changed");
        NSDictionary *value = QRingGestureSnapshot(snapshot(rawMode, 0, YES, 8, NO), availableModes);
        CHECK(value != nil, "ordinary touch zero must also produce a gesture snapshot");
        CHECK([value[@"confirmedMode"] integerValue] == appMode, "actual mode must be selected correctly");
        CHECK([value[@"rawMode"] integerValue] == rawMode, "raw firmware mode must survive presentation");
        CHECK([value[@"enabled"] boolValue] == (rawMode != 0), "only off mode is disabled");
        CHECK([value[@"strength"] isEqual:@0], "gesture presentation must preserve reserved strength");
        CHECK([value[@"duration"] isEqual:@8], "gesture presentation must preserve sleep duration");
        CHECK([value[@"availableModes"] isEqual:availableModes], "presentation must not invent supported modes");
        CHECK(isBoolean(value[@"readbackVerified"]) && [value[@"readbackVerified"] boolValue],
              "a valid snapshot must contain a real readback boolean");
        CHECK(isBoolean(value[@"enabled"]), "gesture enable state must be a Flutter boolean");
    }
    for (NSNumber *rawMode in @[@3, @7, @8, @9]) {
        NSDictionary *value = QRingGestureSnapshot(snapshot(rawMode.integerValue, 0, YES, 8, NO), availableModes);
        CHECK(value != nil, "valid unmapped firmware mode must remain readable");
        CHECK([value[@"confirmedMode"] integerValue] == -1, "unmapped mode must not be marked as off");
        CHECK([value[@"enabled"] boolValue], "unmapped active mode must remain enabled");
        CHECK([value[@"rawMode"] isEqual:rawMode], "unmapped original mode must be preserved");
        CHECK([value[@"strength"] isEqual:@0] && [value[@"duration"] isEqual:@8],
              "unmapped mode must not lose other original settings");
    }
    CHECK(QRingGestureRawMode(-1) == -1 && QRingGestureRawMode(6) == -1,
          "out-of-range App mode must not become a firmware command");
    CHECK(QRingGestureSnapshot(snapshot(5, -1, NO, 0, NO), availableModes) == nil,
          "invalid gesture result must not become a confirmed snapshot");
    CHECK(QRingGestureSnapshot(snapshot(5, 0, YES, 8, YES), availableModes) == nil,
          "invalid screen-touch result must not become a confirmed snapshot");
    CHECK(QRingGestureSnapshot(nil, availableModes) == nil, "missing readback must remain missing");
    return 0;
}

static int gestureReadback(void) {
    NSDictionary *unused = snapshot(0, 0, NO, 0, NO);
    NSDictionary *music = snapshot(1, 1, NO, 0, NO);
    NSDictionary *closed = snapshot(0, 1, NO, 0, NO);
    CHECK(unused && music && closed, "observed R8 states must pass snapshot validation");
    NSDictionary *originalBefore = [unused copy];
    NSDictionary *originalActual = [music copy];
    CHECK(QRingGestureReadbackMatches(unused, music, 1),
          "first enable must accept the firmware's observed zero-to-one initialization");
    CHECK(QRingGestureReadbackMatches(music, closed, 0),
          "restoring off must preserve the firmware's initialized strength");
    CHECK(QRingGestureReadbackMatches(closed, closed, 0),
          "an additional read of restored off must remain confirmed");
    CHECK([unused isEqual:originalBefore] && [music isEqual:originalActual],
          "readback matching must not rewrite original or returned strength");
    CHECK([unused[@"strength"] isEqual:@0] && [music[@"strength"] isEqual:@1],
          "the returned initialized strength must remain distinct from the original zero");

    for (NSNumber *target in @[@1, @2, @4, @5, @6]) {
        NSInteger mode = target.integerValue;
        CHECK(QRingGestureReadbackMatches(unused, snapshot(mode, 1, NO, 0, NO), mode),
              "first enable must require the exact requested nonzero mode");
        CHECK(!QRingGestureReadbackMatches(unused, snapshot(mode, 1, NO, 0, NO), 0),
              "an enabled read must not satisfy a request to close");
        CHECK(!QRingGestureReadbackMatches(unused, snapshot(mode, 2, NO, 0, NO), mode),
              "first enable must not permit an arbitrary new sensitivity");
    }
    for (NSNumber *strength in @[@1, @7, @10]) {
        NSDictionary *before = snapshot(0, strength.integerValue, NO, 0, NO);
        CHECK(QRingGestureReadbackMatches(before, snapshot(1, strength.integerValue, NO, 0, NO), 1),
              "an existing positive strength must be preserved exactly when enabling");
        CHECK(!QRingGestureReadbackMatches(before, snapshot(1, 0, NO, 0, NO), 1),
              "an existing sensitivity must never silently become zero");
        NSInteger changedStrength = strength.integerValue == 1 ? 2 : 1;
        CHECK(!QRingGestureReadbackMatches(before, snapshot(1, changedStrength, NO, 0, NO), 1),
              "an existing positive sensitivity must never be reinitialized");
    }
    CHECK(QRingGestureReadbackMatches(unused, snapshot(1, 0, NO, 0, NO), 1),
          "a firmware that preserves zero must still satisfy an otherwise exact readback");
    CHECK(!QRingGestureReadbackMatches(snapshot(2, 0, NO, 0, NO), music, 1),
          "the exception must not apply to a previously active zero-strength mode");
    CHECK(!QRingGestureReadbackMatches(unused, closed, 0),
          "remaining off must not initialize the sensitivity");
    CHECK(!QRingGestureReadbackMatches(music, unused, 0),
          "closing must not silently reset an initialized sensitivity to zero");
    CHECK(!QRingGestureReadbackMatches(unused, music, 2),
          "a different actual mode must never confirm the requested mode");

    NSDictionary *ordinary = snapshot(0, 0, YES, 8, NO);
    CHECK(QRingGestureReadbackMatches(ordinary, snapshot(1, 0, YES, 8, NO), 1),
          "ordinary touch must retain its reserved zero and duration");
    CHECK(!QRingGestureReadbackMatches(ordinary, snapshot(1, 1, YES, 8, NO), 1),
          "the gesture initialization exception must not apply to touch control");
    NSDictionary *screen = snapshot(0, 1, YES, 8, YES);
    CHECK(QRingGestureReadbackMatches(screen, snapshot(1, 1, YES, 8, YES), 1),
          "screen touch must preserve its positive strength and duration");
    CHECK(!QRingGestureReadbackMatches(screen, snapshot(1, 2, YES, 8, YES), 1),
          "screen-touch strength changes must remain rejected");
    CHECK(!QRingGestureReadbackMatches(ordinary, snapshot(1, 0, YES, 9, NO), 1),
          "an otherwise matching touch read must preserve duration");
    CHECK(!QRingGestureReadbackMatches(unused, snapshot(1, 1, NO, 1, NO), 1),
          "first-enable initialization must not bypass duration preservation");
    CHECK(!QRingGestureReadbackMatches(unused, snapshot(1, 1, YES, 1, NO), 1),
          "a changed control type must not satisfy readback");

    CHECK(!QRingGestureReadbackMatches(nil, music, 1), "missing original state must not be confirmed");
    CHECK(!QRingGestureReadbackMatches(unused, nil, 1), "missing readback must not be confirmed");
    CHECK(!QRingGestureReadbackMatches(@{}, music, 1), "an empty original state must not qualify for initialization");
    CHECK(!QRingGestureReadbackMatches(unused, @{}, 1), "an empty callback must not be treated as a successful read");
    CHECK(!QRingGestureReadbackMatches(unused, snapshot(1, -1, NO, 0, NO), 1),
          "the SDK error sentinel must remain a failed readback");
    for (NSNumber *invalidMode in @[@(-1), @10, @(NSIntegerMin), @(NSIntegerMax)]) {
        CHECK(!QRingGestureReadbackMatches(unused, music, invalidMode.integerValue),
              "out-of-range expected firmware modes must be rejected");
    }
    for (NSString *key in @[@"mode", @"strength", @"touch", @"duration"]) {
        NSMutableDictionary *incompleteBefore = [unused mutableCopy];
        [incompleteBefore removeObjectForKey:key];
        CHECK(!QRingGestureReadbackMatches(incompleteBefore, music, 1),
              "missing original fields must not qualify for initialization");
        NSMutableDictionary *incompleteActual = [music mutableCopy];
        [incompleteActual removeObjectForKey:key];
        CHECK(!QRingGestureReadbackMatches(unused, incompleteActual, 1),
              "missing callback fields must not qualify for initialization");
    }
    return 0;
}

static int snapshotIsolation(void) {
    NSDictionary *raw = snapshot(2, 0, YES, 8, NO);
    CHECK(raw != nil, "ordinary touch state must be available before editing");
    NSDictionary *original = [raw copy];
    NSDictionary *gesture = QRingGestureSnapshot(raw, @[@0, @1, @4]);
    CHECK([raw isEqual:original], "gesture presentation must not mutate the original camera snapshot");
    CHECK(![raw[@"enabled"] boolValue] && [gesture[@"enabled"] boolValue],
          "camera-enabled and gesture-enabled have different meanings");
    CHECK(raw[@"confirmedMode"] == nil && raw[@"rawMode"] == nil,
          "presentation-only fields must not leak into raw settings");
    CHECK([gesture[@"mode"] isEqual:original[@"mode"]] &&
          [gesture[@"strength"] isEqual:original[@"strength"]] &&
          [gesture[@"duration"] isEqual:original[@"duration"]],
          "all original write-preservation fields must survive presentation unchanged");
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        int result;
        if (strcmp(argv[1], "ordinary-touch") == 0) result = ordinaryTouch();
        else if (strcmp(argv[1], "closed-gesture") == 0) result = closedGesture();
        else if (strcmp(argv[1], "boundaries") == 0) result = boundaries();
        else if (strcmp(argv[1], "gesture-modes") == 0) result = gestureModes();
        else if (strcmp(argv[1], "gesture-readback") == 0) result = gestureReadback();
        else if (strcmp(argv[1], "snapshot-isolation") == 0) result = snapshotIsolation();
        else return 2;
        if (result == 0) printf("QRing %s: %ld assertions passed\n", argv[1], (long)checks);
        return result;
    }
}
