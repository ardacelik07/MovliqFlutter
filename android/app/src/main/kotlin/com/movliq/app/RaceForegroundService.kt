    package com.movliq.app // Paket adınızla değiştirin

    import android.annotation.SuppressLint // MissingPermission için
    import android.app.Notification
    import android.app.NotificationChannel
    import android.app.NotificationManager
    import android.app.PendingIntent
    import android.app.Service
    import android.content.Context
    import android.content.Intent
    import android.location.Location // Konum sınıfı için import
    import android.os.Build
    import android.os.IBinder
    import android.os.Looper // Timer için
    import android.os.Handler // Timer için
    import androidx.core.app.NotificationCompat
    import io.flutter.Log // Flutter log kullanmak için
    import io.flutter.embedding.engine.FlutterEngine // Gerekirse
    import io.flutter.plugin.common.EventChannel
    import io.flutter.plugin.common.MethodChannel
    import com.google.android.gms.location.* // Konum için
    import android.hardware.* // Adım sayar için
    import kotlinx.coroutines.* // Coroutine kullanmak için (opsiyonel)
    import com.microsoft.signalr.HubConnection // SignalR için
    import com.microsoft.signalr.HubConnectionBuilder // SignalR için
    import com.microsoft.signalr.HubConnectionState // SignalR durumu için
    import java.util.concurrent.TimeUnit // Timer için
    import org.json.JSONObject // JSON için
    import com.google.gson.Gson // JSON parse için
    import com.google.gson.reflect.TypeToken // JSON List<T> için
    import java.lang.reflect.Type // JSON List<T> için
    import io.reactivex.Single // <- RxJava 2 Single için import
    import kotlinx.coroutines.rx2.await // <- RxJava 2 Completable için BU KULLANILACAK
    import androidx.localbroadcastmanager.content.LocalBroadcastManager // <- Eklendi


    class RaceForegroundService : Service(), SensorEventListener {

        companion object {
            const val ACTION_RACE_UPDATE = "com.movliq.app.RACE_UPDATE" // Intent Action
            const val EXTRA_DATA = "com.movliq.app.EXTRA_DATA"       // Intent Extra Key
        }

        private val NOTIFICATION_ID = 101
        private val CHANNEL_ID = "RaceServiceChannel"

        private var currentRoomId: Int? = null

        // Zamanlayıcı için
        private val handler = Handler(Looper.getMainLooper())
        private var timerRunnable: Runnable? = null
        private var elapsedSeconds = 0
        private var totalDurationSeconds: Int? = null // Süreli yarış için

        // Konum için
        private lateinit var fusedLocationClient: FusedLocationProviderClient
        private lateinit var locationCallback: LocationCallback
        private var totalDistanceMeters = 0.0
        private var lastLocation: Location? = null
        private var currentSpeedMetersPerSecond = 0.0f

        // Adım Sayar için
        private lateinit var sensorManager: SensorManager
        private var stepSensor: Sensor? = null
        private var totalSteps = 0
        private var initialSteps = -1 // Başlangıç adım sayısını tutmak için

         // SignalR için
        private var hubConnection: HubConnection? = null
        private val signalRJob = SupervisorJob()
        private val signalRScope = CoroutineScope(Dispatchers.IO + signalRJob) // IO thread'i
        private val gson = Gson() // JSON parse için Gson instance

        // Liderlik tablosunu tutmak için yeni değişken
        private var currentLeaderboard: List<Map<String, Any?>> = emptyList()

        // --- Service Lifecycle ---
        override fun onCreate() {
            super.onCreate()
            Log.d("RaceService", "onCreate")
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            setupLocationCallback()
        }

        override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
            Log.d("RaceService", "onStartCommand - Intent received: $intent, Extras: ${intent?.extras}") // Intent ve Ekstraları Logla
            if (intent == null) {
                Log.e("RaceService", "onStartCommand - Intent is null. Stopping service.")
                stopSelf()
                return START_NOT_STICKY
            }

            currentRoomId = intent.getIntExtra("roomId", -1).takeIf { it != -1 }
            totalDurationSeconds = intent.getIntExtra("duration", -1).takeIf { it > 0 }
            val token = intent.getStringExtra("token") // Token'ı null check sonrası al

            Log.d("RaceService", "onStartCommand - Extracted values - RoomId: $currentRoomId, Duration: $totalDurationSeconds, Token: $token") // Değerleri logla

            if (currentRoomId == null || token == null || token.isEmpty()) { // isEmpty kontrolü eklendi
                 Log.e("RaceService", "onStartCommand - RoomId or Token is null/empty after extraction. Stopping service.")
                 stopSelf()
                 return START_NOT_STICKY
            }
            Log.i("RaceService", "Service starting prerequisites met for roomId: $currentRoomId") // Başlama logu

            createNotificationChannel()
            // İlk bildirimi daha açıklayıcı yapalım
            startForeground(NOTIFICATION_ID, createNotification("Movliq Yarış Başladı!", "Veriler hesaplanıyor..."))

            // setupSignalR'ı token ile çağır
            setupSignalR(token) // Null olmayacağından eminiz
            resetState()
            startTracking()
            // Takip başladıktan hemen sonra bildirimi güncelle
            updateNotification()
            connectSignalR()

            return START_STICKY
        }

        override fun onDestroy() {
            Log.d("RaceService", "onDestroy")
            stopTracking()
            disconnectSignalR()
            signalRJob.cancel()
            super.onDestroy()
        }

        // Flutter'a veri göndermek için YENİ METOT (LocalBroadcastManager kullanır)
        private fun sendDataToFlutter(data: Map<String, Any?>) {
            val jsonString = try {
                 JSONObject(data).toString()
            } catch (e: Exception) {
                Log.e("RaceService", "Error converting data to JSON String", e)
                return // Hatalı veriyi gönderme
            }

            Log.d("RaceService", "Sending broadcast intent with action: $ACTION_RACE_UPDATE, data: $jsonString")
            val intent = Intent(ACTION_RACE_UPDATE)
            intent.putExtra(EXTRA_DATA, jsonString)
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
        }

         private fun sendErrorToFlutter(message: String) {
             val errorData = mapOf(
                 "status" to "error",
                 "error" to message
             )
              sendDataToFlutter(errorData) // Broadcast ile gönder
         }

        // --- Bildirim ---
        private fun createNotificationChannel() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val serviceChannel = NotificationChannel(
                    CHANNEL_ID,
                    "Movliq Yarış Servisi",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Movliq yarış aktivitesini takip eder"
                }
                val manager = getSystemService(NotificationManager::class.java)
                manager.createNotificationChannel(serviceChannel)
            }
        }

         private fun createNotification(title: String, text: String): Notification {
             val notificationIntent = Intent(this, MainActivity::class.java)
             val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                 PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
             } else {
                 PendingIntent.FLAG_UPDATE_CURRENT
             }
             val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingIntentFlags)

             // İkonu drawable klasöründen almayı dene (ic_stat_directions_run eklenmeli)
             val smallIconResId = try {
                 resources.getIdentifier("ic_stat_directions_run", "drawable", packageName)
             } catch (e: Exception) {
                 Log.w("RaceService", "Small icon 'ic_stat_directions_run' not found, using default.")
                 android.R.drawable.ic_dialog_info // Veya mipmap/ic_launcher
             }


             return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(if (smallIconResId != 0) smallIconResId else android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build()
        }

        private fun updateNotification() {
             // Yarış state'ini alıp metin oluştur
             val currentData = createCurrentRaceDataMap("running") // Geçici olarak running varsayalım
             val elapsedFormatted = formatDuration(currentData["elapsedSeconds"] as? Int ?: 0)
             val distanceFormatted = String.format("%.2f km", currentData["distanceKm"] as? Double ?: 0.0)
             val stepsFormatted = "${currentData["steps"] as? Int ?: 0} Adım"
             val speedFormatted = String.format("%.1f km/s", (currentData["speedKmh"] as? Double ?: 0.0))

             val notificationText = "Süre: $elapsedFormatted | Mesafe: $distanceFormatted | Adım: $stepsFormatted | Hız: $speedFormatted"
             // TODO: Kalan süre mantığını ekle (eğer totalDurationSeconds varsa)

            val notification = createNotification("Movliq Yarış Devam Ediyor", notificationText)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
             try {
                notificationManager.notify(NOTIFICATION_ID, notification)
             } catch (e: Exception) {
                 Log.e("RaceService", "Error updating notification", e)
             }
        }

         private fun formatDuration(totalSeconds: Int): String {
            val hours = TimeUnit.SECONDS.toHours(totalSeconds.toLong())
            val minutes = TimeUnit.SECONDS.toMinutes(totalSeconds.toLong()) % 60
            val seconds = totalSeconds % 60
            return if (hours > 0) {
                String.format("%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format("%02d:%02d", minutes, seconds)
            }
        }

        // --- Takip Mekanizmaları ---
        private fun startTracking() {
            Log.d("RaceService", "startTracking")
            startTimer()
            startLocationUpdates()
            startStepCounter()
        }

        private fun stopTracking() {
             Log.d("RaceService", "stopTracking")
            stopTimer()
            stopLocationUpdates()
            stopStepCounter()
        }

        private fun resetState() {
             Log.d("RaceService", "Resetting state")
            elapsedSeconds = 0
            totalDistanceMeters = 0.0
            totalSteps = 0
            initialSteps = -1
            lastLocation = null
            currentSpeedMetersPerSecond = 0.0f
             // Sıfırlanmış durumu Flutter'a gönder
            sendDataToFlutter(createCurrentRaceDataMap("idle"))
        }

        // Zamanlayıcı
        private fun startTimer() {
            stopTimer()
            timerRunnable = object : Runnable {
                override fun run() {
                    elapsedSeconds++
                    if (totalDurationSeconds != null && elapsedSeconds >= totalDurationSeconds!!) {
                        // Süre doldu
                        val finalData = createCurrentRaceDataMap("stopped")
                        Log.i("RaceService", "Timer finished. Sending final data: $finalData") // Log eklendi
                        sendDataToFlutter(finalData.filterKeys { it != "leaderboard" })
                        sendDataToSignalR(finalData) 
                        Log.d("RaceService", "Timer finished actions initiated.")
                        stopTracking()
                        disconnectSignalR()
                        stopForeground(true)
                        stopSelf()
                    } else {
                        // Periyodik güncelleme
                        val currentData = createCurrentRaceDataMap("running")
                        Log.v("RaceService", "Timer tick. Sending periodic data: $currentData") // Log eklendi (Verbose)
                        // Filtreyi kaldırıyoruz, tüm veriyi gönder
                        sendDataToFlutter(currentData)
                        sendDataToSignalR(currentData)
                        updateNotification()
                        handler.postDelayed(this, 1000)
                    }
                }
            }
            handler.postDelayed(timerRunnable!!, 1000)
            Log.i("RaceService", "Timer started.") // Log eklendi
        }

        private fun stopTimer() {
            timerRunnable?.let { handler.removeCallbacks(it) }
            timerRunnable = null
        }

        // Konum
        private fun setupLocationCallback() {
             locationCallback = object : LocationCallback() {
                 override fun onLocationResult(locationResult: LocationResult) {
                     locationResult.lastLocation?.let { location ->
                         Log.d("RaceService", "New Location: ${location.latitude}, ${location.longitude} Acc: ${location.accuracy}")
                         currentSpeedMetersPerSecond = location.speed // m/s

                         if (lastLocation != null) {
                             if(location.accuracy < 50.0) { // Daha toleranslı bir doğruluk
                                totalDistanceMeters += lastLocation!!.distanceTo(location)
                             }
                         }
                         lastLocation = location
                         // Güncelleme Timer tarafından yapılacak
                     }
                 }
             }
        }

       @SuppressLint("MissingPermission")
        private fun startLocationUpdates() {
             Log.d("RaceService", "Starting location updates")
             // TODO: isIndoorRace kontrolü eklenebilir (MainActivity'den intent ile alınabilir)
             // if (isIndoorRace) return

            val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000L) // 5sn interval
                .setMinUpdateIntervalMillis(2000L) // 2sn min interval
                .build()

            try {
               fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
            } catch (e: SecurityException) {
                 Log.e("RaceService", "Location permission not granted", e)
                 sendErrorToFlutter("Konum izni verilmedi.")
                 stopSelf()
            } catch (e: Exception) {
                 Log.e("RaceService", "Error starting location updates", e)
                 sendErrorToFlutter("Konum takibi başlatılamadı.")
                 // Servisi durdurmak yerine devam edip etmemeye karar verilebilir
            }
        }

        private fun stopLocationUpdates() {
            Log.d("RaceService", "Stopping location updates")
             try {
                fusedLocationClient.removeLocationUpdates(locationCallback)
             } catch (e: Exception) {
                 Log.e("RaceService", "Error stopping location updates", e)
             }
            lastLocation = null
            currentSpeedMetersPerSecond = 0.0f
        }

        // Adım Sayar
        private fun startStepCounter() {
            stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            if (stepSensor != null) {
                 Log.d("RaceService", "Starting step counter")
                 // SENSOR_DELAY_NORMAL yerine daha hızlı bir seçenek (UI veya GAME)
                sensorManager.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_GAME)
            } else {
                Log.w("RaceService", "Step counter sensor not available")
                // Adım sayar olmasa da devam et
            }
        }

        private fun stopStepCounter() {
            if (stepSensor != null) {
                try {
                   Log.d("RaceService", "Stopping step counter")
                   sensorManager.unregisterListener(this, stepSensor)
                } catch (e: Exception) {
                    Log.e("RaceService", "Error unregistering step counter listener", e)
                }
                initialSteps = -1
            }
        }

        override fun onSensorChanged(event: SensorEvent?) {
            if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
                val steps = event.values[0].toInt()
                if (initialSteps == -1) {
                    initialSteps = steps
                    totalSteps = 0 // Başlangıçta 0 adım
                } else {
                   // Negatif olmayacağından emin olalım
                   totalSteps = (steps - initialSteps).coerceAtLeast(0)
                }
                 // Güncelleme Timer tarafından yapılacak
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* Boş */ }


        // --- SignalR ---
        private fun setupSignalR(token: String) {
            // !! ÖNEMLİ: Token null veya boş ise buraya hiç gelmemeli (onStartCommand kontrolü sayesinde)
            Log.d("RaceService", "setupSignalR - Method called with non-null/non-empty token: $token")

            val hubUrl = "http://movliq.mehmetalicakir.tr:5000/racehub"
            Log.i("RaceService", "Setting up SignalR for URL: $hubUrl") // URL Log
            try {
                hubConnection = HubConnectionBuilder.create(hubUrl)
                    .withAccessTokenProvider(Single.defer<String> { Single.just(token) }) // Doğrudan parametre token kullanılır
                    .build()
                Log.i("RaceService", "HubConnection created.") // Başarı logu

                // !!! LOG 1: .onClosed kurulumundan ÖNCE !!!
                Log.d("RaceService", "[DEBUG] Reached point before setting up .onClosed listener.")

                hubConnection?.onClosed { error ->
                    Log.e("RaceService", "SignalR Connection closed: ${error?.message}")
                    sendErrorToFlutter("Sunucu bağlantısı kapandı: ${error?.message}")
                }

                // !!! LOG 2: .onClosed kurulumundan SONRA, .on(LeaderboardUpdated) kurulumundan ÖNCE !!!
                Log.d("RaceService", "[DEBUG] Reached point after setting up .onClosed, before .on(LeaderboardUpdated).")

                // !!! TEST: Daha genel bir dinleyici kullanalım !!!
                hubConnection?.on("LeaderboardUpdated", { args ->
                     // Gelen argümanların tipini ve içeriğini loglayalım
                     val argTypes = args?.map { it?.javaClass?.name ?: "null" }?.joinToString()
                     Log.i("RaceService", "[SignalR Event GENERIC] LeaderboardUpdated Callback TRIGGERED! Arg Count: ${args?.size}, Types: [$argTypes], Args: ${args?.contentToString()}")

                     // Şimdilik _handleLeaderboardUpdated çağırmayalım
                     // if (args != null && args.isNotEmpty() && args[0] is String) {
                     //    signalRScope.launch { _handleLeaderboardUpdated(args[0] as String) }
                     // }

                }, Array<Any?>::class.java ) // Array<Any?> olarak almayı dene

             } catch (e: Exception) {
                 Log.e("RaceService", "FATAL: Error setting up SignalR HubConnection!", e)
                 sendErrorToFlutter("Sunucu bağlantısı kurulum hatası: ${e.message}")
             }
        }

        private fun _handleLeaderboardUpdated(leaderboardJson: String?) {
            if (leaderboardJson == null || leaderboardJson.isEmpty()) {
                Log.w("RaceService", "Received empty or null leaderboard JSON.")
                return
            }
            Log.d("RaceService", "[Leaderboard Handler] Raw JSON received: $leaderboardJson") // Ham JSON'ı logla
            try {
                // JSON String mi kontrol edelim
                if (leaderboardJson.startsWith("[") && leaderboardJson.endsWith("]")) {
                     val typeToken: Type = object : TypeToken<List<Map<String, Any?>>>() {}.type
                     // !!! YENİ: Gson parse işlemini try-catch içine alalım !!!
                     try {
                         val leaderboardMapList: List<Map<String, Any?>> = gson.fromJson(leaderboardJson, typeToken)
                         Log.d("RaceService", "[Leaderboard Handler] Successfully parsed JSON: $leaderboardMapList") // Başarılı parse logu

                         // Gelen liderlik tablosunu değişkende sakla
                         this.currentLeaderboard = leaderboardMapList
                         Log.i("RaceService", "[Leaderboard Handler] Stored leaderboard update with ${leaderboardMapList.size} participants.")
                     } catch (gsonError: Exception) {
                         Log.e("RaceService", "[Leaderboard Handler] GSON parsing error", gsonError)
                         sendErrorToFlutter("Liderlik tablosu JSON parse hatası: ${gsonError.message}")
                     }
                 } else {
                    Log.w("RaceService", "[Leaderboard Handler] Received data is not a valid JSON array string: $leaderboardJson")
                 }

            } catch (e: Exception) { // Genel try-catch _handleLeaderboardUpdated için
                Log.e("RaceService", "[Leaderboard Handler] General error processing leaderboard data", e)
                sendErrorToFlutter("Liderlik tablosu verisi işlenemedi: ${e.message}")
            }
        }

        private fun connectSignalR() {
            if (hubConnection == null) {
                 Log.e("RaceService", "Cannot connect: HubConnection is null (setup failed?).")
                 return
            }
            if (currentRoomId == null) { Log.e("RaceService", "Cannot connect: roomId is null."); return }

            signalRScope.launch {
                Log.i("RaceService", "Attempting SignalR connection... (State: ${hubConnection?.connectionState})")
                if (hubConnection?.connectionState != HubConnectionState.DISCONNECTED) {
                    Log.w("RaceService", "SignalR already connected or connecting. Skipping connection attempt.")
                    return@launch
                }
                try {
                    hubConnection?.start()?.await() // Start connection and wait
                    Log.i("RaceService", "### SignalR Connected successfully! State after await: ${hubConnection?.connectionState} ###") // Log state AFTER await

                    // !!! YENİ LOG !!! Check if execution reaches here
                    Log.d("RaceService", "[DEBUG] Code execution reached after start().await()")

                    // Bağlantı başarılı olduktan sonra odaya katıl
                    if (hubConnection?.connectionState == HubConnectionState.CONNECTED && currentRoomId != null) {
                        // !!! YENİ LOG !!! Check if condition is met
                        Log.d("RaceService", "[DEBUG] Connection state is CONNECTED and roomId is not null. Proceeding to JoinRoom.")

                        Log.i("RaceService", "Attempting to join SignalR group: room-$currentRoomId")
                        try {
                            // JoinRoom metodunu çağır (await ekleyerek deneyelim)
                            hubConnection?.invoke("JoinRoom", currentRoomId)?.await()
                            Log.i("RaceService", "Successfully invoked JoinRoom for room-$currentRoomId")
                        } catch (joinError: Exception) {
                            Log.e("RaceService", "Error invoking JoinRoom for room-$currentRoomId", joinError)
                            sendErrorToFlutter("Sunucu odasına katılım sağlanamadı: ${joinError.message}")
                        }
                    } else {
                        // !!! YENİ LOG !!! Log why JoinRoom is skipped
                        Log.w("RaceService", "[DEBUG] Skipping JoinRoom. Connection state: ${hubConnection?.connectionState}, RoomId: $currentRoomId")
                    }
                    // !!! YENİ LOG !!! Check if execution reaches the end of the try block
                    Log.d("RaceService", "[DEBUG] Reached end of connectSignalR try block.")
                } catch (e: Exception) {
                    Log.e("RaceService", "### SignalR Connection failed! ###", e)
                    sendErrorToFlutter("Sunucu bağlantısı kurulamadı (arka plan): ${e.message}")
                }
            }
        }

         private fun disconnectSignalR() {
             val roomIdToLeave = currentRoomId // Kapatmadan önce ID'yi al
             if (hubConnection == null) return

             signalRScope.launch {
                 try {
                     if (hubConnection?.connectionState == HubConnectionState.CONNECTED) {
                         Log.i("RaceService", "Disconnecting SignalR for background service...")

                         // Bağlantıyı kapat
                         hubConnection?.stop()?.await()
                         Log.i("RaceService", "SignalR Disconnected for background service.")
                     }
                 } catch (e: Exception) {
                     Log.e("RaceService", "SignalR Disconnection error for background service", e)
                 }
             }
         }

        private fun sendDataToSignalR(data: Map<String, Any?>) {
             if (hubConnection?.connectionState != HubConnectionState.CONNECTED) {
                 Log.w("RaceService", "Cannot send data: SignalR not connected.")
                 return
             }
             if (currentRoomId == null) {
                 Log.w("RaceService", "Cannot send data: roomId is null.")
                 return
             }

             signalRScope.launch {
                 try {
                     val distance = data["distanceKm"]
                     val steps = data["steps"]
                     Log.d("RaceService", "Attempting to send data to SignalR: roomId=$currentRoomId, dist=$distance, steps=$steps")

                     // invoke için await kalmalı (eğer bir sonuç bekleniyorsa veya tamamlanması kritikse)
                     // Eğer invoke da Completable döndürmüyorsa, buradaki await de hata verebilir.
                     // Şimdilik invoke için await'i bırakalım.
                     hubConnection?.invoke(
                         "UpdateLocation", // VEYA "UpdateRaceProgress"?
                         currentRoomId,
                         data["distanceKm"],
                         data["steps"]
                     )?.await()
                     Log.v("RaceService", "Data sent successfully via SignalR.")

                 } catch (e: Exception) {
                     Log.e("RaceService", "Failed to send data via SignalR", e)
                 }
             }
         }

        // --- Helper Fonksiyonlar ---
         // private fun getTokenFromStorage(): String? { ... } // BU METOT SİLİNDİ

         // Yarış verilerini Map olarak oluşturan yardımcı fonksiyon
        private fun createCurrentRaceDataMap(status: String): Map<String, Any?> {
            val remainingSeconds = totalDurationSeconds?.let { it - elapsedSeconds }?.coerceAtLeast(0)
            val speedKmh = currentSpeedMetersPerSecond * 3.6

            return mapOf(
                "status" to status,
                "elapsedSeconds" to elapsedSeconds,
                "remainingSeconds" to remainingSeconds, // Null olabilir
                "distanceKm" to totalDistanceMeters / 1000.0,
                "steps" to totalSteps,
                "speedKmh" to speedKmh,
                "leaderboard" to currentLeaderboard, // Liderlik tablosunu ekle
                "error" to null // Hata yoksa null
            )
        }

        // --- onBind Method ---
        override fun onBind(intent: Intent?): IBinder? {
            // Bu servis bağlanmayı desteklemiyor, null döndür.
            return null
        }

    }