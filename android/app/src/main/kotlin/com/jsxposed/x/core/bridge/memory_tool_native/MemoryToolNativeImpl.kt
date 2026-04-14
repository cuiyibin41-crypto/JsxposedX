package com.jsxposed.x.core.bridge.memory_tool_native

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MemoryToolNativeImpl(val context: Context) : MemoryToolNative {
    private val memoryTool = MemoryTool(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun getPid(packageName: String, callback: (Result<Long>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getPid(packageName)
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun getProcessInfo(offset: Long, limit: Long, callback: (Result<List<ProcessInfo>>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getProcessInfo(offset.toInt(), limit.toInt())
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getMemoryRegions(query: MemoryRegionQuery, callback: (Result<List<MemoryRegion>>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getMemoryRegions(query)
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getSearchSessionState(callback: (Result<SearchSessionState>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getSearchSessionState()
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getSearchTaskState(callback: (Result<SearchTaskState>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getSearchTaskState()
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getSearchResults(offset: Long, limit: Long, callback: (Result<List<SearchResult>>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.getSearchResults(offset.toInt(), limit.toInt())
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun readMemoryValues(requests: List<MemoryReadRequest>, callback: (Result<List<MemoryValuePreview>>) -> Unit) {
        scope.launch {
            try {
                val result = memoryTool.readMemoryValues(requests)
                withContext(Dispatchers.Main) {
                    callback(Result.success(result))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun firstScan(request: FirstScanRequest, callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                memoryTool.firstScan(request)
                withContext(Dispatchers.Main) {
                    callback(Result.success(Unit))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun nextScan(request: NextScanRequest, callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                memoryTool.nextScan(request)
                withContext(Dispatchers.Main) {
                    callback(Result.success(Unit))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun cancelSearch(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                memoryTool.cancelSearch()
                withContext(Dispatchers.Main) {
                    callback(Result.success(Unit))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun resetSearchSession(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                memoryTool.resetSearchSession()
                withContext(Dispatchers.Main) {
                    callback(Result.success(Unit))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }
}
