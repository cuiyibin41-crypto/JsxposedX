package com.jsxposed.x.core.bridge.memory_tool_native

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import androidx.annotation.RequiresApi
import com.jsxposed.x.core.utils.log.LogX
import com.jsxposed.x.core.utils.shell.Shell
import java.util.Locale
import java.util.concurrent.TimeUnit

object MemoryToolJni {
    init {
        System.loadLibrary("memory_tool")
    }

    external fun getPid(packageName: String): Long
}

class MemoryTool(private val context: Context) {
    companion object {
        private const val TAG = "MemoryTool"
        private const val PROCESS_INFO_CACHE_TTL_MS = 500L
        private const val FOREGROUND_PACKAGE_CACHE_TTL_MS = 2000L
        private const val ROOT_ACCESS_CACHE_TTL_MS = 15000L
        private const val INSTALLED_PACKAGE_CACHE_TTL_MS = 5 * 60 * 1000L
        private val foregroundPackageRegex =
            Regex("""([A-Za-z0-9._]+)/(?:[A-Za-z0-9._$]+|\.[A-Za-z0-9._$]+)""")
    }

    private val packageManager = context.packageManager
    private val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val iconCache = MemoryToolIconCache(context)
    private val helperManager = MemoryToolHelperManager(context)
    private val daemonClient = MemoryToolDaemonClient(helperManager)
    private val processCacheLock = Any()
    private val processCommandLock = Any()
    private val rootAccessCacheLock = Any()
    private val foregroundPackageCacheLock = Any()
    private val installedPackageCacheLock = Any()
    private val applicationInfoCacheLock = Any()
    private val applicationInfoCache = mutableMapOf<String, ApplicationInfo?>()
    private val thirdPartyAppCache = mutableMapOf<String, Boolean>()
    @Volatile
    private var installedPackageCache: InstalledPackageCache? = null
    @Volatile
    private var processListCache: ProcessListCache? = null
    @Volatile
    private var processListCommand: String? = null
    @Volatile
    private var rootAccessCache: TimedBooleanCache? = null
    @Volatile
    private var foregroundPackageCache: TimedStringCache? = null

    fun getPid(packageName: String): Long {
        return MemoryToolJni.getPid(packageName)
    }

