#include <jni.h>
#include <android/log.h>

namespace {
constexpr char kTag[] = "ShadowKeys-NoOp";
}

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    if (vm == nullptr) {
        return JNI_ERR;
    }
    __android_log_print(ANDROID_LOG_INFO, kTag,
        "No-op native test module loaded; no game memory or files were changed.");
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_damian_shadowkeys_NativeProbe_status(JNIEnv* env, jclass) {
    return env->NewStringUTF(
        "ShadowKeys native test module compiled. This build does not hook or modify GTA.");
}
