package com.damian.shadowkeys.input

import android.os.RemoteException
import androidx.annotation.Keep

/**
 * Shizuku UserService. It runs with the ADB shell UID when Shizuku is started
 * through Android wireless debugging, which is what authorizes global key injection.
 */
@Keep
class InputUserService : IInputService.Stub() {
    override fun sendKeyCodes(keyCodes: IntArray, delayMs: Int): Int {
        if (keyCodes.isEmpty() || keyCodes.size > 32) return -1
        val delay = delayMs.coerceIn(50, 250).toLong()

        return try {
            for (keyCode in keyCodes) {
                if (keyCode !in 7..16 && keyCode !in 29..54) return -2
                val process = Runtime.getRuntime().exec(
                    arrayOf("/system/bin/input", "keyevent", keyCode.toString())
                )
                val exitCode = process.waitFor()
                if (exitCode != 0) return -3
                Thread.sleep(delay)
            }
            keyCodes.size
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            -4
        } catch (error: Exception) {
            -5
        }
    }

    override fun exit() {
        destroy()
    }

    override fun destroy() {
        // Required UserService lifecycle hook. It is called by Shizuku when unbound.
        System.exit(0)
    }
}
