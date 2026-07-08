#import "AudiotagsPlugin.h"
#if __has_include(<audiotags/audiotags-Swift.h>)
#import <audiotags/audiotags-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "audiotags-Swift.h"
#endif

typedef int64_t DartPort;
typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);

int32_t frb_get_rust_content_hash(void);
intptr_t frb_init_frb_dart_api_dl(void *obj);
void store_dart_post_cobject(DartPostCObjectFnType ptr);

static int64_t dummy_method_to_enforce_bundling(void) {
  int64_t dummy_var = 0;
  dummy_var ^= ((int64_t) (void*) frb_get_rust_content_hash);
  dummy_var ^= ((int64_t) (void*) frb_init_frb_dart_api_dl);
  dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
  return dummy_var;
}

@implementation AudiotagsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  dummy_method_to_enforce_bundling();
  [SwiftAudiotagsPlugin registerWithRegistrar:registrar];
}
@end
