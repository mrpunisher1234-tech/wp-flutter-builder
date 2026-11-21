package com.wptoflutter.wp_flutter_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // تنظیم ۲۴ | اشتراک‌گذاری محصول | شیت بومی سیستم (ACTION_SEND + chooser)
    // بدون هیچ پکیج خارجی | خروجی false یعنی شیت باز نشد تا فلاتر فالبک
    // کپی به کلیپ‌بورد را اجرا کند.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "wptf_share",
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                try {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        if (title.isNotEmpty()) {
                            putExtra(Intent.EXTRA_SUBJECT, title)
                        }
                    }
                    val chooser = Intent.createChooser(
                        intent,
                        title.ifEmpty { "اشتراک‌گذاری" },
                    )
                    startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
