#include "memory_tool_instruction.h"

#include <capstone/capstone.h>
#include <keystone/keystone.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <elf.h>
#include <fcntl.h>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

#include "memory_tool_reader.h"
#include "memory_tool_utils.h"

namespace memory_tool {

namespace {

struct InstructionDecodeConfig {
    const char* architecture = "unknown";
    size_t read_size = 0;
    cs_arch arch = CS_ARCH_ALL;
    cs_mode primary_mode = CS_MODE_LITTLE_ENDIAN;
    cs_mode secondary_mode = CS_MODE_LITTLE_ENDIAN;
    bool has_secondary_mode = false;
    uint64_t read_address = 0;
    uint64_t instruction_address = 0;
};

bool ReadProcessElfHeader(int pid, std::array<uint8_t, 32>* header) {
    if (header == nullptr || pid <= 0) {
        return false;
    }

    const std::string executable_path = "/proc/" + std::to_string(pid) + "/exe";
    const int fd = open(executable_path.c_str(), O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        return false;
    }

    ssize_t total_read = 0;
    while (total_read < static_cast<ssize_t>(header->size())) {
        const ssize_t current_read = read(
            fd,
            header->data() + total_read,
            header->size() - static_cast<size_t>(total_read));
        if (current_read <= 0) {
            break;
        }
        total_read += current_read;
    }
    close(fd);

    if (total_read < 20) {
        return false;
    }
    return std::memcmp(header->data(), ELFMAG, SELFMAG) == 0;
}

bool ResolveInstructionDecodeConfig(int pid,
                                    uint64_t address,
                                    InstructionDecodeConfig* config) {
    if (config == nullptr) {
        return false;
    }

    config->read_address = address;
    config->instruction_address = address;

    std::array<uint8_t, 32> header{};
    if (ReadProcessElfHeader(pid, &header)) {
        const uint8_t elf_class = header[EI_CLASS];
        const uint16_t machine = static_cast<uint16_t>(header[18]) |
                                 (static_cast<uint16_t>(header[19]) << 8U);
        if (machine == EM_AARCH64 || elf_class == ELFCLASS64) {
            config->architecture = "aarch64";
            config->read_size = 4;
            config->arch = CS_ARCH_ARM64;
            config->primary_mode = CS_MODE_LITTLE_ENDIAN;
            return true;
        }
        if (machine == EM_ARM || elf_class == ELFCLASS32) {
            config->architecture = "arm";
            config->read_size = 4;
            config->arch = CS_ARCH_ARM;
            if ((address & 1ULL) != 0) {
                config->read_address = address - 1ULL;
                config->instruction_address = address - 1ULL;
                config->primary_mode = static_cast<cs_mode>(
                    CS_MODE_THUMB | CS_MODE_LITTLE_ENDIAN);
                config->secondary_mode = static_cast<cs_mode>(
                    CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN);
                config->has_secondary_mode = true;
            } else {
                config->primary_mode = static_cast<cs_mode>(
                    CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN);
                config->secondary_mode = static_cast<cs_mode>(
                    CS_MODE_THUMB | CS_MODE_LITTLE_ENDIAN);
                config->has_secondary_mode = true;
            }
            return true;
        }
    }

#if defined(__aarch64__)
    config->architecture = "aarch64";
    config->read_size = 4;
    config->arch = CS_ARCH_ARM64;
    config->primary_mode = CS_MODE_LITTLE_ENDIAN;
    return true;
#elif defined(__arm__)
    config->architecture = "arm";
    config->read_size = 4;
    config->arch = CS_ARCH_ARM;
    config->primary_mode = static_cast<cs_mode>(CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN);
    config->secondary_mode = static_cast<cs_mode>(CS_MODE_THUMB | CS_MODE_LITTLE_ENDIAN);
    config->has_secondary_mode = true;
    return true;
#else
    return false;
#endif
}

std::string FormatHexFallback(const std::vector<uint8_t>& bytes) {
    const std::string encoded = utils::HexEncode(bytes);
    if (encoded.empty()) {
        return {};
    }
    return encoded;
}

bool TryDisassembleWithMode(const InstructionDecodeConfig& config,
                            const std::vector<uint8_t>& raw_bytes,
                            cs_mode mode,
                            MemoryInstructionInfo* info) {
    if (info == nullptr) {
        return false;
    }

    csh handle = 0;
    if (cs_open(config.arch, mode, &handle) != CS_ERR_OK) {
        return false;
    }

    cs_option(handle, CS_OPT_DETAIL, CS_OPT_OFF);
    cs_insn* instruction = nullptr;
    const size_t count = cs_disasm(
        handle,
        raw_bytes.data(),
        raw_bytes.size(),
        config.instruction_address,
        1,
        &instruction);
    if (count > 0 && instruction != nullptr) {
        info->is_thumb = (mode & CS_MODE_THUMB) == CS_MODE_THUMB;
        info->size = instruction[0].size;
        info->raw_bytes.assign(raw_bytes.begin(), raw_bytes.begin() + info->size);
        info->text = instruction[0].mnemonic;
        if (instruction[0].op_str[0] != '\0') {
            info->text += ' ';
            info->text += instruction[0].op_str;
        }
        info->is_valid = true;
    }

    if (instruction != nullptr) {
        cs_free(instruction, count);
    }
    cs_close(&handle);
    return info->is_valid;
}

std::vector<int> ReadProcessThreadIds(int pid) {
    std::vector<int> tids;
    if (pid <= 0) {
        return tids;
    }

    const std::string task_directory = "/proc/" + std::to_string(pid) + "/task";
    DIR* directory = opendir(task_directory.c_str());
    if (directory == nullptr) {
        return tids;
    }

    while (dirent* entry = readdir(directory)) {
        if (entry->d_name[0] == '.') {
            continue;
        }
        const int tid = std::atoi(entry->d_name);
        if (tid > 0) {
            tids.push_back(tid);
        }
    }

    closedir(directory);
    std::sort(tids.begin(), tids.end());
    return tids;
}

bool AttachThreadForPatch(int tid, std::string* error) {
    if (ptrace(PTRACE_ATTACH, tid, nullptr, nullptr) != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace attach failed: ") + std::strerror(errno);
        }
        return false;
    }

