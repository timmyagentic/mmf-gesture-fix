#import "HIDBridge.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <dlfcn.h>
#include <libproc.h>
#include <math.h>
#include <signal.h>
#include <string.h>

// This bridge is confined to the official 3.1.0 native HID shape. There is no
// legacy CGEvent-field conversion or dependency on the former MMF27 project.
@interface MGHID : NSObject
- (instancetype)initWithType:(uint32_t)type timestamp:(uint64_t)timestamp senderID:(uint64_t)senderID;
- (NSInteger)integerValueForField:(uint32_t)field;
- (double)doubleValueForField:(uint32_t)field;
- (void)setIntegerValue:(NSInteger)value forField:(uint32_t)field;
- (void)setDoubleValue:(double)value forField:(uint32_t)field;
- (void)appendEvent:(MGHID *)event;
@property uint32_t options;
@property(readonly) uint32_t type;
@property(readonly) uint64_t timestamp;
@property(readonly) NSArray<MGHID *> *children;
@end
static CFTypeRef (*copyHID)(CGEventRef);
static void (*setHID)(CGEventRef, CFTypeRef);
static Class HIDClass;
static const int64_t marker = 0x4d474658313030;
static const uint32_t motionField = (23 << 16) | 1;
static const uint32_t progressField = (23 << 16) | 2;
static const uint32_t flavorField = (23 << 16) | 5;
static const uint32_t vxField = 9 << 16, vyField = (9 << 16) | 1, vzField = (9 << 16) | 2;

