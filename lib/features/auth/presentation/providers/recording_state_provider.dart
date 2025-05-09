import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple state notifier to track if the RecordScreen is currently recording.
/// It also holds an optional callback to trigger cancellation from outside.
class RecordStateNotifier extends StateNotifier<bool> {
  RecordStateNotifier() : super(false); // Initial state: not recording

  Function? _cancelCallback;

  /// Starts recording and stores the cancellation callback.
  void startRecording(Function cancelCallback) {
    _cancelCallback = cancelCallback;
    state = true;
    print('RecordStateNotifier: Recording STARTED');
  }

  /// Stops recording normally (e.g., when finished and saved).
  void stopRecording() {
    _cancelCallback = null; // Clear callback on normal stop
    state = false;
    print('RecordStateNotifier: Recording STOPPED (normally)');
  }

  /// Cancels the recording by invoking the stored callback and resets state.
  void cancelRecording() {
    if (state == true && _cancelCallback != null) {
      print('RecordStateNotifier: Attempting to CANCEL recording...');
      try {
        _cancelCallback!(); // Execute the cancellation logic from RecordScreen
        print('RecordStateNotifier: Cancel callback executed.');
      } catch (e) {
        print('RecordStateNotifier: Error executing cancel callback: $e');
      } finally {
        _cancelCallback = null; // Clear callback after attempting cancel
        state = false; // Set state to not recording
        print(
            'RecordStateNotifier: Recording state set to false after cancel attempt.');
      }
    } else {
      print(
          'RecordStateNotifier: Cancel recording called but not recording or no callback.');
      if (state == true) {
        // If it's recording but has no callback somehow, still force state to false
        state = false;
        print(
            'RecordStateNotifier: Forced recording state to false due to missing callback.');
      }
    }
  }
}

/// Provider definition for the RecordStateNotifier.
final recordStateProvider =
    StateNotifierProvider<RecordStateNotifier, bool>((ref) {
  return RecordStateNotifier();
});
