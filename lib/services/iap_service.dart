import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IapService {
  static final IapService instance = IapService._internal();
  IapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs (Must match store config)
  static const String monthlyId = 'seedling_premium_monthly';
  static const String annualId = 'seedling_premium_annual';

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  final _purchaseController = StreamController<PurchaseStatus>.broadcast();
  Stream<PurchaseStatus> get purchaseStatusStream => _purchaseController.stream;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Stream Error: $error');
    });
  }

  Future<void> loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;

    const Set<String> ids = {monthlyId, annualId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    if (Platform.isIOS) {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam); 
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchaseController.add(PurchaseStatus.pending);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _purchaseController.add(PurchaseStatus.error);
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        _verifyAndComplete(purchaseDetails);
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchaseDetails) async {
    try {
      // 1. Send receipt to server for verification
      final String provider = Platform.isIOS ? 'apple' : 'google';
      final String receiptData = purchaseDetails.verificationData.serverVerificationData;

      final response = await Supabase.instance.client.functions.invoke('verify-receipt', body: {
        'provider': provider,
        'receiptData': receiptData,
        'productId': purchaseDetails.productID,
        'isSandbox': !kReleaseMode
      });

      if (response.status != 200) throw Exception('Verification Failed');

      // 2. Complete purchase in store front
      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
      
      _purchaseController.add(PurchaseStatus.purchased);
    } catch (e) {
      debugPrint('Verification Error: $e');
      _purchaseController.add(PurchaseStatus.error);
    }
  }

  void dispose() {
    _subscription.cancel();
    _purchaseController.close();
  }
}
