package com.damian.shadowkeys.input

import android.os.IBinder
import android.os.Looper
import android.os.Handler

object ShizukuInputController {
    @Volatile
    private var remote: IInputService? = null

    fun attach(binder: IBinder?) {
        remote = if (binder != null && binder.pingBinder()) {
            IInputService.Stub.asInterface(binder)
        } else {
            null
        }
    }

    fun isReady(): Boolean = remote?.asBinder()?.pingBinder() == true

    fun send(code: String, callback: (Boolean, String) -> Unit) {
        val keyCodes = InputKeyMapper.toKeyCodes(code)
        if (keyCodes == null) {
            callback(false, "El código contiene caracteres no admitidos.")
            return
        }

        val service = remote
        if (service == null || service.asBinder()?.pingBinder() != true) {
            callback(false, "Shizuku no está conectado. Abre ShadowKeys y conecta el servicio.")
            return
        }

        Thread {
            val result = try {
                service.sendKeyCodes(keyCodes, 95)
            } catch (error: Exception) {
                -10
            }

            val message = when {
                result == keyCodes.size -> "Teclas enviadas por el servicio ADB. Comprueba el resultado dentro del juego."
                result == -3 -> "Android rechazó la inyección de teclas."
                else -> "No se pudieron enviar las teclas (código $result)."
            }
            Handler(Looper.getMainLooper()).post {
                callback(result == keyCodes.size, message)
            }
        }.start()
    }
}
