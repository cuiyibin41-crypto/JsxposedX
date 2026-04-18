#include "memory_tool_jni.h"

#include <stdexcept>
#include <string>
#include <utility>

#include "memory_tool_protocol.h"
#include "memory_tool_utils.h"

namespace memory_tool {

void ThrowRuntimeException(JNIEnv* env, const std::string& message) {
    jclass exception_class = env->FindClass("java/lang/RuntimeException");
    if (exception_class != nullptr) {
        env->ThrowNew(exception_class, message.c_str());
    }
}

namespace {

SearchValueType ToSearchValueType(jint raw_type) {
    switch (raw_type) {
        case 0:
            return SearchValueType::kI8;
        case 1:
            return SearchValueType::kI16;
        case 2:
            return SearchValueType::kI32;
        case 3:
            return SearchValueType::kI64;
        case 4:
            return SearchValueType::kF32;
        case 5:
            return SearchValueType::kF64;
        case 6:
            return SearchValueType::kBytes;
        default:
            throw std::runtime_error("Unsupported search value type.");
    }
}

SearchMatchMode ToSearchMatchMode(jint raw_mode) {
    if (raw_mode != 0) {
        throw std::runtime_error("Unsupported search match mode.");
    }
    return SearchMatchMode::kExact;
}

}  // namespace

jlong MemoryToolJniBridge::GetPid(JNIEnv* env, jstring package_name) {
    if (package_name == nullptr) {
        return 0;
    }

    const char* package_name_chars = env->GetStringUTFChars(package_name, nullptr);
    if (package_name_chars == nullptr) {
        return 0;
    }

    const std::string inner_command = utils::BuildGetPidCommand(package_name_chars);
    env->ReleaseStringUTFChars(package_name, package_name_chars);
    const std::string command = utils::WrapCommandWithSu(inner_command);

    std::string output;
    int exit_code = 0;
    if (!utils::ExecuteCommand(command, &output, &exit_code)) {
        return 0;
    }
    if (exit_code != 0 && exit_code != 256) {
        return 0;
    }
    return utils::ParsePid(output);
}

jstring MemoryToolJniBridge::GetMemoryRegionsJson(JNIEnv* env,
                                                  jlong pid,
                                                  jint offset,
                                                  jint limit,
                                                  jboolean readable_only,
                                                  jboolean include_anonymous,
                                                  jboolean include_file_backed) {
    const auto result = MemoryToolEngine::Instance().GetMemoryRegions(
        static_cast<int>(pid),
        offset,
        limit,
        readable_only == JNI_TRUE,
        include_anonymous == JNI_TRUE,
        include_file_backed == JNI_TRUE);
    return env->NewStringUTF(protocol::SerializeMemoryRegions(result).c_str());
}

jstring MemoryToolJniBridge::GetSearchSessionStateJson(JNIEnv* env) {
    const auto state = MemoryToolEngine::Instance().GetSearchSessionState();
    return env->NewStringUTF(protocol::SerializeSearchSessionState(state).c_str());
}

jstring MemoryToolJniBridge::GetSearchTaskStateJson(JNIEnv* env) {
    const auto state = MemoryToolEngine::Instance().GetSearchTaskState();
    return env->NewStringUTF(protocol::SerializeSearchTaskState(state).c_str());
}

jstring MemoryToolJniBridge::GetSearchResultsJson(JNIEnv* env, jint offset, jint limit) {
    const auto results = MemoryToolEngine::Instance().GetSearchResults(offset, limit);
    return env->NewStringUTF(protocol::SerializeSearchResults(results).c_str());
}

jstring MemoryToolJniBridge::GetPointerScanSessionStateJson(JNIEnv* env) {
    const auto state = MemoryToolEngine::Instance().GetPointerScanSessionState();
    return env->NewStringUTF(protocol::SerializePointerScanSessionState(state).c_str());
}

jstring MemoryToolJniBridge::GetPointerScanTaskStateJson(JNIEnv* env) {
    const auto state = MemoryToolEngine::Instance().GetPointerScanTaskState();
    return env->NewStringUTF(protocol::SerializePointerScanTaskState(state).c_str());
}

jstring MemoryToolJniBridge::GetPointerScanResultsJson(JNIEnv* env, jint offset, jint limit) {
    const auto results = MemoryToolEngine::Instance().GetPointerScanResults(offset, limit);
    return env->NewStringUTF(protocol::SerializePointerScanResults(results).c_str());
}

jstring MemoryToolJniBridge::ReadMemoryValuesJson(JNIEnv* env,
                                                  jlongArray addresses,
                                                  jintArray types,
                                                  jintArray lengths) {
    const auto requests = BuildReadRequests(env, addresses, types, lengths);
    const auto previews = MemoryToolEngine::Instance().ReadMemoryValues(requests);
    return env->NewStringUTF(protocol::SerializeMemoryValuePreviews(previews).c_str());
}

void MemoryToolJniBridge::WriteMemoryValue(JNIEnv* env,
                                           jlong address,
                                           jint type,
                                           jstring text_value,
                                           jbyteArray bytes_value,
                                           jboolean little_endian) {
    MemoryWriteRequest request;
    request.address = static_cast<uint64_t>(address);
    request.value = BuildSearchValue(env, type, text_value, bytes_value, little_endian);
    MemoryToolEngine::Instance().WriteMemoryValue(request);
}

void MemoryToolJniBridge::SetMemoryFreeze(JNIEnv* env,
                                          jlong address,
                                          jint type,
                                          jstring text_value,
                                          jbyteArray bytes_value,
                                          jboolean little_endian,
                                          jboolean enabled) {
    MemoryFreezeRequest request;
    request.address = static_cast<uint64_t>(address);
    request.value = BuildSearchValue(env, type, text_value, bytes_value, little_endian);
    request.enabled = enabled == JNI_TRUE;
    MemoryToolEngine::Instance().SetMemoryFreeze(request);
}

jstring MemoryToolJniBridge::GetFrozenMemoryValuesJson(JNIEnv* env) {
    const auto values = MemoryToolEngine::Instance().GetFrozenMemoryValues();
    return env->NewStringUTF(protocol::SerializeFrozenMemoryValues(values).c_str());
}

void MemoryToolJniBridge::FirstScan(JNIEnv* env,
                                    jlong pid,
                                    jint type,
                                    jstring text_value,
                                    jbyteArray bytes_value,
                                    jboolean little_endian,
                                    jint match_mode,
                                    jobjectArray range_section_keys,
                                    jboolean scan_all_readable_regions) {
    const SearchValue value =
        BuildSearchValue(env, type, text_value, bytes_value, little_endian);
    const std::vector<std::string> region_type_keys =
        JObjectArrayToStringVector(env, range_section_keys);
    MemoryToolEngine::Instance().FirstScan(static_cast<int>(pid),
                                           value,
                                           ToSearchMatchMode(match_mode),
                                           region_type_keys,
                                           scan_all_readable_regions == JNI_TRUE);
}

void MemoryToolJniBridge::NextScan(JNIEnv* env,
                                   jint type,
                                   jstring text_value,
                                   jbyteArray bytes_value,
                                   jboolean little_endian,
                                   jint match_mode) {
    const SearchValue value =
        BuildSearchValue(env, type, text_value, bytes_value, little_endian);
    MemoryToolEngine::Instance().NextScan(value, ToSearchMatchMode(match_mode));
}

void MemoryToolJniBridge::CancelSearch() {
    MemoryToolEngine::Instance().CancelSearch();
}

void MemoryToolJniBridge::ResetSearchSession() {
    MemoryToolEngine::Instance().ResetSearchSession();
}

void MemoryToolJniBridge::StartPointerScan(JNIEnv* env,
                                           jlong pid,
                                           jlong target_address,
                                           jint pointer_width,
                                           jlong max_offset,
                                           jint alignment,
                                           jobjectArray range_section_keys,
                                           jboolean scan_all_readable_regions) {
    const std::vector<std::string> region_type_keys =
        JObjectArrayToStringVector(env, range_section_keys);
    MemoryToolEngine::Instance().StartPointerScan(
        static_cast<int>(pid),
        static_cast<uint64_t>(target_address),
        static_cast<size_t>(pointer_width),
        static_cast<uint64_t>(max_offset),
        static_cast<size_t>(alignment),
        region_type_keys,
        scan_all_readable_regions == JNI_TRUE);
}

void MemoryToolJniBridge::CancelPointerScan() {
    MemoryToolEngine::Instance().CancelPointerScan();
}

void MemoryToolJniBridge::ResetPointerScanSession() {
    MemoryToolEngine::Instance().ResetPointerScanSession();
}

SearchValue MemoryToolJniBridge::BuildSearchValue(JNIEnv* env,
                                                  jint type,
                                                  jstring text_value,
                                                  jbyteArray bytes_value,
                                                  jboolean little_endian) {
    SearchValue value;
    value.type = ToSearchValueType(type);
    value.text_value = JStringToUtf8(env, text_value);
    value.bytes_value = JByteArrayToVector(env, bytes_value);
    value.little_endian = little_endian == JNI_TRUE;
    return value;
}

std::vector<MemoryReadRequest> MemoryToolJniBridge::BuildReadRequests(JNIEnv* env,
                                                                      jlongArray addresses,
                                                                      jintArray types,
                                                                      jintArray lengths) {
    if (addresses == nullptr || types == nullptr || lengths == nullptr) {
        return {};
    }

    const jsize address_size = env->GetArrayLength(addresses);
    const jsize type_size = env->GetArrayLength(types);
    const jsize length_size = env->GetArrayLength(lengths);
    if (address_size != type_size || address_size != length_size) {
        throw std::runtime_error("Read request arrays have mismatched lengths.");
    }

    std::vector<jlong> address_values(static_cast<size_t>(address_size));
    std::vector<jint> type_values(static_cast<size_t>(type_size));
    std::vector<jint> length_values(static_cast<size_t>(length_size));
    env->GetLongArrayRegion(addresses, 0, address_size, address_values.data());
    env->GetIntArrayRegion(types, 0, type_size, type_values.data());
    env->GetIntArrayRegion(lengths, 0, length_size, length_values.data());

    std::vector<MemoryReadRequest> requests;
    requests.reserve(static_cast<size_t>(address_size));
    for (jsize index = 0; index < address_size; ++index) {
        MemoryReadRequest request;
        request.address = static_cast<uint64_t>(address_values[static_cast<size_t>(index)]);
        request.type = ToSearchValueType(type_values[static_cast<size_t>(index)]);
        request.length = static_cast<size_t>(length_values[static_cast<size_t>(index)]);
        requests.push_back(std::move(request));
    }
    return requests;
}

std::string MemoryToolJniBridge::JStringToUtf8(JNIEnv* env, jstring value) {
    if (value == nullptr) {
        return {};
    }

    const char* raw = env->GetStringUTFChars(value, nullptr);
    if (raw == nullptr) {
        return {};
    }
    std::string result(raw);
    env->ReleaseStringUTFChars(value, raw);
    return result;
}

std::vector<uint8_t> MemoryToolJniBridge::JByteArrayToVector(JNIEnv* env, jbyteArray value) {
    if (value == nullptr) {
        return {};
    }

    const jsize length = env->GetArrayLength(value);
    std::vector<uint8_t> bytes(static_cast<size_t>(length));
    env->GetByteArrayRegion(value, 0, length, reinterpret_cast<jbyte*>(bytes.data()));
    return bytes;
}

std::vector<std::string> MemoryToolJniBridge::JObjectArrayToStringVector(JNIEnv* env,
                                                                         jobjectArray value) {
    if (value == nullptr) {
        return {};
    }

    const jsize length = env->GetArrayLength(value);
    std::vector<std::string> strings;
    strings.reserve(static_cast<size_t>(length));
    for (jsize index = 0; index < length; ++index) {
        auto* item = static_cast<jstring>(env->GetObjectArrayElement(value, index));
        strings.push_back(JStringToUtf8(env, item));
        env->DeleteLocalRef(item);
    }
    return strings;
}

}  // namespace memory_tool

