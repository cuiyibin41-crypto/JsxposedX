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

    static jstring ReadMemoryValuesJson(JNIEnv* env,
                                        jlongArray addresses,
                                        jintArray types,
                                        jintArray lengths);

    static void FirstScan(JNIEnv* env,
                          jlong pid,
                          jint type,
                          jstring text_value,
                          jbyteArray bytes_value,
                          jboolean little_endian,
                          jint match_mode,
                          jboolean scan_all_readable_regions);

    static void NextScan(JNIEnv* env,
                         jint type,
                         jstring text_value,
                         jbyteArray bytes_value,
                         jboolean little_endian,
                         jint match_mode);

    static void CancelSearch();

    static void ResetSearchSession();

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

    static std::string JStringToUtf8(JNIEnv* env, jstring value);

    static std::vector<uint8_t> JByteArrayToVector(JNIEnv* env, jbyteArray value);
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_JNI_H
