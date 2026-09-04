package com.creditcore.creditcalc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        val product = NotificationChannel(
            "creditcore_product",
            "Aggiornamenti CreditCore",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Avvisi su novità, corsi e funzioni CreditCore"
            setShowBadge(true)
        }
        val support = NotificationChannel(
            "creditcore_support",
            "Assistenza e community",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Risposte assistenza e community"
            setShowBadge(true)
        }
        manager.createNotificationChannel(product)
        manager.createNotificationChannel(support)
    }
}