    int status = 0;
    if (waitpid(tid, &status, __WALL) < 0) {
        if (error != nullptr) {
            *error = std::string("waitpid failed: ") + std::strerror(errno);
        }
        ptrace(PTRACE_DETACH, tid, nullptr, nullptr);
        return false;
    }

    if (!WIFSTOPPED(status)) {
        if (error != nullptr) {
            *error = "Attached thread did not stop.";
        }
        ptrace(PTRACE_DETACH, tid, nullptr, nullptr);
        return false;
    }

    return true;
}

void DetachThreadsForPatch(const std::vector<int>& tids) {
    for (auto iterator = tids.rbegin(); iterator != tids.rend(); ++iterator) {
        ptrace(PTRACE_DETACH, *iterator, nullptr, nullptr);
    }
}

bool ReadTraceWord(int tid, uint64_t address, long* value, std::string* error) {
    if (value == nullptr) {
        return false;
    }

    errno = 0;
    const long result = ptrace(
        PTRACE_PEEKTEXT,
        tid,
        reinterpret_cast<void*>(static_cast<uintptr_t>(address)),
        nullptr);
    if (result == -1L && errno != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace peek failed: ") + std::strerror(errno);
        }
        return false;
    }

    *value = result;
    return true;
}

bool WriteTraceWord(int tid, uint64_t address, long value, std::string* error) {
    if (ptrace(PTRACE_POKETEXT,
               tid,
               reinterpret_cast<void*>(static_cast<uintptr_t>(address)),
               reinterpret_cast<void*>(static_cast<intptr_t>(value))) != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace poke failed: ") + std::strerror(errno);
        }
        return false;
    }
    return true;
}

