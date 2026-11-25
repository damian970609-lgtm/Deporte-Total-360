package com.damian.shadowkeys

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.damian.shadowkeys.data.Cheat
import com.damian.shadowkeys.data.CheatCatalog
import com.damian.shadowkeys.input.IInputService
import com.damian.shadowkeys.input.InputUserService
import com.damian.shadowkeys.input.ShizukuInputController
import com.damian.shadowkeys.overlay.CheatOverlayService
import rikka.shizuku.Shizuku

class MainActivity : Activity() {
    private lateinit var statusText: TextView
    private lateinit var gameText: TextView
    private lateinit var results: LinearLayout
    private lateinit var searchField: EditText
    private lateinit var testField: EditText
    private var selectedCategory: String? = null
    private var serviceBound = false

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == REQUEST_SHIZUKU && grantResult == PackageManager.PERMISSION_GRANTED) {
            bindInputService()
        } else if (requestCode == REQUEST_SHIZUKU) {
            updateStatus("Permiso de Shizuku denegado. No se enviaron teclas.")
        }
    }

    private val binderListener = Shizuku.OnBinderReceivedListener {
        runOnUiThread { connectShizukuIfAllowed() }
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        ShizukuInputController.attach(null)
        runOnUiThread { updateStatus("Shizuku se detuvo. Reinícialo y vuelve a conectar.") }
    }

    private val inputServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            ShizukuInputController.attach(binder)
            runOnUiThread {
                updateStatus(
                    if (ShizukuInputController.isReady()) {
                        "Conectado. El envío se ejecuta mediante el servicio ADB de Shizuku."
                    } else {
                        "El servicio de entrada no respondió. Vuelve a conectar Shizuku."
                    }
                )
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            ShizukuInputController.attach(null)
            serviceBound = false
            runOnUiThread { updateStatus("Servicio de entrada desconectado.") }
        }
    }

    private val inputServiceArgs by lazy {
        Shizuku.UserServiceArgs(
            ComponentName(packageName, InputUserService::class.java.name)
        ).daemon(false).tag("shadowkeys-gta-input").version(1).processNameSuffix("input")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(9, 13, 11)
        window.navigationBarColor = Color.rgb(9, 13, 11)
        Shizuku.addBinderReceivedListenerSticky(binderListener)
        Shizuku.addBinderDeadListener(binderDeadListener)
        Shizuku.addRequestPermissionResultListener(permissionListener)
        buildScreen()
        refreshGameStatus()
        connectShizukuIfAllowed()
    }

    override fun onResume() {
        super.onResume()
        refreshGameStatus()
        connectShizukuIfAllowed()
    }

    override fun onDestroy() {
        super.onDestroy()
        Shizuku.removeBinderReceivedListener(binderListener)
        Shizuku.removeBinderDeadListener(binderDeadListener)
        Shizuku.removeRequestPermissionResultListener(permissionListener)
        if (serviceBound) {
            runCatching {
                Shizuku.unbindUserService(inputServiceArgs, inputServiceConnection, true)
            }
            serviceBound = false
        }
        ShizukuInputController.attach(null)
    }

    private fun buildScreen() {
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(18), dp(16), dp(30))
            setBackgroundColor(Color.rgb(9, 13, 11))
        }

        val title = text("SHADOWKEYS", 28f, Color.rgb(73, 226, 140), true)
        title.letterSpacing = 0.08f
        page.addView(title)
        page.addView(text("GTA SAN ANDREAS · EDICIÓN MÓVIL", 12f, Color.LTGRAY, true))
        page.addView(text("Objetivo de prueba: Rockstar 2.11.311 · Android 15", 12f, Color.GRAY, false).apply {
            setPadding(0, dp(4), 0, dp(12))
        })

        val statusCard = panel()
        statusText = text("Comprobando Shizuku…", 13f, Color.WHITE, true)
        statusCard.addView(text("ESTADO DE ENTRADA", 10f, Color.rgb(73, 226, 140), true))
        statusCard.addView(statusText.apply { setPadding(0, dp(6), 0, 0) })
        page.addView(statusCard, marginParams(bottom = 10))

        gameText = text("Comprobando GTA San Andreas…", 12f, Color.LTGRAY, false)
        page.addView(gameText, marginParams(bottom = 10))

        val actions = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        actions.addView(actionButton("CONECTAR SHIZUKU") { connectShizukuIfAllowed(userInitiated = true) }, marginParams(bottom = 7))
        actions.addView(actionButton("DESCARGAR / ABRIR SHIZUKU") { openShizuku() }, marginParams(bottom = 7))
        actions.addView(actionButton("ACTIVAR PANEL FLOTANTE") { enableOverlay() }, marginParams(bottom = 7))
        actions.addView(actionButton("DETENER PANEL FLOTANTE") { CheatOverlayService.stop(this) }, marginParams(bottom = 7))
        actions.addView(actionButton("ABRIR GTA SAN ANDREAS") { openGta() }, marginParams(bottom = 12))
        page.addView(actions)

        val testCard = panel()
        testCard.addView(text("PRUEBA DEL ENVÍO", 12f, Color.rgb(73, 226, 140), true))
        testCard.addView(text(
            "Primero prueba que Android reciba las teclas aquí. Pulsa el campo y después Enviar TEST123.",
            11f, Color.LTGRAY, false
        ).apply { setPadding(0, dp(5), 0, dp(8)) })
        testField = EditText(this).apply {
            hint = "El texto de prueba aparecerá aquí"
            setHintTextColor(Color.GRAY)
            setTextColor(Color.WHITE)
            textSize = 14f
            singleLine = true
            background = rounded("#0B100D", "#315A43", 10)
            setPadding(dp(10), dp(8), dp(10), dp(8))
        }
        testCard.addView(testField, marginParams(bottom = 8))
        testCard.addView(actionButton("ENVIAR TEST123") {
            testField.requestFocus()
            testField.setSelection(testField.text.length)
            sendCode("TEST123")
        })
        page.addView(testCard, marginParams(bottom = 12))

        page.addView(text("CATÁLOGO DE TRUCOS · 83 CÓDIGOS MÓVILES", 15f, Color.WHITE, true).apply {
            setPadding(0, dp(6), 0, dp(8))
        })

        searchField = EditText(this).apply {
            hint = "Buscar truco o contraseña…"
            setHintTextColor(Color.GRAY)
            setTextColor(Color.WHITE)
            textSize = 14f
            singleLine = true
            background = rounded("#151D18", "#315A43", 12)
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        page.addView(searchField, marginParams(bottom = 8))

        val categoryScroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
        }
        val categoryRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val categoryNames = listOf("Todos") + CheatCatalog.categories
        categoryNames.forEach { name ->
            val chip = actionButton(name) {
                selectedCategory = if (name == "Todos") null else name
                renderCheats()
            }.apply {
                textSize = 11f
                minHeight = dp(38)
                setPadding(dp(10), 0, dp(10), 0)
            }
            categoryRow.addView(chip, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, dp(38)
            ).apply { rightMargin = dp(6) })
        }
        categoryScroll.addView(categoryRow)
        page.addView(categoryScroll, marginParams(bottom = 10))

        results = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        page.addView(results)

        page.addView(text(
            "AVISO: los trucos pueden desactivar logros o afectar misiones. No guardes una partida principal con disturbios o peatones agresivos activos. La lista corresponde a la edición móvil; no se ha confirmado todavía qué códigos acepta la compilación 2.11.311.",
            11f, Color.LTGRAY, false
        ).apply { setPadding(0, dp(14), 0, 0) })

        searchField.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = renderCheats()
            override fun afterTextChanged(s: Editable?) = Unit
        })

        val pageScroll = ScrollView(this).apply {
            isFillViewport = true
            addView(page)
        }
        setContentView(pageScroll)
        renderCheats()
    }

    private fun connectShizukuIfAllowed(userInitiated: Boolean = false) {
        if (!Shizuku.pingBinder()) {
            if (userInitiated) updateStatus("Shizuku no está iniciado. Abre Shizuku y pulsa Iniciar.")
            else updateStatus("Shizuku no detectado. Consulta la guía de conexión.")
            return
        }

        try {
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                if (userInitiated || !Shizuku.shouldShowRequestPermissionRationale()) {
                    Shizuku.requestPermission(REQUEST_SHIZUKU)
                    updateStatus("Autoriza ShadowKeys en la ventana de Shizuku.")
                } else {
                    updateStatus("Falta autorizar ShadowKeys desde Shizuku.")
                }
                return
            }
            if (!serviceBound) {
                Shizuku.bindUserService(inputServiceArgs, inputServiceConnection)
                serviceBound = true
                updateStatus("Conectando el servicio de entrada…")
            } else {
                updateStatus("Servicio de entrada conectado.")
            }
        } catch (error: Exception) {
            serviceBound = false
            updateStatus("No se pudo conectar: ${error.message ?: "error de Shizuku"}")
        }
    }

    private fun updateStatus(message: String) {
        if (::statusText.isInitialized) statusText.text = message
    }

    private fun refreshGameStatus() {
        if (!::gameText.isInitialized) return
        val version = try {
            val info = if (Build.VERSION.SDK_INT >= 33) {
                packageManager.getPackageInfo(GTA_PACKAGE, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(GTA_PACKAGE, 0)
            }
            info.versionName ?: "versión no indicada"
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        gameText.text = if (version == null) {
            "GTA San Andreas: no detectado con el paquete Rockstar esperado."
        } else {
            "GTA detectado · ${version}. La versión de destino para las pruebas es 2.11.311."
        }
    }

    private fun openShizuku() {
        val launch = packageManager.getLaunchIntentForPackage(SHIZUKU_PACKAGE)
        if (launch != null) {
            startActivity(launch)
        } else {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(SHIZUKU_DOWNLOAD)))
        }
    }

    private fun enableOverlay() {
        if (!Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            Toast.makeText(this, "Activa Permitir mostrar sobre otras aplicaciones y vuelve a ShadowKeys.", Toast.LENGTH_LONG).show()
            return
        }
        runCatching {
            CheatOverlayService.start(this)
            Toast.makeText(this, "Panel flotante activado. El botón SK se puede mover.", Toast.LENGTH_SHORT).show()
        }.onFailure {
            Toast.makeText(this, "No se pudo iniciar el panel: ${it.message}", Toast.LENGTH_LONG).show()
        }
    }

    private fun openGta() {
        val launch = packageManager.getLaunchIntentForPackage(GTA_PACKAGE)
        if (launch == null) {
            Toast.makeText(this, "No encuentro GTA San Andreas con el paquete Rockstar.", Toast.LENGTH_LONG).show()
        } else {
            startActivity(launch)
        }
    }

    private fun renderCheats() {
        if (!::results.isInitialized) return
        results.removeAllViews()
        val filtered = CheatCatalog.search(searchField.text?.toString().orEmpty(), selectedCategory)
        if (filtered.isEmpty()) {
            results.addView(text("No hay trucos que coincidan con la búsqueda.", 13f, Color.LTGRAY, false))
            return
        }
        filtered.forEach { cheat -> results.addView(cheatCard(cheat), marginParams(bottom = 8)) }
    }

    private fun cheatCard(cheat: Cheat): View {
        val card = panel()
        val titleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        titleRow.addView(text(cheat.title, 14f, Color.WHITE, true), LinearLayout.LayoutParams(0, -2, 1f))
        titleRow.addView(text(cheat.category.uppercase(), 9f, Color.rgb(73, 226, 140), true))
        card.addView(titleRow)
        card.addView(text(cheat.code, 19f, Color.rgb(73, 226, 140), true).apply {
            setPadding(0, dp(4), 0, dp(3))
            letterSpacing = 0.12f
        })
        card.addView(text(cheat.description, 11f, Color.LTGRAY, false))
        cheat.warning?.let {
            card.addView(text("PRECAUCIÓN: $it", 10f, Color.rgb(255, 186, 90), true).apply {
                setPadding(0, dp(5), 0, 0)
            })
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(5), 0, 0)
        }
        buttons.addView(actionButton("COPIAR") { copyCode(cheat.code) }, LinearLayout.LayoutParams(0, dp(40), 1f).apply {
            rightMargin = dp(6)
        })
        buttons.addView(actionButton("ENVIAR") { sendCode(cheat.code) }, LinearLayout.LayoutParams(0, dp(40), 1f))
        card.addView(buttons)
        return card
    }

    private fun sendCode(code: String) {
        if (!ShizukuInputController.isReady()) {
            Toast.makeText(this, "Primero inicia Shizuku y conecta el servicio ADB.", Toast.LENGTH_LONG).show()
            updateStatus("Sin conexión de inyección. Comprueba Shizuku y vuelve a conectar.")
            return
        }
        ShizukuInputController.send(code) { _, message ->
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }

    private fun copyCode(code: String) {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Código GTA San Andreas", code))
        Toast.makeText(this, "Código copiado: $code", Toast.LENGTH_SHORT).show()
    }

    private fun panel(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(12), dp(10), dp(12), dp(10))
        background = rounded("#151D18", "#294334", 12)
    }

    private fun text(value: String, size: Float, color: Int, bold: Boolean): TextView {
        return TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }
    }

    private fun actionButton(label: String, action: () -> Unit): Button {
        return Button(this).apply {
            text = label
            textSize = 12f
            isAllCaps = false
            setTextColor(Color.WHITE)
            background = rounded("#1E3A2A", "#49E28C", 10)
            setOnClickListener { action() }
        }
    }

    private fun rounded(fill: String, stroke: String, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.parseColor(fill))
            setStroke(dp(1), Color.parseColor(stroke))
            cornerRadius = dp(radius).toFloat()
        }
    }

    private fun marginParams(bottom: Int): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(bottom) }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val REQUEST_SHIZUKU = 1811
        private const val GTA_PACKAGE = "com.rockstargames.gtasa"
        private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
        private const val SHIZUKU_DOWNLOAD = "https://shizuku.rikka.app/download/"
    }
}
