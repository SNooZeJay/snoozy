package com.snoozy.app

import android.content.Context
import com.snoozy.app.data.db.SnoozyDatabases
import com.snoozy.app.data.diagnostics.DataDiagnostics
import com.snoozy.app.data.library.LibraryRepository
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.scan.LibraryScanner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AppContainer(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val stores = SnoozyStores(appContext)
    val databases = SnoozyDatabases(appContext)
    val scanner = LibraryScanner(appContext, stores)
    val repository = LibraryRepository(appContext, stores, scanner, databases)

    private var loadJob: Job? = null

    fun start() {
        val previous = loadJob
        loadJob = scope.launch {
            // A grant can arrive mid-load; run again after it finishes.
            previous?.join()
            val preserved = runCatching { stores.scannedSnapshot().size }.getOrDefault(0)
            val result = repository.refresh()
            DataDiagnostics.log(stores, databases, preserved, result)
        }
    }
}