bool WriteInstructionBytesWithPtrace(int pid,
                                     uint64_t address,
                                     const std::vector<uint8_t>& bytes,
                                     std::string* error) {
    if (pid <= 0 || address == 0 || bytes.empty()) {
        return false;
    }

    const std::vector<int> tids = ReadProcessThreadIds(pid);
    if (tids.empty()) {
        if (error != nullptr) {
            *error = "No target threads found for instruction patch.";
        }
        return false;
    }

    std::vector<int> attached_tids;
    attached_tids.reserve(tids.size());
    for (int tid : tids) {
        if (!AttachThreadForPatch(tid, error)) {
            DetachThreadsForPatch(attached_tids);
            return false;
        }
        attached_tids.push_back(tid);
    }

    const int trace_tid = attached_tids.front();
    const uint64_t word_size = static_cast<uint64_t>(sizeof(long));
    const uint64_t aligned_start = address & ~(word_size - 1U);
    const uint64_t aligned_end =
        (address + static_cast<uint64_t>(bytes.size()) + word_size - 1U) &
        ~(word_size - 1U);

    bool success = true;
    for (uint64_t current = aligned_start; current < aligned_end; current += word_size) {
        long word = 0;
        if (!ReadTraceWord(trace_tid, current, &word, error)) {
            success = false;
            break;
        }

        auto* word_bytes = reinterpret_cast<uint8_t*>(&word);
        for (uint64_t index = 0; index < word_size; ++index) {
            const uint64_t target = current + index;
            if (target < address ||
                target >= address + static_cast<uint64_t>(bytes.size())) {
                continue;
            }
            word_bytes[index] = bytes[static_cast<size_t>(target - address)];
        }

        if (!WriteTraceWord(trace_tid, current, word, error)) {
            success = false;
            break;
        }
    }

    DetachThreadsForPatch(attached_tids);
    return success;
}

