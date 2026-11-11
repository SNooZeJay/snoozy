package com.snoozy.app.playback

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaController
import androidx.media3.session.MediaSession
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.snoozy.app.MainActivity
import com.snoozy.app.data.db.SnoozyDatabases
import com.snoozy.app.data.library.LibraryRepository
import com.snoozy.app.data.mmkv.SnoozyStores
import com.snoozy.app.data.model.PlaybackSession
import com.snoozy.app.data.model.Track
import com.snoozy.app.data.playback.resolvePlaybackSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.roundToLong

class PlaybackController(
    context: Context,
    private val stores: SnoozyStores,
    private val databases: SnoozyDatabases,
    private val repository: LibraryRepository,
) {
    data class State(
        val ready: Boolean = false,
        val activeTrack: Track? = null,
        val isPlaying: Boolean = false,
        val queueItems: List<QueueEntry> = emptyList(),
        val queueIndex: Int = -1,
        val repeatMode: RepeatState = RepeatState.Off,
        val shuffle: Boolean = false,
        val playbackRate: Float = 1.0f,
        val error: String? = null,
    )

    data class Progress(
        val positionSeconds: Double = 0.0,
        val durationSeconds: Double = 0.0,
    )

    private data class ListenProgress(
        val trackId: String,
        val durationSeconds: Double,
        var maxPositionMs: Long = 0L,
    )

    private data class ActiveListeningSession(
        val id: Long?,
        val trackId: String,
        val startedAtMs: Long,
    )

    private val appContext = context.applicationContext
    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val initialSession = stores.playbackSession()
    private val initialRepeat = initialSession?.repeatMode?.let(RepeatState::fromStored)
        ?: RepeatState.fromStored(stores.repeatMode())
    private val initialShuffle = initialSession?.shuffle ?: stores.shuffle()
    private val initialSpeed = PlaybackQueueOps.clampPlaybackSpeed(stores.playbackRate())

    private val _state = MutableStateFlow(
        State(
            repeatMode = initialRepeat,
            shuffle = initialShuffle,
            playbackRate = initialSpeed,
        ),
    )
    val state: StateFlow<State> = _state.asStateFlow()

    private val _progress = MutableStateFlow(
        Progress(
            positionSeconds = initialSession?.positionSeconds ?: 0.0,
            durationSeconds = 0.0,
        ),
    )
    val progress: StateFlow<Progress> = _progress.asStateFlow()

    private var exoPlayer: ExoPlayer? = null
    private var mediaSession: MediaSession? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var tickerJob: Job? = null
    private var coldStartRestored = false
    private var restoredPositionSeconds = initialSession?.positionSeconds ?: 0.0
    private var listenProgress: ListenProgress? = null
    private var activeListeningSession: ActiveListeningSession? = null

    init {
        mainScope.launch {
            repository.state.collect { libState ->
                if (!coldStartRestored && libState.tracks.isNotEmpty()) {
                    coldStartRestored = true
                    restoreColdStartSession(libState.tracks)
                } else if (coldStartRestored && libState.tracks.isNotEmpty()) {
                    refreshActiveTrackMetadata(libState.tracks)
                }
            }
        }
    }

    fun getOrCreateSession(): MediaSession {
        mediaSession?.let { return it }
        val player = getOrCreatePlayer()
        val sessionActivity = PendingIntent.getActivity(
            appContext,
            0,
            Intent(appContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val callback = object : MediaSession.Callback {
            override fun onAddMediaItems(
                mediaSession: MediaSession,
                controller: MediaSession.ControllerInfo,
                mediaItems: List<MediaItem>,
            ): ListenableFuture<List<MediaItem>> {
                val byId = tracksById()
                val resolved = mediaItems.map { item ->
                    val track = byId[item.mediaId]
                    if (track != null) MediaItemMapper.mediaItemFor(track) else item
                }
                return Futures.immediateFuture(resolved)
            }
        }
        return MediaSession.Builder(appContext, player)
            .setId(SESSION_ID)
            .setSessionActivity(sessionActivity)
            .setCallback(callback)
            .build()
            .also { created ->
                mediaSession = created
            }
    }

    private fun getOrCreatePlayer(): ExoPlayer {
        exoPlayer?.let { return it }
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()
        return ExoPlayer.Builder(appContext)
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .build()
            .also { player ->
                exoPlayer = player
                player.repeatMode = toExoRepeatMode(_state.value.repeatMode)
                player.shuffleModeEnabled = _state.value.shuffle
                player.setPlaybackSpeed(_state.value.playbackRate)
                player.addListener(playerListener)
                _state.update { it.copy(ready = true) }
            }
    }

    private fun ensureServiceBound() {
        getOrCreateSession()
        if (controllerFuture != null) return
        try {
            val token = SessionToken(
                appContext,
                ComponentName(appContext, SnoozyPlaybackService::class.java),
            )
            controllerFuture = MediaController.Builder(appContext, token).buildAsync()
        } catch (error: Exception) {
            Log.w(TAG, "Could not bind media session service", error)
        }
    }

    private val playerListener = object : Player.Listener {
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            val nextId = mediaItem?.mediaId
            handleTrackTransition(nextId, recordNewRecent = reason != Player.MEDIA_ITEM_TRANSITION_REASON_PLAYLIST_CHANGED)
            syncQueueAndStateFromPlayer()
            persistCurrentSession()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            _state.update { it.copy(isPlaying = isPlaying) }
            if (isPlaying) {
                startProgressTicker()
                _state.value.activeTrack?.let(::beginListeningSession)
            } else {
                stopProgressTicker()
                sampleProgressFromPlayer()
                persistCurrentSession()
                endListeningSession()
            }
        }

        override fun onRepeatModeChanged(repeatMode: Int) {
            val mapped = fromExoRepeatMode(repeatMode)
            _state.update { it.copy(repeatMode = mapped) }
        }

        override fun onShuffleModeEnabledChanged(shuffleModeEnabled: Boolean) {
            _state.update { it.copy(shuffle = shuffleModeEnabled) }
        }

        override fun onTimelineChanged(timeline: androidx.media3.common.Timeline, reason: Int) {
            syncQueueAndStateFromPlayer()
        }

        override fun onPlayerError(error: PlaybackException) {
            val message = error.localizedMessage?.takeIf { it.isNotBlank() } ?: "Playback failed."
            Log.w(TAG, "ExoPlayer error", error)
            _state.update { it.copy(error = message, isPlaying = false) }
            stopProgressTicker()
            endListeningSession()
        }
    }

    private fun restoreColdStartSession(tracks: List<Track>) {
        try {
            val byId = tracks.associateBy { it.id }
            val persisted = stores.playbackSession()
            val resolved = resolvePlaybackSession(persisted, byId) ?: return

            val player = getOrCreatePlayer()
            ensureServiceBound()
            val repeat = RepeatState.fromStored(resolved.repeatMode)
            val items = resolved.queueTracks.map(MediaItemMapper::mediaItemFor)
            val startPositionMs = (resolved.positionSeconds * 1000.0).roundToLong().coerceAtLeast(0L)

            restoredPositionSeconds = resolved.positionSeconds
            listenProgress = ListenProgress(
                trackId = resolved.activeTrack.id,
                durationSeconds = resolved.activeTrack.duration,
                maxPositionMs = 0L,
            )

            player.playWhenReady = false
            player.repeatMode = toExoRepeatMode(repeat)
            player.shuffleModeEnabled = resolved.shuffle
            player.setPlaybackSpeed(_state.value.playbackRate)
            player.setMediaItems(items, resolved.activeIndex, startPositionMs)
            player.prepare()

            _state.update {
                it.copy(
                    ready = true,
                    activeTrack = resolved.activeTrack,
                    isPlaying = false,
                    queueItems = resolved.queueTracks.map(PlaybackQueueOps::queueEntryFor),
                    queueIndex = resolved.activeIndex,
                    repeatMode = repeat,
                    shuffle = resolved.shuffle,
                )
            }
            _progress.value = Progress(
                positionSeconds = resolved.positionSeconds,
                durationSeconds = resolved.activeTrack.duration,
            )

            ioScope.launch {
                stores.saveRepeatMode(repeat.storageValue)
                stores.saveShuffle(resolved.shuffle)
                stores.saveQueueIds(resolved.queueIds)
                stores.savePlaybackSession(
                    PlaybackSession(
                        activeTrackId = resolved.activeTrack.id,
                        queueIds = resolved.queueIds,
                        queueIndex = resolved.activeIndex,
                        positionSeconds = resolved.positionSeconds,
                        shuffle = resolved.shuffle,
                        repeatMode = repeat.storageValue,
                        updatedAt = System.currentTimeMillis(),
                    ),
                )
            }
        } catch (error: Exception) {
            Log.w(TAG, "Cold-start session restore failed", error)
        }
    }

    private fun refreshActiveTrackMetadata(tracks: List<Track>) {
        val currentActive = _state.value.activeTrack ?: return
        val updated = tracks.firstOrNull { it.id == currentActive.id } ?: return
        if (updated != currentActive) {
            _state.update { it.copy(activeTrack = updated) }
        }
    }

    fun playTrack(
        track: Track,
        queue: List<Track> = emptyList(),
        shuffleOverride: Boolean? = null,
        repeatOverride: RepeatState? = null,
    ) {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                ensureServiceBound()
                val effectiveQueue = queue.ifEmpty {
                    repository.state.value.tracks.ifEmpty { listOf(track) }
                }.let { candidate ->
                    if (candidate.any { it.id == track.id }) candidate else listOf(track) + candidate
                }
                val startIndex = effectiveQueue.indexOfFirst { it.id == track.id }.coerceAtLeast(0)
                val nextShuffle = shuffleOverride ?: _state.value.shuffle
                val nextRepeat = repeatOverride ?: _state.value.repeatMode

                handleTrackTransition(track.id, recordNewRecent = true)
                restoredPositionSeconds = 0.0

                val items = effectiveQueue.map(MediaItemMapper::mediaItemFor)
                player.repeatMode = toExoRepeatMode(nextRepeat)
                player.shuffleModeEnabled = nextShuffle
                player.setPlaybackSpeed(_state.value.playbackRate)
                player.setMediaItems(items, startIndex, 0L)
                player.prepare()
                player.play()

                val queueIds = effectiveQueue.map { it.id }
                _state.update {
                    it.copy(
                        ready = true,
                        activeTrack = track,
                        isPlaying = true,
                        queueItems = effectiveQueue.map(PlaybackQueueOps::queueEntryFor),
                        queueIndex = startIndex,
                        repeatMode = nextRepeat,
                        shuffle = nextShuffle,
                        error = null,
                    )
                }
                _progress.value = Progress(positionSeconds = 0.0, durationSeconds = track.duration)

                ioScope.launch {
                    stores.saveRepeatMode(nextRepeat.storageValue)
                    stores.saveShuffle(nextShuffle)
                    stores.saveQueueIds(queueIds)
                    stores.savePlaybackSession(
                        PlaybackSession(
                            activeTrackId = track.id,
                            queueIds = queueIds,
                            queueIndex = startIndex,
                            positionSeconds = 0.0,
                            shuffle = nextShuffle,
                            repeatMode = nextRepeat.storageValue,
                            updatedAt = System.currentTimeMillis(),
                        ),
                    )
                }
            } catch (error: Exception) {
                Log.w(TAG, "playTrack failed", error)
                _state.update {
                    it.copy(error = error.localizedMessage ?: "Could not start playback.")
                }
            }
        }
    }

    fun togglePlayback() {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                ensureServiceBound()
                if (player.isPlaying) {
                    player.pause()
                    persistCurrentSession()
                    return@launch
                }
                if (player.mediaItemCount == 0) {
                    val fallbackTrack = _state.value.activeTrack
                        ?: repository.state.value.tracks.firstOrNull()
                        ?: return@launch
                    playTrack(fallbackTrack, repository.state.value.tracks)
                    return@launch
                }
                if (restoredPositionSeconds > 0.0 && player.currentPosition < 1_000L) {
                    player.seekTo((restoredPositionSeconds * 1000.0).roundToLong())
                }
                if (player.playbackState == Player.STATE_IDLE || player.playbackState == Player.STATE_ENDED) {
                    player.prepare()
                }
                player.play()
                _state.update { it.copy(error = null) }
            } catch (error: Exception) {
                Log.w(TAG, "togglePlayback failed", error)
                _state.update {
                    it.copy(error = error.localizedMessage ?: "Playback failed.")
                }
            }
        }
    }

    fun pause() {
        mainScope.launch {
            try {
                exoPlayer?.pause()
                persistCurrentSession()
            } catch (error: Exception) {
                Log.w(TAG, "pause failed", error)
            }
        }
    }

    fun next() {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                ensureServiceBound()
                if (player.mediaItemCount == 0) return@launch
                restoredPositionSeconds = 0.0
                if (player.hasNextMediaItem()) {
                    player.seekToNextMediaItem()
                } else if (player.mediaItemCount > 0) {
                    player.seekTo(0, 0L)
                }
                player.play()
            } catch (error: Exception) {
                Log.w(TAG, "next failed", error)
                _state.update { it.copy(error = error.localizedMessage ?: "Could not skip track.") }
            }
        }
    }

    fun previous() {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                ensureServiceBound()
                if (player.mediaItemCount == 0) return@launch
                restoredPositionSeconds = 0.0
                if (PlaybackQueueOps.shouldRestartOnPrevious(player.currentPosition)) {
                    player.seekTo(0L)
                } else if (player.hasPreviousMediaItem()) {
                    player.seekToPreviousMediaItem()
                } else {
                    player.seekTo(0L)
                }
                player.play()
            } catch (error: Exception) {
                Log.w(TAG, "previous failed", error)
                _state.update { it.copy(error = error.localizedMessage ?: "Could not skip back.") }
            }
        }
    }

    fun seekTo(seconds: Double) {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                val clampedSeconds = max(0.0, if (seconds.isFinite()) seconds else 0.0)
                restoredPositionSeconds = clampedSeconds
                player.seekTo((clampedSeconds * 1000.0).roundToLong())
                _progress.update { it.copy(positionSeconds = clampedSeconds) }
                persistCurrentSession(positionOverrideSeconds = clampedSeconds)
            } catch (error: Exception) {
                Log.w(TAG, "seekTo failed", error)
            }
        }
    }

    fun playNext(track: Track) {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                val currentIds = currentPlayerQueueIds(player)
                if (currentIds.isEmpty()) {
                    playTrack(track, listOf(track))
                    return@launch
                }
                val activeIndex = player.currentMediaItemIndex.takeIf { it >= 0 } ?: _state.value.queueIndex
                val mutation = PlaybackQueueOps.playNextOrder(currentIds, activeIndex, track.id)
                if (mutation.insertIndex < 0) return@launch
                if (mutation.removeIndex >= 0) {
                    player.removeMediaItem(mutation.removeIndex)
                }
                player.addMediaItem(
                    mutation.insertIndex.coerceIn(0, player.mediaItemCount),
                    MediaItemMapper.mediaItemFor(track),
                )
                syncQueueAndStateFromPlayer()
                persistCurrentSession()
            } catch (error: Exception) {
                Log.w(TAG, "playNext failed", error)
                _state.update { it.copy(error = error.localizedMessage ?: "Could not update queue.") }
            }
        }
    }

    fun addToQueue(track: Track) {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                val currentIds = currentPlayerQueueIds(player)
                if (currentIds.isEmpty()) {
                    playTrack(track, listOf(track))
                    return@launch
                }
                val nextIds = PlaybackQueueOps.appendUnique(currentIds, track.id)
                if (nextIds === currentIds) return@launch
                player.addMediaItem(MediaItemMapper.mediaItemFor(track))
                syncQueueAndStateFromPlayer()
                persistCurrentSession()
            } catch (error: Exception) {
                Log.w(TAG, "addToQueue failed", error)
                _state.update { it.copy(error = error.localizedMessage ?: "Could not update queue.") }
            }
        }
    }

    fun removeQueueItem(index: Int) {
        mainScope.launch {
            try {
                val player = exoPlayer ?: return@launch
                if (index !in 0 until player.mediaItemCount) return@launch
                player.removeMediaItem(index)
                if (player.mediaItemCount == 0) {
                    clearQueue()
                    return@launch
                }
                syncQueueAndStateFromPlayer()
                persistCurrentSession()
            } catch (error: Exception) {
                Log.w(TAG, "removeQueueItem failed", error)
            }
        }
    }

    fun moveQueueItem(from: Int, to: Int) {
        mainScope.launch {
            try {
                val player = exoPlayer ?: return@launch
                if (from == to || from !in 0 until player.mediaItemCount || to !in 0 until player.mediaItemCount) {
                    return@launch
                }
                player.moveMediaItem(from, to)
                syncQueueAndStateFromPlayer()
                persistCurrentSession()
            } catch (error: Exception) {
                Log.w(TAG, "moveQueueItem failed", error)
            }
        }
    }

    fun clearQueue() {
        mainScope.launch {
            try {
                handleTrackTransition(null, recordNewRecent = false)
                endListeningSession()
                stopProgressTicker()
                exoPlayer?.stop()
                exoPlayer?.clearMediaItems()
                restoredPositionSeconds = 0.0
                _state.update {
                    it.copy(
                        activeTrack = null,
                        isPlaying = false,
                        queueItems = emptyList(),
                        queueIndex = -1,
                    )
                }
                _progress.value = Progress()
                ioScope.launch {
                    stores.clearQueueIds()
                    stores.clearPlaybackSession()
                }
            } catch (error: Exception) {
                Log.w(TAG, "clearQueue failed", error)
            }
        }
    }

    fun playQueueItem(index: Int) {
        mainScope.launch {
            try {
                val player = getOrCreatePlayer()
                ensureServiceBound()
                if (index !in 0 until player.mediaItemCount) return@launch
                restoredPositionSeconds = 0.0
                player.seekTo(index, 0L)
                player.prepare()
                player.play()
                syncQueueAndStateFromPlayer()
                persistCurrentSession(positionOverrideSeconds = 0.0)
            } catch (error: Exception) {
                Log.w(TAG, "playQueueItem failed", error)
            }
        }
    }

    fun cycleRepeat() {
        mainScope.launch {
            val next = _state.value.repeatMode.next()
            exoPlayer?.repeatMode = toExoRepeatMode(next)
            _state.update { it.copy(repeatMode = next) }
            ioScope.launch { stores.saveRepeatMode(next.storageValue) }
            persistCurrentSession()
        }
    }

    fun setShuffle(enabled: Boolean) {
        mainScope.launch {
            exoPlayer?.shuffleModeEnabled = enabled
            _state.update { it.copy(shuffle = enabled) }
            ioScope.launch { stores.saveShuffle(enabled) }
            persistCurrentSession()
        }
    }

    fun toggleShuffle() {
        setShuffle(!_state.value.shuffle)
    }

    fun setPlaybackRate(rate: Double) {
        mainScope.launch {
            val clamped = PlaybackQueueOps.clampPlaybackSpeed(rate)
            exoPlayer?.setPlaybackSpeed(clamped)
            _state.update { it.copy(playbackRate = clamped) }
            ioScope.launch { stores.savePlaybackRate(clamped.toDouble()) }
        }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    fun onTaskRemoved() {
        mainScope.launch {
            sampleProgressFromPlayer()
            persistCurrentSession()
            if (exoPlayer?.isPlaying != true) {
                endListeningSession()
            }
        }
    }

    private fun startProgressTicker() {
        if (tickerJob?.isActive == true) return
        tickerJob = mainScope.launch {
            var ticksSincePersist = 0
            while (isActive) {
                sampleProgressFromPlayer()
                ticksSincePersist += 1
                if (ticksSincePersist >= 5) {
                    ticksSincePersist = 0
                    persistCurrentSession()
                }
                delay(1_000L)
            }
        }
    }

    private fun stopProgressTicker() {
        tickerJob?.cancel()
        tickerJob = null
    }

    private fun sampleProgressFromPlayer() {
        val player = exoPlayer ?: return
        val positionMs = player.currentPosition.coerceAtLeast(0L)
        val positionSeconds = positionMs / 1000.0
        if (positionMs > 0L && restoredPositionSeconds > 0.0) {
            restoredPositionSeconds = 0.0
        }
        val active = _state.value.activeTrack
        val durationSeconds = if (player.duration > 0L && player.duration != C.TIME_UNSET) {
            player.duration / 1000.0
        } else {
            active?.duration ?: 0.0
        }
        _progress.value = Progress(
            positionSeconds = if (positionSeconds > 0.0) positionSeconds else restoredPositionSeconds,
            durationSeconds = durationSeconds,
        )
        val currentListen = listenProgress
        if (currentListen != null && currentListen.trackId == active?.id) {
            if (positionMs > currentListen.maxPositionMs) {
                currentListen.maxPositionMs = positionMs
            }
        }
    }

    private fun handleTrackTransition(nextTrackId: String?, recordNewRecent: Boolean) {
        val previous = listenProgress
        if (previous != null && previous.trackId != nextTrackId) {
            val maxPos = previous.maxPositionMs
            val duration = previous.durationSeconds
            if (PlaybackQueueOps.shouldRecordPlay(duration, maxPos)) {
                ioScope.launch {
                    repository.recordPlay(previous.trackId, maxPos)
                }
            }
        }
        val nextTrack = nextTrackId?.let { tracksById()[it] }
        listenProgress = if (nextTrack != null) {
            ListenProgress(
                trackId = nextTrack.id,
                durationSeconds = nextTrack.duration,
                maxPositionMs = 0L,
            )
        } else if (nextTrackId != null) {
            ListenProgress(trackId = nextTrackId, durationSeconds = 0.0, maxPositionMs = 0L)
        } else {
            null
        }
        if (recordNewRecent && !nextTrackId.isNullOrBlank()) {
            ioScope.launch { repository.recordRecent(nextTrackId) }
        }
        if (nextTrack != null && _state.value.isPlaying) {
            beginListeningSession(nextTrack)
        }
    }

    private fun beginListeningSession(track: Track) {
        val existing = activeListeningSession
        if (existing?.trackId == track.id) return
        val now = System.currentTimeMillis()
        if (existing != null) {
            val prevId = existing.id
            val elapsedSeconds = ((now - existing.startedAtMs) / 1000L).coerceAtLeast(0L)
            if (prevId != null) {
                ioScope.launch {
                    databases.finishListeningSession(prevId, now, elapsedSeconds)
                }
            }
        }
        activeListeningSession = ActiveListeningSession(id = null, trackId = track.id, startedAtMs = now)
        ioScope.launch {
            val insertedId = databases.startListeningSession(track.id, now)
            mainScope.launch {
                val current = activeListeningSession
                if (current != null && current.trackId == track.id && current.startedAtMs == now) {
                    activeListeningSession = current.copy(id = insertedId)
                } else if (insertedId != null) {
                    val finishNow = System.currentTimeMillis()
                    val elapsed = ((finishNow - now) / 1000L).coerceAtLeast(0L)
                    ioScope.launch {
                        databases.finishListeningSession(insertedId, finishNow, elapsed)
                    }
                }
            }
        }
    }

    private fun endListeningSession() {
        val current = activeListeningSession ?: return
        activeListeningSession = null
        val id = current.id ?: return
        val now = System.currentTimeMillis()
        val elapsedSeconds = ((now - current.startedAtMs) / 1000L).coerceAtLeast(0L)
        ioScope.launch {
            databases.finishListeningSession(id, now, elapsedSeconds)
        }
    }

    private fun syncQueueAndStateFromPlayer() {
        val player = exoPlayer ?: return
        val byId = tracksById()
        val count = player.mediaItemCount
        if (count == 0) return

        val entries = ArrayList<QueueEntry>(count)
        val ids = ArrayList<String>(count)
        for (i in 0 until count) {
            val item = player.getMediaItemAt(i)
            val id = item.mediaId
            if (id.isNotEmpty()) ids += id
            val track = byId[id]
            entries += if (track != null) {
                PlaybackQueueOps.queueEntryFor(track)
            } else {
                QueueEntry(
                    mediaId = id.ifEmpty { "unknown-$i" },
                    title = item.mediaMetadata.title?.toString()?.takeIf { it.isNotBlank() } ?: "Untitled track",
                    artist = item.mediaMetadata.artist?.toString()?.takeIf { it.isNotBlank() } ?: "Unknown artist",
                    artwork = item.mediaMetadata.artworkUri?.toString(),
                )
            }
        }
        val activeIndex = player.currentMediaItemIndex.coerceIn(0, count - 1)
        val activeMediaId = player.currentMediaItem?.mediaId ?: ids.getOrNull(activeIndex)
        val activeTrack = activeMediaId?.let { byId[it] } ?: _state.value.activeTrack

        _state.update {
            it.copy(
                activeTrack = activeTrack,
                queueItems = entries,
                queueIndex = activeIndex,
            )
        }
        if (ids.isNotEmpty()) {
            ioScope.launch { stores.saveQueueIds(ids) }
        }
    }

    private fun persistCurrentSession(positionOverrideSeconds: Double? = null) {
        val player = exoPlayer
        val currentState = _state.value
        val queueIds = if (player != null && player.mediaItemCount > 0) {
            currentPlayerQueueIds(player)
        } else {
            currentState.queueItems.map { it.mediaId }.filter { it.isNotBlank() }
        }
        if (queueIds.isEmpty()) return

        val resolvedIndex = (player?.currentMediaItemIndex?.takeIf { it >= 0 } ?: currentState.queueIndex)
            .coerceIn(0, queueIds.lastIndex)
        val activeTrackId = player?.currentMediaItem?.mediaId?.takeIf { it.isNotBlank() }
            ?: currentState.activeTrack?.id
            ?: queueIds[resolvedIndex]
        val positionSeconds = positionOverrideSeconds ?: run {
            val nativeSeconds = (player?.currentPosition ?: 0L).coerceAtLeast(0L) / 1000.0
            if (nativeSeconds > 0.0) nativeSeconds else restoredPositionSeconds
        }
        val session = PlaybackSession(
            activeTrackId = activeTrackId,
            queueIds = queueIds,
            queueIndex = resolvedIndex,
            positionSeconds = positionSeconds,
            shuffle = currentState.shuffle,
            repeatMode = currentState.repeatMode.storageValue,
            updatedAt = System.currentTimeMillis(),
        )
        ioScope.launch {
            stores.savePlaybackSession(session)
            stores.saveQueueIds(queueIds)
        }
    }

    private fun currentPlayerQueueIds(player: ExoPlayer): List<String> = buildList {
        for (i in 0 until player.mediaItemCount) {
            val id = player.getMediaItemAt(i).mediaId
            if (id.isNotBlank()) add(id)
        }
    }

    private fun tracksById(): Map<String, Track> =
        repository.state.value.tracks.associateBy { it.id }

    private fun toExoRepeatMode(state: RepeatState): Int = when (state) {
        RepeatState.Off -> Player.REPEAT_MODE_OFF
        RepeatState.All -> Player.REPEAT_MODE_ALL
        RepeatState.One -> Player.REPEAT_MODE_ONE
    }

    private fun fromExoRepeatMode(mode: Int): RepeatState = when (mode) {
        Player.REPEAT_MODE_ALL -> RepeatState.All
        Player.REPEAT_MODE_ONE -> RepeatState.One
        else -> RepeatState.Off
    }

    companion object {
        private const val TAG = "SnoozyPlayback"
        private const val SESSION_ID = "snoozy-main-session"
    }
}
