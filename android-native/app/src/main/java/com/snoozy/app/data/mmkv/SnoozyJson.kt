package com.snoozy.app.data.mmkv

import kotlinx.serialization.json.Json

val SnoozyJson = Json {
    encodeDefaults = true
    ignoreUnknownKeys = true
}
