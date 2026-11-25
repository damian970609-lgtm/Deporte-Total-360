package com.damian.shadowkeys.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import android.content.Context
import android.content.pm.ServiceInfo
import com.damian.shadowkeys.data.Cheat
import com.damian.shadowkeys.data.CheatCatalog
import com.damian.shadowkeys.input.WirelessAdbInputController

class CheatOverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var bubble: View? = null
    private var panel: View? = null
    private var panelVisible = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopOverlay()
            return START_NOT_STICKY
        }
        startForegroundCompat()
        if (bubble == null) {
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            showBubble()
        }
        return START_STICKY
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "ShadowKeys flotante", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("ShadowKeys activo")
                .setContentText("Panel flotante de trucos disponible")
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("ShadowKeys activo")
                .setContentText("Panel flotante de trucos disponible")
                .setOngoing(true)
                .build()
        }

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(FOREGROUND_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(FOREGROUND_ID, notification)
        }
    }

    private fun showBubble() {
        val label = TextView(this).apply {
            text = "SK"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = rounded("#123B29", "#49E28C", 100f, 2)
        }
        val size = dp(58)
        val params = overlayParams(size, size).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(12)
            y = dp(210)
        }

        label.setOnTouchListener(object : View.OnTouchListener {
            private var startX = 0
            private var startY = 0
            private var downX = 0f
            private var downY = 0f
            private var moved = false

            override fun onTouch(view: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        startX = params.x
                        startY = params.y
                        downX = event.rawX
                        downY = event.rawY
                        moved = false
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - downX).toInt()
                        val dy = (event.rawY - downY).toInt()
                        if (kotlin.math.abs(dx) > dp(5) || kotlin.math.abs(dy) > dp(5)) moved = true
                        if (moved) {
                            params.x = (startX - dx).coerceAtLeast(0)
                            params.y = (startY + dy).coerceAtLeast(0)
                            runCatching { windowManager.updateViewLayout(label, params) }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!moved) togglePanel()
                        return true
                    }
                }
                return false
            }
        })

        bubble = label
        windowManager.addView(label, params)
    }

    private fun togglePanel() {
        if (panelVisible) {
            hidePanel()
            return
        }
        val screenHeight = resources.displayMetrics.heightPixels
        val screenWidth = resources.displayMetrics.widthPixels
        val width = (screenWidth - dp(24)).coerceAtLeast(dp(260))
        val height = (screenHeight * 0.62f).toInt().coerceAtLeast(dp(260))

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = rounded("#101713", "#315A43", 18f, 1)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "SHADOWKEYS · TRUCOS GTA"
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
        }
        val close = Button(this).apply {
            text = "Cerrar"
            setOnClickListener { hidePanel() }
        }
        header.addView(title, LinearLayout.LayoutParams(0, dp(44), 1f))
        header.addView(close, LinearLayout.LayoutParams(dp(82), dp(42)))
        container.addView(header)

        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        CheatCatalog.all.forEach { cheat -> list.addView(makeCheatRow(cheat)) }
        val scroll = ScrollView(this).apply { addView(list) }
        container.addView(scroll, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
        ))

        panel = container
        val params = overlayParams(width, height).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(12)
        }
        windowManager.addView(container, params)
        panelVisible = true
    }

    private fun makeCheatRow(cheat: Cheat): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(6))
            background = rounded("#18231C", "#294334", 10f, 1)
        }
        val title = TextView(this).apply {
            text = cheat.title
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
        }
        val code = TextView(this).apply {
            text = "${cheat.code}  ·  ${cheat.category}"
            textSize = 11f
            setTextColor(Color.rgb(73, 226, 140))
        }
        val send = Button(this).apply {
            text = "ENVIAR"
            setOnClickListener {
                WirelessAdbInputController.send(this@CheatOverlayService, cheat.code) { _, message ->
                    Toast.makeText(this@CheatOverlayService, message, Toast.LENGTH_LONG).show()
                }
            }
        }
        row.addView(title)
        row.addView(code)
        row.addView(send, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(40)
        ))
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 0, 0, dp(6))
            addView(row)
        }
    }

    private fun hidePanel() {
        panel?.let { runCatching { windowManager.removeView(it) } }
        panel = null
        panelVisible = false
    }

    private fun overlayParams(width: Int, height: Int): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            width,
            height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
    }

    private fun rounded(fill: String, stroke: String, radius: Float, strokeWidth: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.parseColor(fill))
            setStroke(dp(strokeWidth), Color.parseColor(stroke))
            cornerRadius = dp(radius.toInt()).toFloat()
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun stopOverlay() {
        hidePanel()
        bubble?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
        @Suppress("DEPRECATION")
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        hidePanel()
        bubble?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
    }

    companion object {
        const val ACTION_STOP = "com.damian.shadowkeys.STOP_OVERLAY"
        private const val CHANNEL_ID = "shadowkeys_overlay"
        private const val FOREGROUND_ID = 7351

        fun start(context: Context) {
            val intent = Intent(context, CheatOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }

        fun stop(context: Context) {
            context.startService(Intent(context, CheatOverlayService::class.java).setAction(ACTION_STOP))
        }
    }
}
