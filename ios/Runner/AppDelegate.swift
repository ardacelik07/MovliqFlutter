import Flutter
import UIKit
import GoogleMaps
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // HealthKit Store instance
  private let healthStore = HKHealthStore()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add your Google Maps API key here
    GMSServices.provideAPIKey("AIzaSyAKS4a9rCu2hRTebc2lHA9o24BthtqyLjc")
    
    // Initialize HealthKit for step counting as early as possible
    initializeHealthKit()
    
    // Register a method channel for HealthKit
    setupHealthKitMethodChannel()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Daha kapsamlı HealthKit başlatma
  private func initializeHealthKit() {
    if HKHealthStore.isHealthDataAvailable() {
      print("HealthKit data is available on this device")
      
      // Define the health data types your app needs to read - more comprehensive list
      guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
            let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
      else {
        print("HealthKit: Required data types aren't available")
        return
      }
      
      // Set of types to read
      let typesToRead: Set<HKObjectType> = [
        stepCount,
        distanceWalkingRunning,
        activeEnergy
      ]
      
      // Request authorization to access health data
      healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
        if let error = error {
          print("HealthKit authorization failed with error: \(error.localizedDescription)")
        } else if success {
          print("HealthKit authorization successful")
          // Immediately try to query steps to verify access
          self.readStepCount()
        } else {
          print("HealthKit authorization denied")
        }
      }
    } else {
      print("HealthKit is not available on this device")
    }
  }
  
  // Step verilerini okumayı dene - izin kontrolü için
  private func readStepCount() {
    guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
      print("Step count type is not available")
      return
    }
    
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    
    let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (_, result, error) in
      if let error = error {
        print("Failed to read step count: \(error.localizedDescription)")
        return
      }
      
      if let result = result, let sum = result.sumQuantity() {
        let steps = sum.doubleValue(for: HKUnit.count())
        print("Total steps today: \(steps)")
      } else {
        print("No step count data available")
      }
    }
    
    healthStore.execute(query)
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
}