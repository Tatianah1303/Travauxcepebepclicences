package com.example.frontend
import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val canal = "cisco/enregistrer_fichier"
    private val codeDemande = 7421
    private var resultatEnAttente: MethodChannel.Result? = null
    private var octetsEnAttente: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { appel, resultat ->
                if (appel.method != "enregistrer") {
                    resultat.notImplemented()
                    return@setMethodCallHandler
                }
                if (resultatEnAttente != null) {
                    resultat.error("occupe", "Un enregistrement est déjà en cours", null)
                    return@setMethodCallHandler
                }
                val octets = appel.argument<ByteArray>("octets")
                if (octets == null) {
                    resultat.error("arguments", "Contenu du fichier manquant", null)
                    return@setMethodCallHandler
                }
                resultatEnAttente = resultat
                octetsEnAttente = octets
                val intention = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = appel.argument<String>("mime") ?: "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, appel.argument<String>("nom") ?: "fichier")
                }
                @Suppress("DEPRECATION")
                startActivityForResult(intention, codeDemande)
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != codeDemande) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val resultat = resultatEnAttente
        val octets = octetsEnAttente
        resultatEnAttente = null
        octetsEnAttente = null
        if (resultat == null) return

        val uri: Uri? = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null && octets != null) {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(octets) }
                resultat.success(uri.toString())
            } catch (e: Exception) {
                resultat.error("ecriture", e.message, null)
            }
        } else {
            resultat.success(null) // fenêtre fermée sans choisir
        }
    }
}
