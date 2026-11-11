package com.snoozy.app.playback

import android.content.Intent
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.snoozy.app.SnoozyApplication

class SnoozyPlaybackService : MediaSessionService() {
    override fun onCreate() {
        super.onCreate()
        val session = (application as SnoozyApplication).container.playbackController.getOrCreateSession()
        if (!isSessionAdded(session)) {
            addSession(session)
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession =
        (application as SnoozyApplication).container.playbackController.getOrCreateSession()

    override fun onTaskRemoved(rootIntent: Intent?) {
        val controller = (application as SnoozyApplication).container.playbackController
        controller.onTaskRemoved()
        val player = controller.getOrCreateSession().player
        if (!player.playWhenReady || player.mediaItemCount == 0) {
            stopSelf()
        }
        super.onTaskRemoved(rootIntent)
    }
}
