package it.kybo.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

// FlutterFragmentActivity (instead of FlutterActivity) implements ActivityResultRegistryOwner,
// required by health 13.x to register the Health Connect permission launcher before onStart().
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "it.kybo.app/timezone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getLocalTimezone") {
                result.success(TimeZone.getDefault().id)
            } else {
                result.notImplemented()
            }
        }
    }
}