    @RequiresApi(Build.VERSION_CODES.P)
    fun getProcessInfo(offset: Int, limit: Int): List<ProcessInfo> {
        if (limit <= 0) {
            return emptyList()
        }

        val sortedProcesses = getCachedResolvedProcesses()

        if (offset >= sortedProcesses.size) {
            return emptyList()
        }

        val pagedProcesses = sortedProcesses.subList(
            offset.coerceAtLeast(0),
            (offset + limit).coerceAtMost(sortedProcesses.size)
        )

        return pagedProcesses.map { process ->
            val cachedIcon = iconCache.getCachedIconBytes(process.packageName)
            if (cachedIcon == null) {
                iconCache.prefetchIcon(process.packageName)
            }

            ProcessInfo(
                pid = process.pid.toLong(),
                name = process.name,
                packageName = process.packageName,
                icon = cachedIcon
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun getCachedResolvedProcesses(): List<ResolvedProcess> {
        val now = SystemClock.elapsedRealtime()
        val cachedProcesses = processListCache
        if (cachedProcesses != null &&
            now - cachedProcesses.generatedAtMs <= PROCESS_INFO_CACHE_TTL_MS
        ) {
            return cachedProcesses.processes
        }

        synchronized(processCacheLock) {
            val synchronizedNow = SystemClock.elapsedRealtime()
            val refreshedCache = processListCache
            if (refreshedCache != null &&
                synchronizedNow - refreshedCache.generatedAtMs <=
                    PROCESS_INFO_CACHE_TTL_MS
            ) {
                return refreshedCache.processes
            }

            val runningProcessMap = activityManager.runningAppProcesses
                ?.associateBy { it.pid }
                .orEmpty()
            val resolvedProcesses = readProcessEntries()
                .asSequence()
                .mapNotNull { rawProcess ->
                    resolveProcess(rawProcess, runningProcessMap[rawProcess.pid])
                }
                .filterNot { process ->
                    process.packageName == context.packageName ||
                        process.pid == android.os.Process.myPid()
                }
                .distinctBy { it.pid }
                .sortedWith(
                    compareBy<ResolvedProcess>(
                        { if (it.isThirdPartyApp) 0 else 1 },
                        { importanceRank(it.importance) },
                        { it.name.lowercase(Locale.ROOT) },
                        { it.pid }
                    )
                )
                .toList()
            processListCache = ProcessListCache(
                generatedAtMs = synchronizedNow,
                processes = resolvedProcesses
            )
            return resolvedProcesses
        }
    }

    fun getMemoryRegions(query: MemoryRegionQuery): List<MemoryRegion> {
        return daemonClient.getMemoryRegions(query)
    }

    fun getSearchSessionState(): SearchSessionState {
        return daemonClient.getSearchSessionState()
    }

    fun getSearchTaskState(): SearchTaskState {
        return daemonClient.getSearchTaskState()
    }

    fun getSearchResults(offset: Int, limit: Int): List<SearchResult> {
        return daemonClient.getSearchResults(offset, limit)
    }

    fun getPointerScanSessionState(): PointerScanSessionState {
        return daemonClient.getPointerScanSessionState()
    }

    fun getPointerScanTaskState(): PointerScanTaskState {
        return daemonClient.getPointerScanTaskState()
    }

    fun getPointerScanResults(offset: Int, limit: Int): List<PointerScanResult> {
        return daemonClient.getPointerScanResults(offset, limit)
    }

    fun readMemoryValues(requests: List<MemoryReadRequest>): List<MemoryValuePreview> {
        return daemonClient.readMemoryValues(requests)
    }

    fun writeMemoryValue(request: MemoryWriteRequest) {
        daemonClient.writeMemoryValue(request)
    }

    fun setMemoryFreeze(request: MemoryFreezeRequest) {
        daemonClient.setMemoryFreeze(request)
    }

    fun getFrozenMemoryValues(): List<FrozenMemoryValue> {
        return daemonClient.getFrozenMemoryValues()
    }

    fun isProcessPaused(pid: Long): Boolean {
        require(pid > 0) { "Invalid process id." }
        val statusOutput = Shell(su = true).execute("cat /proc/$pid/status")
        if (statusOutput.isBlank()) {
            throw IllegalStateException("Failed to read process status.")
        }
        if (statusOutput.startsWith("ERROR") || statusOutput.startsWith("EXCEPTION")) {
            throw IllegalStateException(statusOutput)
        }

        val stateLine = statusOutput.lineSequence()
            .map { it.trim() }
            .firstOrNull { it.startsWith("State:") }
            ?: return false
        val stateCode = stateLine.removePrefix("State:")
            .trim()
            .firstOrNull()
            ?: return false
        return stateCode == 'T' || stateCode == 't'
    }

    fun setProcessPaused(pid: Long, paused: Boolean) {
        require(pid > 0) { "Invalid process id." }
        val signal = if (paused) "-STOP" else "-CONT"
        val output = Shell(su = true).execute("kill $signal $pid")
        if (output.startsWith("ERROR") || output.startsWith("EXCEPTION")) {
            throw IllegalStateException(output)
        }
    }

    fun firstScan(request: FirstScanRequest) {
        daemonClient.firstScan(request)
    }

    fun nextScan(request: NextScanRequest) {
        daemonClient.nextScan(request)
    }

    fun cancelSearch() {
        daemonClient.cancelSearch()
    }

    fun resetSearchSession() {
        daemonClient.resetSearchSession()
    }

    fun startPointerScan(request: PointerScanRequest) {
        daemonClient.startPointerScan(request)
    }

    fun cancelPointerScan() {
        daemonClient.cancelPointerScan()
    }

    fun resetPointerScanSession() {
        daemonClient.resetPointerScanSession()
    }

    private fun readProcessEntries(): List<RawProcessEntry> {
        if (!hasRootAccess()) {
            LogX.w(TAG, "getProcessInfo requires root access")
            return emptyList()
        }

        val command = resolveProcessListCommand() ?: return emptyList()
        val output = Shell(su = true).execute(command)
        val parsed = parsePsOutput(output)
        if (parsed.isNotEmpty()) {
            return parsed
        }

        LogX.w(TAG, "getProcessInfo root ps returned empty result")
        return emptyList()
    }

    private fun resolveProcessListCommand(): String? {
        val cachedCommand = processListCommand
        if (cachedCommand != null) {
            return cachedCommand
        }

        synchronized(processCommandLock) {
            val refreshedCommand = processListCommand
            if (refreshedCommand != null) {
                return refreshedCommand
            }

            for (candidate in listOf("ps -A", "ps")) {
                val output = Shell(su = true).execute(candidate)
                val parsed = parsePsOutput(output)
                if (parsed.isNotEmpty()) {
                    processListCommand = candidate
                    return candidate
                }
            }

            LogX.w(TAG, "failed to resolve supported ps command")
            return null
        }
    }

    private fun parsePsOutput(output: String): List<RawProcessEntry> {
        if (output.isBlank() || output.startsWith("ERROR") || output.startsWith("EXCEPTION")) {
            return emptyList()
        }

        val lines = output.lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .toList()

        if (lines.isEmpty()) {
            return emptyList()
        }

        val headerTokens = lines.first().split(Regex("\\s+"))
        val pidIndex = headerTokens.indexOfFirst { it.equals("PID", ignoreCase = true) }
        val nameIndex = headerTokens.indexOfFirst {
            it.equals("NAME", ignoreCase = true) ||
                it.equals("CMD", ignoreCase = true) ||
                it.equals("COMMAND", ignoreCase = true)
        }
        val hasHeader = pidIndex >= 0

        return lines.drop(if (hasHeader) 1 else 0).mapNotNull { line ->
            val tokens = line.split(Regex("\\s+"))
            if (tokens.size < 2) {
                return@mapNotNull null
            }

            val resolvedPidIndex = when {
                hasHeader && pidIndex in tokens.indices -> pidIndex
                tokens.size > 1 -> 1
                else -> 0
            }
            val resolvedNameIndex = when {
                hasHeader && nameIndex in tokens.indices -> nameIndex
                else -> tokens.lastIndex
            }

            val pid = tokens.getOrNull(resolvedPidIndex)?.toIntOrNull() ?: return@mapNotNull null
            val processName = tokens.getOrNull(resolvedNameIndex)?.trim().orEmpty()
            if (processName.isBlank()) {
                return@mapNotNull null
            }

            RawProcessEntry(pid = pid, processName = processName)
        }
    }

    private fun resolveProcess(
        rawProcess: RawProcessEntry,
        runningProcessInfo: ActivityManager.RunningAppProcessInfo?
    ): ResolvedProcess? {
        val packageName = resolvePackageName(rawProcess.processName, runningProcessInfo) ?: return null

        return ResolvedProcess(
            pid = rawProcess.pid,
            name = rawProcess.processName,
            packageName = packageName,
            importance = runningProcessInfo?.importance ?: Int.MAX_VALUE,
            isThirdPartyApp = isThirdPartyApp(packageName)
        )
    }

    private fun resolveRunningProcess(
        runningProcessInfo: ActivityManager.RunningAppProcessInfo
    ): ResolvedProcess? {
        val processName = runningProcessInfo.processName.orEmpty()
        if (processName.isBlank()) {
            return null
        }

        val packageName = resolvePackageName(processName, runningProcessInfo) ?: return null
        return ResolvedProcess(
            pid = runningProcessInfo.pid,
            name = processName,
            packageName = packageName,
            importance = runningProcessInfo.importance,
            isThirdPartyApp = isThirdPartyApp(packageName)
        )
    }

    private fun resolvePackageName(
        processName: String,
        runningProcessInfo: ActivityManager.RunningAppProcessInfo?
    ): String? {
        val installedPackages = getInstalledPackages()
        val candidates = linkedSetOf<String>()
        val baseProcessName = processName.substringBefore(':')
        candidates += baseProcessName
        candidates += processName
        runningProcessInfo?.pkgList?.let { candidates.addAll(it) }
        val directMatch = candidates.firstOrNull { candidate ->
            candidate.isNotBlank() && installedPackages.contains(candidate)
        }
        if (directMatch != null) {
            return directMatch
        }

        val uid = runningProcessInfo?.uid ?: return null
        return packageManager.getPackagesForUid(uid)?.firstOrNull { packageName ->
            packageName.isNotBlank() && installedPackages.contains(packageName)
        }
    }

    private fun isInstalledPackage(packageName: String): Boolean {
        if (packageName.isBlank()) {
            return false
        }
        return getInstalledPackages().contains(packageName)
    }

    private fun getInstalledPackages(): Set<String> {
        val now = SystemClock.elapsedRealtime()
        val cachedPackages = installedPackageCache
        if (cachedPackages != null &&
            now - cachedPackages.generatedAtMs <= INSTALLED_PACKAGE_CACHE_TTL_MS
        ) {
            return cachedPackages.packageNames
        }

        synchronized(installedPackageCacheLock) {
            val synchronizedNow = SystemClock.elapsedRealtime()
            val refreshedCache = installedPackageCache
            if (refreshedCache != null &&
                synchronizedNow - refreshedCache.generatedAtMs <=
                    INSTALLED_PACKAGE_CACHE_TTL_MS
            ) {
                return refreshedCache.packageNames
            }

            val packageNames = packageManager.getInstalledApplications(0)
                .asSequence()
                .mapNotNull { it.packageName }
                .filter { it.isNotBlank() }
                .toSet()
            installedPackageCache = InstalledPackageCache(
                generatedAtMs = synchronizedNow,
                packageNames = packageNames
            )
            return packageNames
        }
    }

    private fun getApplicationInfoCached(packageName: String): ApplicationInfo? {
        synchronized(applicationInfoCacheLock) {
            if (applicationInfoCache.containsKey(packageName)) {
                return applicationInfoCache[packageName]
            }

            val appInfo = try {
                packageManager.getApplicationInfo(packageName, 0)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
            applicationInfoCache[packageName] = appInfo
            return appInfo
        }
    }

    private fun isThirdPartyApp(packageName: String): Boolean {
        synchronized(applicationInfoCacheLock) {
            val cachedValue = thirdPartyAppCache[packageName]
            if (cachedValue != null) {
                return cachedValue
            }
        }

        val appInfo = getApplicationInfoCached(packageName) ?: return false
        val isThirdParty =
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 &&
                (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0

        synchronized(applicationInfoCacheLock) {
            thirdPartyAppCache[packageName] = isThirdParty
        }
        return isThirdParty
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun hasRootAccess(): Boolean {
        val now = SystemClock.elapsedRealtime()
        val cachedRootAccess = rootAccessCache
        if (cachedRootAccess != null &&
            now - cachedRootAccess.generatedAtMs <= ROOT_ACCESS_CACHE_TTL_MS
        ) {
            return cachedRootAccess.value
        }

        synchronized(rootAccessCacheLock) {
            val synchronizedNow = SystemClock.elapsedRealtime()
            val refreshedCache = rootAccessCache
            if (refreshedCache != null &&
                synchronizedNow - refreshedCache.generatedAtMs <=
                    ROOT_ACCESS_CACHE_TTL_MS
            ) {
                return refreshedCache.value
            }

            val hasRoot = try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
                val finished = process.waitFor(1200, TimeUnit.MILLISECONDS)
                if (!finished) {
                    process.destroy()
                    false
                } else {
                    process.exitValue() == 0
                }
            } catch (e: Exception) {
                LogX.w(TAG, "root check failed: ${e.message}")
                false
            }
            rootAccessCache = TimedBooleanCache(
                generatedAtMs = synchronizedNow,
                value = hasRoot
            )
            return hasRoot
        }
    }

    private fun resolveForegroundPackageName(): String? {
        val now = SystemClock.elapsedRealtime()
        val cachedForegroundPackage = foregroundPackageCache
        if (cachedForegroundPackage != null &&
            now - cachedForegroundPackage.generatedAtMs <=
                FOREGROUND_PACKAGE_CACHE_TTL_MS
        ) {
            return cachedForegroundPackage.value
        }

        synchronized(foregroundPackageCacheLock) {
            val synchronizedNow = SystemClock.elapsedRealtime()
            val refreshedCache = foregroundPackageCache
            if (refreshedCache != null &&
                synchronizedNow - refreshedCache.generatedAtMs <=
                    FOREGROUND_PACKAGE_CACHE_TTL_MS
            ) {
                return refreshedCache.value
            }

            for (command in listOf("dumpsys window windows", "dumpsys activity top")) {
                val output = Shell(su = true).execute(command)
                val packageName = parseForegroundPackageName(output)
                if (packageName != null) {
                    foregroundPackageCache = TimedStringCache(
                        generatedAtMs = synchronizedNow,
                        value = packageName
                    )
                    return packageName
                }
            }

            LogX.w(TAG, "failed to resolve foreground package name")
            foregroundPackageCache = TimedStringCache(
                generatedAtMs = synchronizedNow,
                value = null
            )
            return null
        }
    }

    private fun parseForegroundPackageName(output: String): String? {
        if (output.isBlank() || output.startsWith("ERROR") || output.startsWith("EXCEPTION")) {
            return null
        }

        val prioritizedLines = output.lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .sortedBy { line ->
                when {
                    "mCurrentFocus" in line -> 0
                    "mFocusedApp" in line -> 1
                    line.startsWith("ACTIVITY ") -> 2
                    else -> 3
                }
            }

        for (line in prioritizedLines) {
            val packageName = foregroundPackageRegex.find(line)?.groupValues?.getOrNull(1)
            if (packageName != null && isInstalledPackage(packageName)) {
                return packageName
            }
        }

        return null
    }

    private fun importanceRank(importance: Int): Int {
        if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
            return 0
        }
        if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE) {
            return 1
        }
        if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_PERCEPTIBLE) {
            return 2
        }
        if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE) {
            return 3
        }
        if (importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED) {
            return 4
        }
        return 5
    }

    private data class RawProcessEntry(
        val pid: Int,
        val processName: String
    )

    private data class ResolvedProcess(
        val pid: Int,
        val name: String,
        val packageName: String,
        val importance: Int,
        val isThirdPartyApp: Boolean
    )

    private data class ProcessListCache(
        val generatedAtMs: Long,
        val processes: List<ResolvedProcess>
    )

    private data class TimedBooleanCache(
        val generatedAtMs: Long,
        val value: Boolean
    )

    private data class TimedStringCache(
        val generatedAtMs: Long,
        val value: String?
    )

    private data class InstalledPackageCache(
        val generatedAtMs: Long,
        val packageNames: Set<String>
    )
}