extern "C" JNIEXPORT jlong JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolJni_getPid(
        JNIEnv* env,
        jobject /* thiz */,
        jstring package_name) {
    return memory_tool::MemoryToolJniBridge::GetPid(env, package_name);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getMemoryRegionsJson(
        JNIEnv* env,
        jobject /* thiz */,
        jlong pid,
        jint offset,
        jint limit,
        jboolean readable_only,
        jboolean include_anonymous,
        jboolean include_file_backed) {
    try {
        return memory_tool::MemoryToolJniBridge::GetMemoryRegionsJson(
            env,
            pid,
            offset,
            limit,
            readable_only,
            include_anonymous,
            include_file_backed);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getSearchSessionStateJson(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        return memory_tool::MemoryToolJniBridge::GetSearchSessionStateJson(env);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getSearchTaskStateJson(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        return memory_tool::MemoryToolJniBridge::GetSearchTaskStateJson(env);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getSearchResultsJson(
        JNIEnv* env,
        jobject /* thiz */,
        jint offset,
        jint limit) {
    try {
        return memory_tool::MemoryToolJniBridge::GetSearchResultsJson(env, offset, limit);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getPointerScanSessionStateJson(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        return memory_tool::MemoryToolJniBridge::GetPointerScanSessionStateJson(env);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getPointerScanTaskStateJson(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        return memory_tool::MemoryToolJniBridge::GetPointerScanTaskStateJson(env);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getPointerScanResultsJson(
        JNIEnv* env,
        jobject /* thiz */,
        jint offset,
        jint limit) {
    try {
        return memory_tool::MemoryToolJniBridge::GetPointerScanResultsJson(env, offset, limit);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_readMemoryValuesJson(
        JNIEnv* env,
        jobject /* thiz */,
        jlongArray addresses,
        jintArray types,
        jintArray lengths) {
    try {
        return memory_tool::MemoryToolJniBridge::ReadMemoryValuesJson(env, addresses, types, lengths);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_writeMemoryValue(
        JNIEnv* env,
        jobject /* thiz */,
        jlong address,
        jint type,
        jstring text_value,
        jbyteArray bytes_value,
        jboolean little_endian) {
    try {
        memory_tool::MemoryToolJniBridge::WriteMemoryValue(
            env,
            address,
            type,
            text_value,
            bytes_value,
            little_endian);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_setMemoryFreeze(
        JNIEnv* env,
        jobject /* thiz */,
        jlong address,
        jint type,
        jstring text_value,
        jbyteArray bytes_value,
        jboolean little_endian,
        jboolean enabled) {
    try {
        memory_tool::MemoryToolJniBridge::SetMemoryFreeze(
            env,
            address,
            type,
            text_value,
            bytes_value,
            little_endian,
            enabled);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_getFrozenMemoryValuesJson(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        return memory_tool::MemoryToolJniBridge::GetFrozenMemoryValuesJson(env);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
        return nullptr;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_firstScan(
        JNIEnv* env,
        jobject /* thiz */,
        jlong pid,
        jint type,
        jstring text_value,
        jbyteArray bytes_value,
        jboolean little_endian,
        jint match_mode,
        jobjectArray range_section_keys,
        jboolean scan_all_readable_regions) {
    try {
        memory_tool::MemoryToolJniBridge::FirstScan(
            env,
            pid,
            type,
            text_value,
            bytes_value,
            little_endian,
            match_mode,
            range_section_keys,
            scan_all_readable_regions);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_nextScan(
        JNIEnv* env,
        jobject /* thiz */,
        jint type,
        jstring text_value,
        jbyteArray bytes_value,
        jboolean little_endian,
        jint match_mode) {
    try {
        memory_tool::MemoryToolJniBridge::NextScan(
            env,
            type,
            text_value,
            bytes_value,
            little_endian,
            match_mode);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_cancelSearch(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        memory_tool::MemoryToolJniBridge::CancelSearch();
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_resetSearchSession(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        memory_tool::MemoryToolJniBridge::ResetSearchSession();
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_startPointerScan(
        JNIEnv* env,
        jobject /* thiz */,
        jlong pid,
        jlong target_address,
        jint pointer_width,
        jlong max_offset,
        jint alignment,
        jobjectArray range_section_keys,
        jboolean scan_all_readable_regions) {
    try {
        memory_tool::MemoryToolJniBridge::StartPointerScan(
            env,
            pid,
            target_address,
            pointer_width,
            max_offset,
            alignment,
            range_section_keys,
            scan_all_readable_regions);
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_cancelPointerScan(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        memory_tool::MemoryToolJniBridge::CancelPointerScan();
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolHelperNativeBridge_resetPointerScanSession(
        JNIEnv* env,
        jobject /* thiz */) {
    try {
        memory_tool::MemoryToolJniBridge::ResetPointerScanSession();
    } catch (const std::exception& exception) {
        memory_tool::ThrowRuntimeException(env, exception.what());
    }
}