int32_t MGLoadHID(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW | RTLD_LOCAL);
        if (handle) {
            copyHID = dlsym(handle, "SLEventCopyIOHIDEvent");
            setHID = dlsym(handle, "SLEventSetIOHIDEvent");
            HIDClass = NSClassFromString(@"HIDEvent");
        }
    });
    return copyHID && setHID && HIDClass;
}
static MGHID *payload(CGEventRef event) {
    return copyHID ? CFBridgingRelease(copyHID(event)) : nil;
}
int32_t MGReadFrame(CGEventRef event, MGFrame *frame) {
    if (!event || !frame || CGEventGetType(event) != (CGEventType)30 || !MGLoadHID()) return 0;
    MGHID *hid = payload(event);
    if (hid.type != 23) return 0;
    memset(frame, 0, sizeof(*frame));
    frame->pid = (int32_t)CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
    frame->marked = CGEventGetIntegerValueField(event, kCGEventSourceUserData) == marker;
    frame->motion = (int32_t)[hid integerValueForField:motionField];
    frame->flavor = (int32_t)[hid integerValueForField:flavorField];
    frame->phase = (hid.options >> 24) & 0xff;
    frame->timestamp = CGEventGetTimestamp(event);
    frame->progress = [hid doubleValueForField:progressField];
    frame->terminal = frame->phase == 4 || frame->phase == 8;
    if (frame->terminal) {
        MGHID *velocity = hid.children.count == 1 ? hid.children.firstObject : nil;
        if (velocity.type != 9) return 0;
        frame->vx = [velocity doubleValueForField:vxField];
        frame->vy = [velocity doubleValueForField:vyField];
        frame->vz = [velocity doubleValueForField:vzField];
    } else if (hid.children.count != 0) return 0;
    return isfinite(frame->progress) && isfinite(frame->vx) && isfinite(frame->vy) && isfinite(frame->vz);
}
CGEventRef MGCopyWithVelocity(CGEventRef event, double vx, double vy) {
    MGFrame frame;
    if (!MGReadFrame(event, &frame) || !frame.terminal || frame.marked || !isfinite(vx) || !isfinite(vy)) return NULL;
    MGHID *original = payload(event), *oldV = original.children.firstObject;
    MGHID *hid = [[HIDClass alloc] initWithType:23 timestamp:original.timestamp senderID:0];
    MGHID *velocity = [[HIDClass alloc] initWithType:9 timestamp:oldV.timestamp senderID:0];
    if (!hid || !velocity) return NULL;
    hid.options = original.options; velocity.options = oldV.options;
    [hid setIntegerValue:frame.motion forField:motionField];
    [hid setIntegerValue:frame.flavor forField:flavorField];
    [hid setDoubleValue:frame.progress forField:progressField];
    [velocity setDoubleValue:vx forField:vxField];
    [velocity setDoubleValue:vy forField:vyField];
    [velocity setDoubleValue:frame.vz forField:vzField];
    [hid appendEvent:velocity];
    CGEventRef result = CGEventCreateCopy(event);
    if (result) {
        setHID(result, (__bridge CFTypeRef)hid);
        CGEventSetIntegerValueField(result, kCGEventSourceUserData, marker);
    }
    return result;
}
int32_t MGVerifiedHelperBuild(int32_t pid) {
    SecCodeRef code = NULL; SecRequirementRef requirement = NULL; CFDictionaryRef info = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kSecGuestAttributePid:@(pid)};
    OSStatus status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes, kSecCSDefaultFlags, &code);
    CFStringRef rule = CFSTR("anchor apple generic and identifier \"com.nuebling.mac-mouse-fix.helper\" and certificate leaf[subject.OU] = \"LM5Z78756B\"");
    if (status == errSecSuccess) status = SecRequirementCreateWithString(rule, kSecCSDefaultFlags, &requirement);
    if (status == errSecSuccess) status = SecCodeCheckValidity(code, kSecCSDefaultFlags, requirement);
    if (status == errSecSuccess) status = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info);
    NSDictionary *plist = info ? ((__bridge NSDictionary *)info)[(__bridge NSString *)kSecCodeInfoPList] : nil;
    int32_t build = status == errSecSuccess ? [plist[@"CFBundleVersion"] intValue] : 0;
    if (info) CFRelease(info);
    if (requirement) CFRelease(requirement);
    if (code) CFRelease(code);
    return build;
}
int32_t MGProcessMatches(int32_t pid, const char *path) {
    char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
    return pid > 0 && path && kill(pid, 0) == 0 && proc_pidpath(pid, executable, sizeof(executable)) > 0
        && strcmp(path, executable) == 0;
}
int32_t MGBridgeSelfTest(void) {
    if (!MGLoadHID()) return 0;
    MGHID *hid = [[HIDClass alloc] initWithType:23 timestamp:0 senderID:0];
    MGHID *velocity = [[HIDClass alloc] initWithType:9 timestamp:0 senderID:0];
    hid.options = 4 << 24;
    [hid setIntegerValue:1 forField:motionField]; [hid setIntegerValue:3 forField:flavorField];
    [hid setDoubleValue:-0.5 forField:progressField];
    [velocity setDoubleValue:12 forField:vxField]; [velocity setDoubleValue:12 forField:vyField];
    [hid appendEvent:velocity];
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, (CGEventType)30); CGEventSetTimestamp(event, 123456);
    CGEventSetFlags(event, kCGEventFlagMaskAlternate); CGEventSetLocation(event, CGPointMake(34, 56));
    setHID(event, (__bridge CFTypeRef)hid);
    MGFrame before, after, unchanged;
    BOOL valid = MGReadFrame(event, &before);
    CGEventRef replacement = MGCopyWithVelocity(event, -12, -12);
    valid = valid && replacement && MGReadFrame(replacement, &after) && MGReadFrame(event, &unchanged)
        && before.vx == 12 && unchanged.vx == 12 && after.vx == -12 && after.vy == -12
        && after.progress == before.progress && after.timestamp == before.timestamp && after.marked
        && CGEventGetFlags(replacement) == kCGEventFlagMaskAlternate
        && CGPointEqualToPoint(CGEventGetLocation(replacement), CGPointMake(34, 56))
        && MGCopyWithVelocity(replacement, 12, 12) == NULL;
    if (replacement) CFRelease(replacement);
    CFRelease(event);
    return valid;
}