std::vector<std::string> TokenizeInstructionText(const std::string& value) {
    std::string normalized;
    normalized.reserve(value.size());
    for (char ch : value) {
        if (ch == ',' || std::isspace(static_cast<unsigned char>(ch))) {
            normalized.push_back(' ');
            continue;
        }
        normalized.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(ch))));
    }

    std::istringstream stream(normalized);
    std::vector<std::string> tokens;
    std::string token;
    while (stream >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

uint64_t NormalizeAssemblyAddress(const MemoryInstructionInfo& current, uint64_t address) {
    if (current.architecture == "arm" && current.is_thumb && (address & 1ULL) != 0) {
        return address - 1ULL;
    }
    return address;
}

std::string BuildInstructionSizeError(const std::string& architecture,
                                      size_t expected_size,
                                      size_t actual_size) {
    return "Assembled " + architecture + " instruction size is " +
           std::to_string(actual_size) + " bytes, expected " +
           std::to_string(expected_size) + ".";
}

bool TryAssembleWithKeystone(ks_arch arch,
                             int mode,
                             uint64_t address,
                             const std::string& input_text,
                             std::vector<uint8_t>* bytes,
                             std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    ks_engine* engine = nullptr;
    const ks_err open_error = ks_open(arch, mode, &engine);
    if (open_error != KS_ERR_OK) {
        if (error != nullptr) {
            *error = std::string("Failed to initialize assembler: ") +
                     ks_strerror(open_error);
        }
        return false;
    }

    unsigned char* encoding = nullptr;
    size_t encoding_size = 0;
    size_t statement_count = 0;
    const int assemble_result = ks_asm(engine,
                                       input_text.c_str(),
                                       address,
                                       &encoding,
                                       &encoding_size,
                                       &statement_count);
    if (assemble_result != 0) {
        if (error != nullptr) {
            *error = ks_strerror(ks_errno(engine));
        }
        if (encoding != nullptr) {
            ks_free(encoding);
        }
        ks_close(engine);
        return false;
    }

    if (statement_count != 1) {
        if (error != nullptr) {
            *error = "Only a single instruction is supported.";
        }
        if (encoding != nullptr) {
            ks_free(encoding);
        }
        ks_close(engine);
        return false;
    }

    bytes->assign(encoding, encoding + encoding_size);
    ks_free(encoding);
    ks_close(engine);

    if (bytes->empty()) {
        if (error != nullptr) {
            *error = "Assembler returned no bytes.";
        }
        return false;
    }
    return true;
}

std::string NormalizeArmAssemblyInput(const std::string& input_text) {
    const std::vector<std::string> tokens = TokenizeInstructionText(input_text);
    if (tokens.empty()) {
        return input_text;
    }

    if (tokens[0] == "ret") {
        if (tokens.size() == 1) {
            return "bx lr";
        }
        if (tokens.size() == 2) {
            return "bx " + tokens[1];
        }
    }

    return input_text;
}

bool ParseSignedIntegerToken(const std::string& raw_token, int64_t* value) {
    if (value == nullptr) {
        return false;
    }

    std::string token = raw_token;
    if (!token.empty() && token.front() == '#') {
        token.erase(token.begin());
    }
    if (token.empty()) {
        return false;
    }
    if (token == ".") {
        *value = 0;
        return true;
    }

    bool negative = false;
    if (token.front() == '+' || token.front() == '-') {
        negative = token.front() == '-';
        token.erase(token.begin());
    }
    if (token.empty()) {
        return false;
    }

    int base = 10;
    if (token.size() > 2 && token[0] == '0' && (token[1] == 'x' || token[1] == 'X')) {
        base = 16;
        token = token.substr(2);
    }
    if (token.empty()) {
        return false;
    }

    try {
        const uint64_t parsed = std::stoull(token, nullptr, base);
        if (negative) {
            if (parsed > static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1ULL) {
                return false;
            }
            *value = parsed == static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1ULL
                         ? std::numeric_limits<int64_t>::min()
                         : -static_cast<int64_t>(parsed);
            return true;
        }
        if (parsed > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
            return false;
        }
        *value = static_cast<int64_t>(parsed);
        return true;
    } catch (...) {
        return false;
    }
}

bool ParseArm64Register(const std::string& token, int* reg) {
    if (reg == nullptr) {
        return false;
    }
    if (token == "lr") {
        *reg = 30;
        return true;
    }
    if (token.size() < 2 || token.front() != 'x') {
        return false;
    }

    try {
        const int parsed = std::stoi(token.substr(1));
        if (parsed < 0 || parsed > 30) {
            return false;
        }
        *reg = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

bool ParseArmRegister(const std::string& token, int* reg) {
    if (reg == nullptr) {
        return false;
    }
    if (token == "sp") {
        *reg = 13;
        return true;
    }
    if (token == "lr") {
        *reg = 14;
        return true;
    }
    if (token == "pc") {
        *reg = 15;
        return true;
    }
    if (token.size() < 2 || token.front() != 'r') {
        return false;
    }

    try {
        const int parsed = std::stoi(token.substr(1));
        if (parsed < 0 || parsed > 15) {
            return false;
        }
        *reg = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

std::vector<uint8_t> EncodeArm64Word(uint32_t instruction) {
    return std::vector<uint8_t>{
        static_cast<uint8_t>(instruction & 0xFFU),
        static_cast<uint8_t>((instruction >> 8U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 16U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 24U) & 0xFFU),
    };
}

std::vector<uint8_t> EncodeArmWord(uint32_t instruction) {
    return std::vector<uint8_t>{
        static_cast<uint8_t>(instruction & 0xFFU),
        static_cast<uint8_t>((instruction >> 8U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 16U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 24U) & 0xFFU),
    };
}

std::vector<uint8_t> EncodeThumbHalfWord(uint16_t instruction) {
    return std::vector<uint8_t>{
        static_cast<uint8_t>(instruction & 0xFFU),
        static_cast<uint8_t>((instruction >> 8U) & 0xFFU),
    };
}

bool TryParseHexBytes(const std::string& input_text, std::vector<uint8_t>* bytes) {
    if (bytes == nullptr) {
        return false;
    }

    std::string trimmed = utils::Trim(input_text);
    if (trimmed.empty()) {
        return false;
    }

    auto strip_0x = [](const std::string& token) {
        if (token.size() > 2 && token[0] == '0' && (token[1] == 'x' || token[1] == 'X')) {
            return token.substr(2);
        }
        return token;
    };

    if (trimmed.find_first_of(" ,\t\r\n") == std::string::npos) {
        const std::string compact = strip_0x(trimmed);
        return utils::HexDecode(compact, bytes);
    }

    std::string normalized = trimmed;
    std::replace(normalized.begin(), normalized.end(), ',', ' ');
    std::istringstream stream(normalized);
    std::vector<uint8_t> parsed_bytes;
    std::string token;
    while (stream >> token) {
        const std::string hex = strip_0x(token);
        if (hex.empty() || hex.size() > 2) {
            return false;
        }
        std::string padded = hex;
        if (padded.size() == 1) {
            padded.insert(padded.begin(), '0');
        }
        std::vector<uint8_t> one_byte;
        if (!utils::HexDecode(padded, &one_byte) || one_byte.size() != 1) {
            return false;
        }
        parsed_bytes.push_back(one_byte.front());
    }
    if (parsed_bytes.empty()) {
        return false;
    }
    *bytes = std::move(parsed_bytes);
    return true;
}

bool TryAssembleArm64Instruction(uint64_t address,
                                 const std::string& input_text,
                                 std::vector<uint8_t>* bytes,
                                 std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    const std::vector<std::string> tokens = TokenizeInstructionText(input_text);
    if (tokens.empty()) {
        if (error != nullptr) {
            *error = "Instruction is empty.";
        }
        return false;
    }

    const auto fail = [error](const std::string& message) {
        if (error != nullptr) {
            *error = message;
        }
        return false;
    };

    std::string keystone_error;
    if (TryAssembleWithKeystone(KS_ARCH_ARM64,
                                KS_MODE_LITTLE_ENDIAN,
                                address,
                                input_text,
                                bytes,
                                &keystone_error)) {
        if (bytes->size() == 4) {
            return true;
        }
        keystone_error = BuildInstructionSizeError("ARM64", 4, bytes->size());
    }

    if (tokens[0] == "nop" && tokens.size() == 1) {
        *bytes = EncodeArm64Word(0xD503201FU);
        return true;
    }

    if (tokens[0] == "ret") {
        int reg = 30;
        if (tokens.size() == 2) {
            if (!ParseArm64Register(tokens[1], &reg)) {
                return fail("Invalid ARM64 RET register.");
            }
        } else if (tokens.size() != 1) {
            return fail("Unsupported ARM64 RET syntax.");
        }
        *bytes = EncodeArm64Word(0xD65F0000U | (static_cast<uint32_t>(reg) << 5U));
        return true;
    }

    if (tokens[0] == "br" || tokens[0] == "blr") {
        if (tokens.size() != 2) {
            return fail("Unsupported ARM64 branch-register syntax.");
        }
        int reg = 0;
        if (!ParseArm64Register(tokens[1], &reg)) {
            return fail("Invalid ARM64 branch register.");
        }
        const uint32_t base = tokens[0] == "br" ? 0xD61F0000U : 0xD63F0000U;
        *bytes = EncodeArm64Word(base | (static_cast<uint32_t>(reg) << 5U));
        return true;
    }

    if (tokens[0] == "b" || tokens[0] == "bl") {
        if (tokens.size() != 2) {
            return fail("Unsupported ARM64 branch syntax.");
        }

        int64_t parsed_target = 0;
        if (!ParseSignedIntegerToken(tokens[1], &parsed_target)) {
            return fail("Invalid ARM64 branch target.");
        }

        uint64_t target_address = 0;
        if (tokens[1] == ".") {
            target_address = address;
        } else if (!tokens[1].empty() &&
                   (tokens[1].front() == '+' || tokens[1].front() == '-')) {
            target_address = static_cast<uint64_t>(
                static_cast<int64_t>(address) + parsed_target);
        } else {
            target_address = static_cast<uint64_t>(parsed_target);
        }

        const int64_t diff = static_cast<int64_t>(target_address) -
                             static_cast<int64_t>(address);
        if (diff % 4 != 0) {
            return fail("ARM64 branch target must be 4-byte aligned.");
        }

        const int64_t imm26 = diff / 4;
        constexpr int64_t kMinImm26 = -(1LL << 25);
        constexpr int64_t kMaxImm26 = (1LL << 25) - 1;
        if (imm26 < kMinImm26 || imm26 > kMaxImm26) {
            return fail("ARM64 branch target is out of range.");
        }

        const uint32_t base = tokens[0] == "b" ? 0x14000000U : 0x94000000U;
        const uint32_t encoded = base |
                                 (static_cast<uint32_t>(imm26) & 0x03FFFFFFU);
        *bytes = EncodeArm64Word(encoded);
        return true;
    }

    return fail(keystone_error.empty()
                    ? "Unsupported ARM64 instruction. Use raw hex or ARM64 nop/ret/b/bl/br/blr."
                    : keystone_error);
}

bool TryAssembleArmInstruction(uint64_t address,
                               const MemoryInstructionInfo& current,
                               const std::string& input_text,
                               std::vector<uint8_t>* bytes,
                               std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    const std::vector<std::string> tokens = TokenizeInstructionText(input_text);
    if (tokens.empty()) {
        if (error != nullptr) {
            *error = "Instruction is empty.";
        }
        return false;
    }

    const auto fail = [error](const std::string& message) {
        if (error != nullptr) {
            *error = message;
        }
        return false;
    };

    const std::string normalized_input = NormalizeArmAssemblyInput(input_text);
    std::string keystone_error;
    if (TryAssembleWithKeystone(KS_ARCH_ARM,
                                current.is_thumb
                                    ? (KS_MODE_THUMB | KS_MODE_LITTLE_ENDIAN)
                                    : (KS_MODE_ARM | KS_MODE_LITTLE_ENDIAN),
                                NormalizeAssemblyAddress(current, address),
                                normalized_input,
                                bytes,
                                &keystone_error)) {
        if (bytes->size() == current.size) {
            return true;
        }
        keystone_error = BuildInstructionSizeError(
            current.is_thumb ? "Thumb" : "ARM",
            current.size,
            bytes->size());
    }

    if (tokens[0] == "nop" && tokens.size() == 1) {
        if (current.is_thumb) {
            if (current.size == 2) {
                *bytes = EncodeThumbHalfWord(0xBF00U);
                return true;
            }
            if (current.size == 4) {
                *bytes = EncodeThumbHalfWord(0xBF00U);
                const std::vector<uint8_t> suffix = EncodeThumbHalfWord(0xBF00U);
                bytes->insert(bytes->end(), suffix.begin(), suffix.end());
                return true;
            }
            return fail("Unsupported Thumb instruction size for NOP.");
        }
        if (current.size != 4) {
            return fail("ARM instruction patch size must be 4 bytes.");
        }
        *bytes = EncodeArmWord(0xE320F000U);
        return true;
    }

    if (tokens[0] == "ret" || tokens[0] == "bx" || tokens[0] == "blx") {
        int reg = 14;
        if (tokens[0] == "ret") {
            if (tokens.size() == 2) {
                if (!ParseArmRegister(tokens[1], &reg)) {
                    return fail("Invalid ARM return register.");
                }
            } else if (tokens.size() != 1) {
                return fail("Unsupported ARM return syntax.");
            }
        } else {
            if (tokens.size() != 2) {
                return fail("Unsupported ARM branch-register syntax.");
            }
            if (!ParseArmRegister(tokens[1], &reg)) {
                return fail("Invalid ARM branch register.");
            }
        }

        if (current.is_thumb) {
            const uint16_t base = tokens[0] == "blx" ? 0x4780U : 0x4700U;
            if (current.size == 2) {
                *bytes = EncodeThumbHalfWord(
                    static_cast<uint16_t>(base | (static_cast<uint16_t>(reg) << 3U)));
                return true;
            }
            if (current.size == 4) {
                *bytes = EncodeThumbHalfWord(
                    static_cast<uint16_t>(base | (static_cast<uint16_t>(reg) << 3U)));
                const std::vector<uint8_t> suffix = EncodeThumbHalfWord(0xBF00U);
                bytes->insert(bytes->end(), suffix.begin(), suffix.end());
                return true;
            }
            return fail("Unsupported Thumb instruction size for branch register patch.");
        }

        if (current.size != 4) {
            return fail("ARM instruction patch size must be 4 bytes.");
        }
        const uint32_t base = tokens[0] == "blx" ? 0xE12FFF30U : 0xE12FFF10U;
        *bytes = EncodeArmWord(base | static_cast<uint32_t>(reg));
        return true;
    }

    return fail(keystone_error.empty()
                    ? "Unsupported ARM/Thumb instruction. Use raw hex or ARM/Thumb nop/ret/bx/blx."
                    : keystone_error);
}

}  // namespace

MemoryInstructionInfo ReadMemoryInstruction(int pid, uint64_t address) {
    MemoryInstructionInfo info;
    if (pid <= 0 || address == 0) {
        return info;
    }

    InstructionDecodeConfig config;
    if (!ResolveInstructionDecodeConfig(pid, address, &config)) {
        return info;
    }

    info.architecture = config.architecture;

    ProcessMemoryReader reader(pid);
    std::vector<uint8_t> raw_bytes;
    if (!reader.Read(config.read_address, config.read_size, &raw_bytes)) {
        return info;
    }

    if (!TryDisassembleWithMode(config, raw_bytes, config.primary_mode, &info) &&
        !(config.has_secondary_mode &&
          TryDisassembleWithMode(config, raw_bytes, config.secondary_mode, &info))) {
        info.raw_bytes = raw_bytes;
        info.size = info.raw_bytes.size();
        info.text = FormatHexFallback(info.raw_bytes);
        info.is_valid = true;
    }
    return info;
}

std::vector<MemoryInstructionInfo> ReadMemoryInstructions(
    int pid,
    const std::vector<uint64_t>& addresses) {
    std::vector<MemoryInstructionInfo> instructions;
    instructions.reserve(addresses.size());
    for (uint64_t address : addresses) {
        instructions.push_back(ReadMemoryInstruction(pid, address));
    }
    return instructions;
}

InstructionPatchResultView PatchMemoryInstructionAtAddress(int pid,
                                                           uint64_t address,
                                                           const std::string& input_text) {
    const std::string trimmed_input = utils::Trim(input_text);
    if (trimmed_input.empty()) {
        throw std::runtime_error("Instruction is empty.");
    }

    const MemoryInstructionInfo current = ReadMemoryInstruction(pid, address);
    if (!current.is_valid || current.size == 0 || current.raw_bytes.empty()) {
        throw std::runtime_error("Failed to read current instruction.");
    }

    std::vector<uint8_t> patched_bytes;
    if (!TryParseHexBytes(trimmed_input, &patched_bytes)) {
        std::string assembly_error;
        const bool assembled = current.architecture == "aarch64"
                                   ? TryAssembleArm64Instruction(
                                         address,
                                         trimmed_input,
                                         &patched_bytes,
                                         &assembly_error)
                                   : current.architecture == "arm"
                                   ? TryAssembleArmInstruction(
                                         address,
                                         current,
                                         trimmed_input,
                                         &patched_bytes,
                                         &assembly_error)
                                   : false;
        if (!assembled) {
            throw std::runtime_error(
                assembly_error.empty() ? "Unsupported instruction patch input for this architecture."
                                       : assembly_error);
        }
    }

    if (patched_bytes.size() != current.size) {
        throw std::runtime_error(
            "Patch size must match the current instruction size.");
    }

    std::string patch_error;
    if (!WriteInstructionBytesWithPtrace(pid, address, patched_bytes, &patch_error)) {
        throw std::runtime_error(
            patch_error.empty() ? "Failed to patch instruction bytes safely."
                                : patch_error);
    }

    const MemoryInstructionInfo patched = ReadMemoryInstruction(pid, address);

    InstructionPatchResultView result;
    result.address = address;
    result.architecture = current.architecture;
    result.instruction_size = current.size;
    result.before_bytes = current.raw_bytes;
    result.after_bytes = patched.is_valid && !patched.raw_bytes.empty()
                             ? patched.raw_bytes
                             : patched_bytes;
    result.instruction_text = patched.is_valid && !patched.text.empty()
                                  ? patched.text
                                  : FormatHexFallback(result.after_bytes);
    return result;
}

}  // namespace memory_tool
