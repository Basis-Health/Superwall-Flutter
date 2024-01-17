import 'package:flutter/services.dart';
import 'package:superwallkit_flutter/src/private/BridgingCreator.dart';

class CompletionBlockProxy extends BridgeIdInstantiable {
  static const BridgeClass bridgeClass = "CompletionBlockProxyBridge";
  CompletionBlockProxy(this.block, [BridgeId? bridgeId]): super(bridgeClass, bridgeId);

  Function(dynamic) block;

  // Handle method calls from native
  @override
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'callCompletionBlock':
        final arguments = call.arguments;
        block(arguments);
      default:
        throw UnimplementedError('Method ${call.method} not implemented.');
    }
  }
}