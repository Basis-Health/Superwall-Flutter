import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

// The name of the bridging class on the native side
typedef BridgeClass = String;

// The identifier of the bridge instance
typedef BridgeId = String;

class BridgingCreator {
  static const MethodChannel _channel = MethodChannel('SWK_BridgingCreator');

  // Stores argument metadata provided during the creation of the bridgeId.
  // This will later be used when invoking creation to pass in initialization arguments
  static final Map<String, Map<String, dynamic>> _metadataByBridgeId = {};

  static BridgeId _createBridgeId(BridgeClass bridgeClass, [ Map<String, dynamic>? initializationArgs ]) {
    BridgeId bridgeId = bridgeClass.generateBridgeId();
    _metadataByBridgeId[bridgeId] = { "args": initializationArgs };

    return bridgeId;
  }

  static _invokeBridgeInstanceCreation(BridgeId bridgeId) async {
    Map<String, dynamic> metadata = BridgingCreator._metadataByBridgeId[bridgeId] ?? {};
    Map<String, dynamic>? initializationArgs = metadata["args"];

    await _channel.invokeMethod("createBridgeInstance", { "bridgeId" : bridgeId, "args" : initializationArgs });

    metadata["bridgeInstanceCreated"] = "true";
    _metadataByBridgeId[bridgeId] = metadata;
  }

  static Future<void> _ensureBridgeCreated(BridgeId bridgeId) async {
    Map<String, dynamic>? metadata = BridgingCreator._metadataByBridgeId[bridgeId];

    // If metadata is not null, this bridge was already created on the Dart
    // side here, so you must invoke creation of the instance on the native side.
    if (metadata != null && metadata["bridgeInstanceCreated"] == null) {
      await BridgingCreator._invokeBridgeInstanceCreation(bridgeId);
    }
  }

  //region Creators - NOTE: In order to create a bridge, it MUST exist in
  // the `bridgeMap` on the native sides

  // TODO: Move these to their associated classes and abstract into base class (see PaywallSkipReason)

  static BridgeId createSuperwallBridge() {
    return _createBridgeId("SuperwallBridge");
  }

  static BridgeId createSuperwallDelegateProxyBridgeId() {
    return _createBridgeId("SuperwallDelegateProxyBridge");
  }

  static BridgeId createPurchaseControllerProxyBridgeId() {
    return _createBridgeId("PurchaseControllerProxyBridge");
  }

  static BridgeId createSubscriptionStatusActiveBridgeId() {
    return _createBridgeId("SubscriptionStatusActiveBridge");
  }

  static BridgeId createSubscriptionStatusInactiveBridgeId() {
    return _createBridgeId("SubscriptionStatusInactiveBridge");
  }

  static BridgeId createSubscriptionStatusUnknownBridgeId() {
    return _createBridgeId("SubscriptionStatusUnknownBridge");
  }

  static BridgeId createPurchaseResultCancelledBridgeId() {
    return _createBridgeId("PurchaseResultCancelledBridge");
  }

  static BridgeId createPurchaseResultPurchasedBridgeId() {
    return _createBridgeId("PurchaseResultPurchasedBridge");
  }

  static BridgeId createPurchaseResultRestoredBridgeId() {
    return _createBridgeId("PurchaseResultRestoredBridge");
  }

  static BridgeId createPurchaseResultPendingBridgeId() {
    return _createBridgeId("PurchaseResultPendingBridge");
  }

  static BridgeId createPurchaseResultFailedBridgeId(String error) {
    return _createBridgeId("PurchaseResultFailedBridge", { "error": error });
  }

  static BridgeId createRestorationResultRestoredBridge() {
    return _createBridgeId("RestorationResultRestoredBridge");
  }

  static BridgeId createRestorationResultFailedBridge(String error) {
    return _createBridgeId("RestorationResultFailedBridge", { "error": error });
  }

  //endregion
}

// A protocol that Dart classes should conform to if they want to be able to
// create a BridgeId, or instantiate themselves from a BridgeID
abstract class BridgeIdInstantiable {
  BridgeId bridgeId;

  BridgeIdInstantiable(BridgeClass bridgeClass, [BridgeId? providedBridgeId, Map<String, dynamic>? initializationArgs])
      : bridgeId = providedBridgeId ?? BridgingCreator._createBridgeId(bridgeClass, initializationArgs) {
    bridgeId.associate(this);
    bridgeId.communicator.setMethodCallHandler(handleMethodCall);
  }

  // Handle method calls from native (subclasses should implement)
  Future<dynamic> handleMethodCall(MethodCall call) async {}
}

extension MethodChannelBridging on MethodChannel {
  // Will invoke the method as usual, but will wait for any native Ids to be
  // created if they don't already exist.
  Future<T?> invokeBridgeMethod<T>(String method, [Map<String, Object?>? arguments]) async {
    // Check if arguments is a Map and contains native IDs
    if (arguments != null) {
      for (var value in arguments.values) {
        if (value is String && value.isBridgeId) {
          BridgeId bridgeId = value;
          await bridgeId.ensureBridgeCreated();
        }
      }
    }

    await bridgeId.ensureBridgeCreated();

    return invokeMethod(method, arguments);
  }

  BridgeId get bridgeId {
    return name;
  }
}

extension FlutterMethodCall on MethodCall {
  T? argument<T>(String key) {
    return arguments[key] as T?;
  }

  BridgeId bridgeId(String key) {
    final BridgeId? bridgeId = argument<String>(key);
    assert(bridgeId != null, "Attempting to fetch a bridge Id in Dart that has "
        "not been created by the BridgeCreator natively.");

    return bridgeId ?? "";
  }
}

// Stores a reference to a dart instance that receives responses from the native side.
extension BridgeAssociation on BridgeId {
  static final List<dynamic> associatedInstances = [];

  associate(dynamic dartInstance) {
    BridgeAssociation.associatedInstances.add(dartInstance);
  }
}

extension BridgeAdditions on BridgeId {
  MethodChannel get communicator {
    return MethodChannel(this);
  }

  BridgeClass get bridgeClass {
    return split('-').first;
  }

  // Call this
  Future<void> ensureBridgeCreated() async {
    await BridgingCreator._ensureBridgeCreated(this);
  }
}

extension StringExtension on String {
  bool get isBridgeId {
    return endsWith('-bridgeId');
  }
}

extension Additions on BridgeClass {
  // Make sure this is the same on the Native side.
  BridgeId generateBridgeId() {
    final instanceIdentifier = const Uuid().v4();
    final bridgeId = "$this-$instanceIdentifier-bridgeId";
    return bridgeId;
  }
}