#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
typedef struct {
    int32_t pid, motion, phase, flavor, terminal, marked;
    uint64_t timestamp;
    double progress, vx, vy, vz;
} MGFrame;
int32_t MGLoadHID(void);
int32_t MGReadFrame(CGEventRef _Nonnull event, MGFrame * _Nonnull frame);
CGEventRef _Nullable MGCopyWithVelocity(CGEventRef _Nonnull event, double vx, double vy) CF_RETURNS_RETAINED;
int32_t MGVerifiedHelperBuild(int32_t pid);
int32_t MGProcessMatches(int32_t pid, const char * _Nullable path);
int32_t MGBridgeSelfTest(void);
