import Flutter
import UIKit
import GoogleMaps
import HealthKit
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  // HealthKit Store instance
  private let healthStore = HKHealthStore()
  // Location manager
  private let locationManager = CLLocationManager()
  // Değişken ekleyelim: Konum takibi aktif mi?
  private var isBackgroundTrackingActive = false
  // Son konum ve zamanı tutma
  private var lastLocation: CLLocation?
  private var lastLocationTime: Date?
  // Konum izin durumu değişkenini ekle
  private var hasLocationPermission = false
  // Konum güncellemeleri zamanını kontrol etmek için timer
  private var locationRefreshTimer: Timer?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add your Google Maps API key here
    GMSServices.provideAPIKey("AIzaSyAKS4a9rCu2hRTebc2lHA9o24BthtqyLjc")
    
    // Hazırlık yapılıyor ama izin istenmeyecek
    prepareLocationServices()
    
    // Method channel'ları kur - sadece kur ama izin isteme
    setupHealthKitMethodChannel()
    setupNotificationMethodChannel()
    setupLocationMethodChannel()
    
    // İzin isteklerini kaldır
    // requestNotificationPermission() -> İzin isteği kaldırıldı
    // initializeHealthKit() -> İzin isteği kaldırıldı
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Sadece konum servislerini hazırlayan fonksiyon
  private func prepareLocationServices() {
    // Konum yöneticisini ayarla
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5 // 5 metre değişimde lokasyon güncelleme
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.showsBackgroundLocationIndicator = true
    
    // İzinleri kontrol etme veya istemeden servis ayarları yapılıyor
    print("iOS Native: Konum servisleri yapılandırıldı (izin istenmedi)")
  }
  
  // MARK: - Background Location Setup
  
  private func setupBackgroundLocationCapabilities() {
    // Konum yöneticisini ayarla
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5 // 5 metre değişimde lokasyon güncelleme
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.showsBackgroundLocationIndicator = true
    
    // Significant location changes özelliğini de etkinleştir
    // Bu, batarya tasarrufu yaparken daha uzun süre konum takibi için faydalı
    locationManager.startMonitoringSignificantLocationChanges()
    
    // İzinleri hemen kontrol et
    checkLocationPermissions()
  }
  
  // Konum izinlerini kontrol et
  private func checkLocationPermissions() {
    let authStatus = CLLocationManager.authorizationStatus()
    switch authStatus {
    case .authorizedAlways:
      print("iOS Native: Konum izni Always verilmiş")
      hasLocationPermission = true
    case .authorizedWhenInUse:
      print("iOS Native: Konum izni WhenInUse verilmiş - Always izni gerekebilir")
      hasLocationPermission = true
      // When in use izni var ama always izni yoksa, tekrar istemek mantıklı olabilir
      locationManager.requestAlwaysAuthorization()
    case .notDetermined:
      print("iOS Native: Konum izni henüz belirlenmemiş, isteniyor...")
      locationManager.requestAlwaysAuthorization()
    default:
      print("iOS Native: Konum izni verilmemiş: \(authStatus.rawValue)")
      hasLocationPermission = false
    }
  }
  
  // MARK: - Location Method Channel
  
  private func setupLocationMethodChannel() {
    let controller = window?.rootViewController as! FlutterViewController
    let locationChannel = FlutterMethodChannel(
      name: "com.movliq/location",
      binaryMessenger: controller.binaryMessenger
    )
    
    locationChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      if call.method == "enableBackgroundLocationTracking" {
        self.enableBackgroundLocationTracking()
        result(true)
      } else if call.method == "disableBackgroundLocationTracking" {
        self.disableBackgroundLocationTracking()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func enableBackgroundLocationTracking() {
    // Konum servisini kontrol et
    if CLLocationManager.locationServicesEnabled() {
      print("iOS Native: Konum servisleri açık, izin durumu kontrol ediliyor...")
      
      // İzin durumunu kontrol et ve gerekirse iste
      checkLocationPermissions()
      
      // Konum güncellemelerini başlat
      startUpdatingLocation()
      
      // Periyodik konum güncellemesi için timer başlat
      startLocationRefreshTimer()
      
      print("iOS Native: Background location tracking enabled")
    } else {
      print("iOS Native: Location services are disabled")
    }
  }
  
  private func disableBackgroundLocationTracking() {
    // Konum güncellemelerini durdur
    locationManager.stopUpdatingLocation()
    
    // Significant location changes özelliğini de durdur
    locationManager.stopMonitoringSignificantLocationChanges()
    
    // Timer'ı durdur
    locationRefreshTimer?.invalidate()
    locationRefreshTimer = nil
    
    isBackgroundTrackingActive = false
    print("iOS Native: Background location tracking disabled")
  }
  
  // Konum güncellemelerini başlat
  private func startUpdatingLocation() {
    // Eğer konum izni yoksa veya konum servisleri kapalıysa çık
    guard hasLocationPermission && CLLocationManager.locationServicesEnabled() else {
      print("iOS Native: Konum izni veya servisleri kapalı, konum güncellemeleri başlatılamadı")
      return
    }
    
    // Normal konum güncellemelerini başlat
    locationManager.startUpdatingLocation()
    
    // Significant location changes özelliğini de etkinleştir - konum takibinin daha uzun süre devam etmesine yardımcı olur
    locationManager.startMonitoringSignificantLocationChanges()
    
    isBackgroundTrackingActive = true
    print("iOS Native: Konum güncellemeleri başlatıldı")
  }
  
  // Belirli aralıklarla konum güncellemesi almak için timer başlat
  private func startLocationRefreshTimer() {
    // Önceki timer varsa durdur
    locationRefreshTimer?.invalidate()
    
    // Yeni timer - her 30 saniyede bir güncelleme yapar
    locationRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
      guard let self = self, self.isBackgroundTrackingActive else { return }
      
      // Konum güncellemelerini yeniden başlat (eğer sistem tarafından durdurulduysa)
      print("iOS Native: Timer ile konum güncellemesi isteniyor...")
      
      // Konum izni kontrolü ve yeniden başlatma
      if CLLocationManager.locationServicesEnabled() && self.hasLocationPermission {
        // Güncellemeleri kısa süreli durdur ve tekrar başlat - sistem tarafından askıya alınmış olabilir
        self.locationManager.stopUpdatingLocation()
        
        // Kısa bir gecikme ile yeniden başlat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.locationManager.startUpdatingLocation()
          print("iOS Native: Konum güncellemeleri yeniden başlatıldı")
        }
        
        // Son konumdan bu yana çok zaman geçtiyse (1 dakikadan fazla) log yazalım
        if let lastTime = self.lastLocationTime, Date().timeIntervalSince(lastTime) > 60 {
          print("iOS Native: ⚠️ Son konum güncellemesinden bu yana 1 dakikadan fazla zaman geçti!")
        }
      } else {
        print("iOS Native: Konum servisleri veya izinleri kapalı")
      }
    }
  }
  
  // MARK: - CLLocationManagerDelegate
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    
    // Son konum ve zaman bilgilerini güncelle
    lastLocation = location
    lastLocationTime = Date()
    
    // Konum güncellemesi alındı, log yaz
    print("iOS Native: Location updated - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude), Accuracy: \(location.horizontalAccuracy)m, Speed: \(location.speed)m/s")
    
    // Eğer doğruluk değeri kötüyse (100m'den fazla), log yazalım
    if location.horizontalAccuracy > 100 {
      print("iOS Native: ⚠️ Konum doğruluğu düşük: \(location.horizontalAccuracy)m")
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("iOS Native: Location manager error: \(error.localizedDescription)")
    
    // Önemli konum hatalarını daha detaylı incele
    if let clError = error as? CLError {
      switch clError.code {
      case .denied:
        print("iOS Native: Kullanıcı konum iznini reddetti")
        hasLocationPermission = false
      case .network:
        print("iOS Native: Ağ hatası nedeniyle konum alınamadı")
      default:
        print("iOS Native: CLError: \(clError.code.rawValue)")
      }
    }
  }
  
  // İzin değişikliklerini takip et
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    print("iOS Native: Konum izni değişti: \(status.rawValue)")
    
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      hasLocationPermission = true
      // İzin verildiğinde, izleme aktifse konum güncellemelerini yeniden başlat
      if isBackgroundTrackingActive {
        startUpdatingLocation()
      }
    default:
      hasLocationPermission = false
    }
  }
  
  // MARK: - Notification Methods
  
  private func setupNotificationMethodChannel() {
    let controller = window?.rootViewController as! FlutterViewController
    let notificationChannel = FlutterMethodChannel(
      name: "com.movliq/notifications",
      binaryMessenger: controller.binaryMessenger
    )
    
    notificationChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      if call.method == "requestNotificationPermission" {
        self.requestNotificationPermission(completion: { granted in
          result(granted)
        })
      } else if call.method == "checkNotificationPermission" {
        self.checkNotificationPermission(completion: { status in
          result(status)
        })
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, error in
      if let error = error {
        print("Notification permission error: \(error.localizedDescription)")
      }
      
      DispatchQueue.main.async {
        completion?(granted)
      }
    }
  }
  
  private func checkNotificationPermission(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      var status = "unknown"
      
      DispatchQueue.main.async {
        switch settings.authorizationStatus {
        case .authorized:
          status = "authorized"
        case .denied:
          status = "denied"
        case .notDetermined:
          status = "notDetermined"
        case .provisional:
          status = "provisional"
        case .ephemeral:
          status = "ephemeral"
        @unknown default:
          status = "unknown"
        }
        
        completion(status)
      }
    }
  }
  
  // Flutter ile HealthKit arasında iletişim için method channel
  private func setupHealthKitMethodChannel() {
    let controller = window?.rootViewController as! FlutterViewController
    let healthKitChannel = FlutterMethodChannel(name: "com.movliq/healthkit", 
                                             binaryMessenger: controller.binaryMessenger)
    
    healthKitChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      if call.method == "checkHealthKitAuthorization" {
        self.checkHealthKitAuthorization(result: result)
      } else if call.method == "requestHealthKitAuthorization" {
        self.requestHealthKitAuthorization(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // HealthKit izin durumunu kontrol et
  private func checkHealthKitAuthorization(result: @escaping FlutterResult) {
    if !HKHealthStore.isHealthDataAvailable() {
      result(false)
      return
    }
    
    guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
      result(false)
      return
    }
    
    let authStatus = healthStore.authorizationStatus(for: stepCountType)
    result(authStatus == .sharingAuthorized)
  }
  
  // HealthKit izni iste
  private func requestHealthKitAuthorization(result: @escaping FlutterResult) {
    if !HKHealthStore.isHealthDataAvailable() {
      result(false)
      return
    }
    
    guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
          let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
          let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
    else {
      result(false)
      return
    }
    
    let typesToRead: Set<HKObjectType> = [
      stepCount,
      distanceWalkingRunning,
      activeEnergy
    ]
    
    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
      DispatchQueue.main.async {
        if let error = error {
          print("HealthKit authorization failed: \(error.localizedDescription)")
          result(false)
        } else {
          result(success)
        }
      }
    }
  }
  
  // MARK: - Background Tasks
  
  // Uygulama arka plana geçtiğinde yapılacak işlemler için metot ekleyelim
  override func applicationDidEnterBackground(_ application: UIApplication) {
    print("iOS Native: Uygulama arka plana geçti")
    
    // Konum takibi aktifse, system tarafından durdurulmasını önlemek için yeniden başlat
    if isBackgroundTrackingActive {
      print("iOS Native: Arka planda konum takibi aktif, güncellemeler sürdürülüyor")
      
      // Konum güncellemelerini geçici olarak durdur ve yeniden başlat
      // Bu, sistemin arka plan modu geçişinde konumu takip etmeye devam etmesini sağlar
      locationManager.stopUpdatingLocation()
      
      // Kısa bir gecikme ile yeniden başlat
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.locationManager.startUpdatingLocation()
        
        // Significant location changes'i de etkinleştir
        self.locationManager.startMonitoringSignificantLocationChanges()
        
        print("iOS Native: Arka planda konum takibi yeniden başlatıldı")
      }
    }
  }
  
  // Uygulama ön plana döndüğünde yapılacak işlemler
  override func applicationWillEnterForeground(_ application: UIApplication) {
    print("iOS Native: Uygulama ön plana dönüyor")
    
    // Konum takibi aktifse, güncelleme almak için yeniden başlat
    if isBackgroundTrackingActive {
      print("iOS Native: Konum takibi ön planda yeniden başlatılıyor")
      startUpdatingLocation()
    }
  }
}