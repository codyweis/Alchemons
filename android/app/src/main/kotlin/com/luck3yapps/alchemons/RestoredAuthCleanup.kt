package com.luck3yapps.alchemons

import android.content.Context
import android.util.Log
import java.io.File
import java.security.KeyStore

/**
 * Firebase Auth keeps the signed-in user in shared prefs, encrypted with a key
 * in the Android Keystore. That key goes with an uninstall and is never backed
 * up, but Android's backup restored the prefs on a reinstall; Firebase could
 * then neither read nor replace them, so every sign-in lasted only until the
 * app closed. The backup rules stop new cases; this clears the files on phones
 * it already happened to, so the next sign-in sticks.
 *
 * Runs before Flutter starts, so Firebase Auth hasn't read the files yet.
 */
object RestoredAuthCleanup {
    private const val CRYPTO = "com.google.firebase.auth.api.crypto."
    private const val STORE = "com.google.firebase.auth.api.Store."
    private const val KEY = "firebear_main_key_id_for_storage_crypto."

    fun run(context: Context) {
        try {
            val prefs = File(context.applicationInfo.dataDir, "shared_prefs")
            @Suppress("DEPRECATION")
            val installed = context.packageManager
                .getPackageInfo(context.packageName, 0).firstInstallTime
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            prefs.listFiles()?.forEach { crypto ->
                if (!crypto.name.startsWith(CRYPTO) || !crypto.name.endsWith(".xml")) {
                    return@forEach
                }
                val suffix = crypto.name.removePrefix(CRYPTO).removeSuffix(".xml")
                // Only files an earlier install wrote, whose key is gone: a
                // keyset this install made is never touched.
                if (crypto.lastModified() >= installed || keyStore.containsAlias(KEY + suffix)) {
                    return@forEach
                }
                crypto.delete()
                File(prefs, "$STORE$suffix.xml").delete()
                Log.i("Alchemons", "Cleared restored Firebase Auth files ($suffix)")
            }
        } catch (error: Exception) {
            Log.w("Alchemons", "Restored Firebase Auth check skipped", error)
        }
    }
}
