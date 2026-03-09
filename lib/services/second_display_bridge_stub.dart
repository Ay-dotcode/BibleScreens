import '../models/second_display_state.dart';

class SecondDisplayBridge {
  Future<void> openDisplayWindow() async {}

  Future<void> publish(SecondDisplayState state) async {}

  Stream<SecondDisplayState> listen() {
    return const Stream.empty();
  }

  Future<SecondDisplayState?> readCurrent() async {
    return null;
  }

  void dispose() {}
}
