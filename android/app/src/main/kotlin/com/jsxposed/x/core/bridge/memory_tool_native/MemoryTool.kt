package com.jsxposed.x.core.bridge.memory_tool_native

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
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
        private val foregroundPackageRegex =
            Regex("""([A-Za-z0-9._]+)/(?:[A-Za-z0-9._$]+|\.[A-Za-z0-9._$]+)""")
    }

    private val packageManager = context.packageManager
    private val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val iconCache = MemoryToolIconCache(context)
    private val helperManager = MemoryToolHelperManager(context)
    private val daemonClient = MemoryToolDaemonClient(helperManager)

    fun getPid(packageName: String): Long {
        return MemoryToolJni.getPid(packageName)
    }

    @RequiresApi(Build.VERSION_CODES.P)
    fun getProcessInfo(offset: Int, limit: Int): List<ProcessInfo> {
        if (limit <= 0) {
            return emptyList()
        }

        val runningProcessMap = activityManager.runningAppProcesses
            ?.associateBy { it.pid }
            .orEmpty()
        val foregroundPackageName = resolveForegroundPackageName()

        val sortedProcesses = readProcessEntries()
            .mapNotNull { rawProcess ->
                resolveProcess(rawProcess, runningProcessMap[rawProcess.pid])
            }
            .distinctBy { it.pid }
            .sortedWith(
                compareBy<ResolvedProcess>(
                    { if (it.packageName == foregroundPackageName) 0 else 1 },
                    { if (it.isThirdPartyApp) 0 else 1 },
                    { importanceRank(it.importance) },
                    { it.name.lowercase(Locale.ROOT) },
                    { it.pid }
                )
            )

        if (offset >= sortedProcesses.size) {
            return emptyList()
        }

        val pagedProcesses = sortedProcesses.subList(
            offset.coerceAtLeast(0),
            (offset + limit).coerceAtMost(sortedProcesses.size)
        )

        return pagedProcesses.map { process ->
            ProcessInfo(
                pid = process.pid.toLong(),
                name = process.name,
                packageName = process.packageName,
                icon = iconCache.getIconBytes(process.packageName)
            )
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

    fun readMemoryValues(requests: List<MemoryReadRequest>): List<MemoryValuePreview> {
        return daemonClient.readMemoryValues(requests)
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

    private fun readProcessEntries(): List<RawProcessEntry> {
        if (!hasRootAccess()) {
            LogX.w(TAG, "getProcessInfo requires root access")
            return emptyList()
        }

        val commands = listOf(
            Shell(su = true).execute("ps -A"),
            Shell(su = true).execute("ps")
        )

        for (output in commands) {
            val parsed = parsePsOutput(output)
            if (parsed.isNotEmpty()) {
                return parsed
            }
        }

        LogX.w(TAG, "getProcessInfo root ps returned empty result")
        return emptyList()
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

    private fun resolvePackageName(
        processName: String,
        runningProcessInfo: ActivityManager.RunningAppProcessInfo?
    ): String? {
        val candidates = linkedSetOf<String>()
        val baseProcessName = processName.substringBefore(':')
        candidates += baseProcessName
        candidates += processName
        runningProcessInfo?.pkgList?.let { candidates.addAll(it) }
        runningProcessInfo?.uid?.let { uid ->
            packageManager.getPackagesForUid(uid)?.let { candidates.addAll(it) }
        }

        return candidates.firstOrNull { isInstalledPackage(it) }
    }

    private fun isInstalledPackage(packageName: String): Boolean {
        return try {
            packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun isThirdPartyApp(packageName: String): Boolean {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 &&
                (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun hasRootAccess(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id")).apply {
                waitFor(1200, TimeUnit.MILLISECONDS)
            }
            process.exitValue() == 0
        } catch (e: Exception) {
            LogX.w(TAG, "root check failed: ${e.message}")
            false
        }
    }

    private fun resolveForegroundPackageName(): String? {
        val outputs = listOf(
            Shell(su = true).execute("dumpsys window windows"),
            Shell(su = true).execute("dumpsys activity top")
        )

        for (output in outputs) {
            val packageName = parseForegroundPackageName(output)
            if (packageName != null) {
                return packageName
            }
        }

        LogX.w(TAG, "failed to resolve foreground package name")
        return null
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
}
