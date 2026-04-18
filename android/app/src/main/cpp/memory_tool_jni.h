#ifndef JSXPOSEDX_MEMORY_TOOL_JNI_H
#define JSXPOSEDX_MEMORY_TOOL_JNI_H

#include <jni.h>

#include <cstdint>
#include <string>
#include <vector>

#include "memory_tool_engine.h"

namespace memory_tool {

class MemoryToolJniBridge {
public:
    static jlong GetPid(JNIEnv* env, jstring package_name);

    static jstring GetMemoryRegionsJson(JNIEnv* env,
                                        jlong pid,
                                        jint offset,
                                        jint limit,
                                        jboolean readable_only,
                                        jboolean include_anonymous,
                                        jboolean include_file_backed);

    static jstring GetSearchSessionStateJson(JNIEnv* env);

    static jstring GetSearchTaskStateJson(JNIEnv* env);

    static jstring GetSearchResultsJson(JNIEnv* env, jint offset, jint limit);

    static jstring GetPointerScanSessionStateJson(JNIEnv* env);

    static jstring GetPointerScanTaskStateJson(JNIEnv* env);

    static jstring GetPointerScanResultsJson(JNIEnv* env, jint offset, jint limit);

    static jstring ReadMemoryValuesJson(JNIEnv* env,
                                        jlongArray addresses,
                                        jintArray types,
                                        jintArray lengths);

    static void WriteMemoryValue(JNIEnv* env,
                                 jlong address,
                                 jint type,
                                 jstring text_value,
                                 jbyteArray bytes_value,
                                 jboolean little_endian);

    static void SetMemoryFreeze(JNIEnv* env,
                                jlong address,
                                jint type,
                                jstring text_value,
                                jbyteArray bytes_value,
                                jboolean little_endian,
                                jboolean enabled);

    static jstring GetFrozenMemoryValuesJson(JNIEnv* env);

    static void FirstScan(JNIEnv* env,
                          jlong pid,
                          jint type,
                          jstring text_value,
                          jbyteArray bytes_value,
                          jboolean little_endian,
                          jint match_mode,
                          jobjectArray range_section_keys,
                          jboolean scan_all_readable_regions);

    static void NextScan(JNIEnv* env,
                         jint type,
                         jstring text_value,
                         jbyteArray bytes_value,
                         jboolean little_endian,
                         jint match_mode);

    static void CancelSearch();

    static void ResetSearchSession();

    static void StartPointerScan(JNIEnv* env,
                                 jlong pid,
                                 jlong target_address,
                                 jint pointer_width,
                                 jlong max_offset,
                                 jint alignment,
                                 jobjectArray range_section_keys,
                                 jboolean scan_all_readable_regions);

    static void CancelPointerScan();

    static void ResetPointerScanSession();

private:
    static SearchValue BuildSearchValue(JNIEnv* env,
                                        jint type,
                                        jstring text_value,
                                        jbyteArray bytes_value,
                                        jboolean little_endian);

    static std::vector<MemoryReadRequest> BuildReadRequests(JNIEnv* env,
                                                            jlongArray addresses,
                                                            jintArray types,
                                                            jintArray lengths);

    static std::vector<std::string> JObjectArrayToStringVector(JNIEnv* env, jobjectArray value);

    static std::string JStringToUtf8(JNIEnv* env, jstring value);

    static std::vector<uint8_t> JByteArrayToVector(JNIEnv* env, jbyteArray value);
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_JNI_H
