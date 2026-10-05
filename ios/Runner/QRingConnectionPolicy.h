#import <Foundation/Foundation.h>

// Release a missing cancellation callback only with actual radio-state proof,
// while the original operation and exact peripheral still own the channel.
static inline BOOL QRingCanFinishCancellation(BOOL sameGeneration,
                                              BOOL samePeripheral,
                                              BOOL cancelling,
                                              BOOL radioDisconnected) {
    return sameGeneration && samePeripheral && cancelling && radioDisconnected;
}
