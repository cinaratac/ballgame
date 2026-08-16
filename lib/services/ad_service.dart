import 'dart:async' as dart_async;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  InterstitialAd? _interstitialAd;
  bool _isInitialized = false;
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isShowing = false;

  static const Set<int> _earlyUnlockAdLevels = {10, 20, 30, 40, 50};

  String? get _interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ca-app-pub-3940256099942544/1033173712';
      case TargetPlatform.iOS:
        return 'ca-app-pub-3940256099942544/4411468910';
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  Future<void> initialize() async {
    if (!_isAvailable || _isInitialized || _interstitialAdUnitId == null) {
      return;
    }

    try {
      await _requestTrackingAuthorizationIfNeeded();
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _loadInterstitial();
    } on MissingPluginException catch (error) {
      _disableAds('Google Mobile Ads plugin is not registered yet: $error');
    } on PlatformException catch (error) {
      _disableAds('Google Mobile Ads failed to initialize: $error');
    }
  }

  Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;

      await Future<void>.delayed(const Duration(milliseconds: 700));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } on MissingPluginException catch (error) {
      debugPrint('App Tracking Transparency plugin is not registered: $error');
    } on PlatformException catch (error) {
      debugPrint('App Tracking Transparency request failed: $error');
    }
  }

  bool shouldShowLevelUnlockAd(int unlockedLevel) {
    return _earlyUnlockAdLevels.contains(unlockedLevel) ||
        (unlockedLevel > 50 && unlockedLevel % 5 == 0);
  }

  Future<void> showAfterLevelUnlockIfReady(int unlockedLevel) async {
    if (!shouldShowLevelUnlockAd(unlockedLevel)) return;
    await initialize();
    if (!_isInitialized || !_isAvailable) return;

    final ad = _interstitialAd;
    if (ad == null || _isShowing) {
      _loadInterstitial();
      return;
    }

    _interstitialAd = null;
    _isShowing = true;
    final completer = dart_async.Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowing = false;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowing = false;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      ad.show();
    } on MissingPluginException catch (error) {
      ad.dispose();
      _disableAds('Google Mobile Ads plugin is not registered yet: $error');
      if (!completer.isCompleted) completer.complete();
    } on PlatformException catch (error) {
      ad.dispose();
      _isShowing = false;
      _loadInterstitial();
      debugPrint('Interstitial ad failed to show: $error');
      if (!completer.isCompleted) completer.complete();
    }
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _isShowing = false;
        _loadInterstitial();
      },
    );
  }

  void _loadInterstitial() {
    final adUnitId = _interstitialAdUnitId;
    if (!_isAvailable || adUnitId == null || !_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoading = false;
            _interstitialAd?.dispose();
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _interstitialAd = null;
          },
        ),
      );
    } on MissingPluginException catch (error) {
      _isLoading = false;
      _disableAds('Google Mobile Ads plugin is not registered yet: $error');
    } on PlatformException catch (error) {
      _isLoading = false;
      debugPrint('Interstitial ad failed to load: $error');
    }
  }

  void _disableAds(String reason) {
    _isAvailable = false;
    _isInitialized = false;
    _isLoading = false;
    _isShowing = false;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    debugPrint(reason);
  }
}
