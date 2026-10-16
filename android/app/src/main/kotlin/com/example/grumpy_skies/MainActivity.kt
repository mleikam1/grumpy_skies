package com.example.grumpy_skies

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var planCast: PlanCastPlugin? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        planCast = PlanCastPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        planCast?.permissionResult(requestCode)
    }
    override fun onPause() { planCast?.pause(); super.onPause() }
    override fun onResume() { super.onResume(); planCast?.resume() }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); planCast?.acceptIntent(intent) }
    override fun onDestroy() { planCast?.dispose(); super.onDestroy() }
}
