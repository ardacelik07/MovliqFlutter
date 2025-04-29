    package com.movliq.app // Paket adınızla değiştirin

    import io.flutter.embedding.android.FlutterActivity
    import io.flutter.embedding.engine.FlutterEngine
    import io.flutter.plugin.common.MethodChannel
    import android.content.Intent
    import android.os.Build
    import android.util.Log
    import android.content.IntentFilter
    import androidx.localbroadcastmanager.content.LocalBroadcastManager
    import android.content.BroadcastReceiver
    import android.content.Context


    class MainActivity: FlutterActivity() {
        private val CONTROL_CHANNEL = "com.movliq.app/race_control"
        private val EVENT_CHANNEL = "com.movliq.app/race_updates"
        private var raceServiceIntent: Intent? = null
        private var eventChannel: EventChannel? = null
        private var eventSink: EventChannel.EventSink? = null
        private var broadcastReceiver: BroadcastReceiver? = null

        override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
            super.configureFlutterEngine(flutterEngine)
            Log.i("MainActivity", "Configuring Flutter Engine")

            raceServiceIntent = Intent(this, RaceForegroundService::class.java)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL).setMethodCallHandler {
                call, result ->
                when (call.method) {
                    "start" -> {
                        val duration = call.argument<Int>("duration")
                        val roomId = call.argument<Int>("roomId")
                        if (roomId == null) {
                             Log.e("MainActivity", "roomId is null, cannot start service.")
                             result.error("INVALID_ARGUMENT", "roomId cannot be null", null)
                             return@setMethodCallHandler
                        }
                        Log.d("MainActivity", "Starting service via MethodChannel with roomId: $roomId, duration: $duration")
                        raceServiceIntent?.putExtra("duration", duration)
                        raceServiceIntent?.putExtra("roomId", roomId)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(raceServiceIntent)
                        } else {
                            startService(raceServiceIntent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        Log.d("MainActivity", "Stopping service via MethodChannel")
                         if (raceServiceIntent != null) {
                            stopService(raceServiceIntent)
                         }
                         result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

            eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.i("MainActivity", "EventChannel onListen - Setting up BroadcastReceiver")
                    eventSink = events
                    setupBroadcastReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    Log.i("MainActivity", "EventChannel onCancel - Tearing down BroadcastReceiver")
                    eventSink = null
                    teardownBroadcastReceiver()
                }
            })
        }

        private fun setupBroadcastReceiver() {
            if (broadcastReceiver == null) {
                broadcastReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        val action = intent?.action
                        Log.d("MainActivity", "BroadcastReceiver onReceive - Action: $action")
                        if (action == RaceForegroundService.ACTION_RACE_UPDATE) {
                            val dataJson = intent.getStringExtra(RaceForegroundService.EXTRA_DATA)
                            if (dataJson != null) {
                                Log.i("MainActivity", "BroadcastReceiver received data. Forwarding to Flutter: $dataJson")
                                if (eventSink != null) {
                                   eventSink?.success(dataJson)
                                } else {
                                    Log.w("MainActivity", "EventSink is null, cannot forward data from BroadcastReceiver.")
                                }
                            } else {
                                Log.w("MainActivity", "BroadcastReceiver received null data.")
                            }
                        }
                    }
                }
                LocalBroadcastManager.getInstance(this).registerReceiver(
                    broadcastReceiver!!, IntentFilter(RaceForegroundService.ACTION_RACE_UPDATE)
                )
                Log.i("MainActivity", "BroadcastReceiver registered for action: ${RaceForegroundService.ACTION_RACE_UPDATE}")
            }
        }

        private fun teardownBroadcastReceiver() {
            if (broadcastReceiver != null) {
                LocalBroadcastManager.getInstance(this).unregisterReceiver(broadcastReceiver!!)
                broadcastReceiver = null
                Log.i("MainActivity", "BroadcastReceiver unregistered.")
            }
        }

        override fun onDestroy() {
            teardownBroadcastReceiver()
            super.onDestroy()
            Log.i("MainActivity", "onDestroy - Receiver torn down.")
        }
    }
