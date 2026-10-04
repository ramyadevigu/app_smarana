package com.example.app_smarana

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
	private var alarmRuntimeChannel: MethodChannel? = null
	private val alarmEventReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context, intent: Intent) {
			when (intent.action) {
				AlarmScheduler.ACTION_RINGING -> {
					applyAlarmWindowBehavior(true)
					val reminderId = intent.getStringExtra("reminderId") ?: return
					alarmRuntimeChannel?.invokeMethod(
						"alarmRinging",
						JSONObject().put("reminderId", reminderId).toString(),
					)
				}
				AlarmScheduler.ACTION_STOPPED -> {
					applyAlarmWindowBehavior(false)
					val reminderId = intent.getStringExtra("reminderId") ?: return
					alarmRuntimeChannel?.invokeMethod(
						"alarmStopped",
						JSONObject().put("reminderId", reminderId).toString(),
					)
				}
			}
		}
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		registerAlarmEventReceiver()
		applyAlarmWindowBehavior(
			intent?.action == AlarmScheduler.ACTION_OPEN_ALARM ||
				AlarmScheduler.activeAlarmId(this) != null,
		)
	}

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

		alarmRuntimeChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"smarana/alarm_runtime",
		).also { channel ->
			channel.setMethodCallHandler { call, result ->
				when (call.method) {
					"ensureFullScreenIntentPermission" -> {
						result.success(ensureFullScreenIntentPermission())
					}
					"scheduleAlarm" -> {
						val id = call.argument<Int>("id")
						val triggerAtMillis = call.argument<Long>("triggerAtMillis")
						val reminderJson = call.argument<String>("reminderJson")
						if (id == null || triggerAtMillis == null || reminderJson == null) {
							result.error("invalid_alarm", "Missing alarm schedule data.", null)
							return@setMethodCallHandler
						}
						try {
							AlarmScheduler.schedule(
								this,
								id,
								triggerAtMillis,
								reminderJson,
								call.argument<Boolean>("isSnooze") == true,
							)
							result.success(null)
						} catch (error: SecurityException) {
							Log.e("TotalRemindersAlarm", "Exact alarm scheduling was denied.", error)
							result.error(
								"alarm_permission_denied",
								"Allow exact alarms for Total Reminders.",
								null,
							)
						} catch (error: IllegalStateException) {
							Log.e("TotalRemindersAlarm", "Unable to schedule alarm.", error)
							result.error("alarm_schedule_failed", error.message, null)
						}
					}
					"pendingSnoozeTime" -> {
						val id = call.argument<Int>("id")
						if (id == null) {
							result.error("invalid_alarm", "Missing alarm ID.", null)
						} else {
							result.success(AlarmScheduler.pendingSnoozeTime(this, id))
						}
					}
					"cancelAlarm" -> {
						val id = call.argument<Int>("id")
						if (id == null) {
							result.error("invalid_alarm", "Missing alarm ID.", null)
						} else {
							AlarmScheduler.cancel(this, id)
							result.success(null)
						}
					}
					"stopAlarm" -> {
						val id = call.argument<Int>("id")
						if (id == null) {
							result.error("invalid_alarm", "Missing alarm ID.", null)
						} else {
							AlarmScheduler.requestStop(this, id)
							result.success(null)
						}
					}
					"snoozeAlarm" -> {
						val id = call.argument<Int>("id")
						if (id == null) {
							result.error("invalid_alarm", "Missing alarm ID.", null)
						} else {
							AlarmScheduler.requestSnooze(this, id)
							result.success(null)
						}
					}
					"activeAlarmReminderId" -> {
						val reminderId = AlarmScheduler.activeReminderId(this)
						applyAlarmWindowBehavior(reminderId != null)
						result.success(reminderId)
					}
					else -> result.notImplemented()
				}
			}
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		if (intent.action == AlarmScheduler.ACTION_OPEN_ALARM) {
			applyAlarmWindowBehavior(true)
			val reminderId = AlarmScheduler.activeReminderId(this)
			if (reminderId != null) {
				alarmRuntimeChannel?.invokeMethod(
					"alarmRinging",
					JSONObject().put("reminderId", reminderId).toString(),
				)
			}
		}
	}

	override fun onDestroy() {
		unregisterReceiver(alarmEventReceiver)
		alarmRuntimeChannel?.setMethodCallHandler(null)
		alarmRuntimeChannel = null
		super.onDestroy()
	}

	private fun registerAlarmEventReceiver() {
		val filter = IntentFilter().apply {
			addAction(AlarmScheduler.ACTION_RINGING)
			addAction(AlarmScheduler.ACTION_STOPPED)
		}
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			registerReceiver(alarmEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
		} else {
			@Suppress("DEPRECATION")
			registerReceiver(alarmEventReceiver, filter)
		}
	}

	private fun ensureFullScreenIntentPermission(): Boolean {
		if (Build.VERSION.SDK_INT < 34) {
			return true
		}
		val notificationManager = getSystemService(NotificationManager::class.java)
		if (notificationManager.canUseFullScreenIntent()) {
			return true
		}
		return try {
			startActivity(
				Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
					.setData(Uri.parse("package:$packageName")),
			)
			false
		} catch (error: ActivityNotFoundException) {
			Log.e(
				"TotalRemindersAlarm",
				"Android full-screen intent settings are unavailable.",
				error,
			)
			false
		}
	}

	private fun applyAlarmWindowBehavior(active: Boolean) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
			setShowWhenLocked(active)
			setTurnScreenOn(active)
		}
		if (active) {
			window.addFlags(
				WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
					WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
					WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
			)
		} else {
			window.clearFlags(
				WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
					WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
					WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
			)
		}
	}
}
