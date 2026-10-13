package com.mousty.gymbro

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * With the app in background FCM shows the notification itself; with the app open it
 * lands here and goes to Dart, which shows its own banner. Token refreshes go to Dart too.
 */
class PushMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        listener?.invoke("onMessage", mapOf(
            "title" to message.notification?.title,
            "body" to message.notification?.body,
            "data" to message.data,
        ))
    }

    override fun onNewToken(token: String) {
        listener?.invoke("onToken", token)
    }

    companion object {
        /** Set by MainActivity while the Flutter engine is running. */
        @Volatile
        var listener: ((String, Any?) -> Unit)? = null
    }
}
