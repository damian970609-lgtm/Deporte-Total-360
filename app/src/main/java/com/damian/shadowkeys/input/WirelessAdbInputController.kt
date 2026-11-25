package com.damian.shadowkeys.input

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.flyfishxu.kadb.Kadb
import com.flyfishxu.kadb.cert.KadbCert
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

/**
 * Uses Android's own Wireless Debugging ADB service.
 *
 * This removes the separate Shizuku app, but the user must explicitly pair
 * ShadowKeys in Developer options. Only fixed, internally generated input
 * commands are sent; arbitrary shell commands are never accepted from UI.
 */
object WirelessAdbInputController {
    private const val PREFS = "shadowkeys_wireless_adb"
    private const val KEY_CERT = "client_cert"
    private const val KEY_PRIVATE_KEY = "client_private_key"
    private const val KEY_HOST = "device_host"
    private const val KEY_PORT = "device_port"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val stateLock = Any()
    private val adbLock = Any()

    @Volatile private var initialized = false
    @Volatile private var savedHost: String? = null
    @Volatile private var savedPort: Int = 0

    fun initialize(context: Context) {
        if (initialized) return
        synchronized(stateLock) {
            if (initialized) return
            val app = context.applicationContext
            val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val certText = prefs.getString(KEY_CERT, null)
            val keyText = prefs.getString(KEY_PRIVATE_KEY, null)

            if (!certText.isNullOrBlank() && !keyText.isNullOrBlank()) {
                KadbCert.set(
                    Base64.decode(certText, Base64.NO_WRAP),
                    Base64.decode(keyText, Base64.NO_WRAP)
                )
            } else {
                val identity = KadbCert.get(
                    notAfter = System.currentTimeMillis() + 10L * 365L * 24L * 60L * 60L * 1000L
                )
                prefs.edit()
                    .putString(KEY_CERT, Base64.encodeToString(identity.first, Base64.NO_WRAP))
                    .putString(KEY_PRIVATE_KEY, Base64.encodeToString(identity.second, Base64.NO_WRAP))
                    .apply()
            }

            savedHost = prefs.getString(KEY_HOST, null)
            savedPort = prefs.getInt(KEY_PORT, 0)
            initialized = true
        }
    }

    fun isReady(context: Context): Boolean {
        initialize(context)
        return !savedHost.isNullOrBlank() && savedPort in 1..65535
    }

    fun savedEndpoint(context: Context): Pair<String, Int>? {
        initialize(context)
        val host = savedHost ?: return null
        val port = savedPort
        return if (port in 1..65535) host to port else null
    }

    fun pair(
        context: Context,
        host: String,
        pairingPort: Int,
        pairingCode: String,
        callback: (Boolean, String) -> Unit
    ) {
        val app = context.applicationContext
        val normalizedHost = host.trim()
        if (!validHost(normalizedHost) || pairingPort !in 1..65535 ||
            !pairingCode.matches(Regex("\\d{6}"))) {
            post(callback, false, "Revisa la IP, el puerto de emparejamiento y el PIN de seis cifras.")
            return
        }

        Thread {
            val result = runCatching {
                initialize(app)
                synchronized(adbLock) {
                    runBlocking(Dispatchers.IO) {
                        Kadb.pair(normalizedHost, pairingPort, pairingCode)
                    }
                }
            }
            if (result.isSuccess) {
                post(callback, true, "Emparejamiento ADB correcto. Ahora introduce el puerto de conexión de Depuración inalámbrica.")
            } else {
                post(callback, false, "No se pudo emparejar: ${result.exceptionOrNull()?.message ?: "comprueba el PIN y el puerto"}")
            }
        }.start()
    }

    fun connect(
        context: Context,
        host: String,
        connectPort: Int,
        callback: (Boolean, String) -> Unit
    ) {
        val app = context.applicationContext
        val normalizedHost = host.trim()
        if (!validHost(normalizedHost) || connectPort !in 1..65535) {
            post(callback, false, "La IP o el puerto de conexión no son válidos.")
            return
        }

        Thread {
            val result = runCatching {
                initialize(app)
                synchronized(adbLock) {
                    Kadb.create(normalizedHost, connectPort, 7_000, 7_000).use { adb ->
                        val response = adb.shell("echo SHADOWKEYS_READY")
                        check(response.exitCode == 0 && response.output.contains("SHADOWKEYS_READY")) {
                            "ADB no confirmó la conexión: ${response.allOutput}"
                        }
                    }
                }
                app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString(KEY_HOST, normalizedHost)
                    .putInt(KEY_PORT, connectPort)
                    .apply()
                savedHost = normalizedHost
                savedPort = connectPort
            }
            if (result.isSuccess) {
                post(callback, true, "ADB conectado. Ya puedes abrir GTA y enviar los códigos desde el panel.")
            } else {
                post(callback, false, "No se pudo conectar: ${result.exceptionOrNull()?.message ?: "revisa el puerto y que Depuración inalámbrica siga activa"}")
            }
        }.start()
    }

    fun send(
        context: Context,
        code: String,
        callback: (Boolean, String) -> Unit
    ) {
        val keyCodes = InputKeyMapper.toKeyCodes(code)
        if (keyCodes == null || keyCodes.size > 16) {
            post(callback, false, "El código contiene caracteres no admitidos.")
            return
        }

        initialize(context)
        val host = savedHost
        val port = savedPort
        if (host.isNullOrBlank() || port !in 1..65535) {
            post(callback, false, "Primero empareja y conecta ShadowKeys en Depuración inalámbrica.")
            return
        }

        Thread {
            val result = runCatching {
                synchronized(adbLock) {
                    val keys = keyCodes.joinToString(" ")
                    val script = "for k in $keys; do input keyevent \"\$k\" || exit 1; sleep 0.12; done"
                    Kadb.create(host, port, 7_000, 10_000).use { adb ->
                        adb.shell(script).also { response ->
                            check(response.exitCode == 0) {
                                "Android rechazó la secuencia: ${response.allOutput}"
                            }
                        }
                    }
                }
            }
            if (result.isSuccess) {
                post(callback, true, "Android recibió la secuencia. Comprueba si GTA activó el truco.")
            } else {
                post(callback, false, "No se pudieron enviar las teclas: ${result.exceptionOrNull()?.message ?: "conexión ADB perdida"}")
            }
        }.start()
    }

    private fun validHost(host: String): Boolean =
        host.isNotBlank() && host.length <= 80 && host.matches(Regex("[A-Za-z0-9.:_-]+"))

    private fun post(callback: (Boolean, String) -> Unit, ok: Boolean, message: String) {
        mainHandler.post { callback(ok, message) }
    }
}
