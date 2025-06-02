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
  }

  /// Stops recording normally (e.g., when finished and saved).
  void stopRecording() {
    _cancelCallback = null; // Clear callback on normal stop
    state = false;
  }

  /// Cancels the recording by invoking the stored callback and resets state.
  void cancelRecording() {
    if (state == true && _cancelCallback != null) {
      try {
        _cancelCallback!(); // Execute the cancellation logic from RecordScreen
      } catch (e) {
      } finally {
        _cancelCallback = null; // Clear callback after attempting cancel
        state = false; // Set state to not recording
      }
    } else {
      if (state == true) {
        // If it's recording but has no callback somehow, still force state to false
        state = false;
      }
    }
  }
}

/// Provider definition for the RecordStateNotifier.
final recordStateProvider =
    StateNotifierProvider<RecordStateNotifier, bool>((ref) {
  return RecordStateNotifier();
});
