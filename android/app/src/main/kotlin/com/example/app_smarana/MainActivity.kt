package com.example.app_smarana

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"smarana/reminder_sounds",
		).setMethodCallHandler { call, result ->
			if (call.method != "listAlarmSounds") {
				result.notImplemented()
				return@setMethodCallHandler
			}

			val ringtoneManager = RingtoneManager(this).apply {
				setType(RingtoneManager.TYPE_ALARM)
			}
			val cursor = ringtoneManager.cursor
			val sounds = mutableListOf<Map<String, String>>()
			while (cursor.moveToNext()) {
				val uri = ringtoneManager.getRingtoneUri(cursor.position)
				if (uri != null) {
					sounds.add(
						mapOf(
							"name" to cursor.getString(
								RingtoneManager.TITLE_COLUMN_INDEX,
							),
							"uri" to uri.toString(),
						),
					)
				}
			}
			cursor.close()
			result.success(sounds)
		}
	}
}
