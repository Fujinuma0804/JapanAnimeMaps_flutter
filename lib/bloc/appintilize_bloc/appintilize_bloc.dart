import 'dart:async';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
part 'appintilize_event.dart';
part 'appintilize_state.dart';

class AppInitializationBloc
    extends Bloc<AppInitializationEvent, AppInitializationState> {
  AppInitializationBloc() : super(InitializationInitial()) {
    on<StartInitialization>(_onStartInitialization);
    on<UpdateInitializationProgress>(_onUpdateProgress);
  }

  Future<void> _onStartInitialization(
    StartInitialization event,
    Emitter<AppInitializationState> emit,
  ) async {
    try {
      emit(InitializationLoading(currentStep: 'アプリを起動しています...', progress: 10));

      // Step 1: トラッキング許可のリクエスト
      await _requestTrackingPermission(emit);

      // Step 2: Firebase Auth状態の確認
      final user = await _checkFirebaseAuthState(emit);

      // Step 3: RevenueCatの同期
      if (user != null) {
        await _syncRevenueCatAndUserData(user, emit);
      }

      // Step 4: 初期化完了
      emit(InitializationLoading(currentStep: '完了', progress: 100));

      await Future.delayed(const Duration(milliseconds: 500));

      emit(InitializationSuccess(user: user));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Initialization error: $e');
        print('Stack trace: $stackTrace');
      }
      emit(
        InitializationError(
          error: e.toString(),
          stackTrace: stackTrace.toString(),
        ),
      );
    }
  }

  void _onUpdateProgress(
    UpdateInitializationProgress event,
    Emitter<AppInitializationState> emit,
  ) {
    if (state is InitializationLoading) {
      emit(
        InitializationLoading(
          currentStep: event.step,
          progress: event.progress,
        ),
      );
    }
  }

  Future<void> _requestTrackingPermission(
    Emitter<AppInitializationState> emit,
  ) async {
    emit(InitializationLoading(currentStep: '設定を読み込み中...', progress: 20));

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await Future.delayed(const Duration(milliseconds: 200));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Tracking permission error: $e');
        }
        // トラッキング許可の失敗は致命的ではないので続行
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<User?> _checkFirebaseAuthState(
    Emitter<AppInitializationState> emit,
  ) async {
    emit(InitializationLoading(currentStep: 'ユーザー情報を確認中...', progress: 40));

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        if (kDebugMode) {
          print('User found: ${user.uid}');
        }
      } else {
        if (kDebugMode) {
          print('No user logged in');
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase Auth check error: $e');
      }
      // 認証チェックの失敗は致命的ではないのでnullを返して続行
      return null;
    }
  }

  Future<void> _syncRevenueCatAndUserData(
    User user,
    Emitter<AppInitializationState> emit,
  ) async {
    emit(InitializationLoading(currentStep: '課金情報を同期中...', progress: 60));

    try {
      // RevenueCatとの同期
      await _syncRevenueCatUser(user.uid);

      emit(InitializationLoading(currentStep: 'ユーザーデータを更新中...', progress: 80));

      // ユーザーデータの更新（並列実行）
      await Future.wait([
        _updateUserLoginInfo(user.uid),
        _recordAppUsage(user.uid),
      ], eagerError: false);
    } catch (e) {
      if (kDebugMode) {
        print('RevenueCat/user data sync error: $e');
      }
      // これらの同期失敗は致命的ではないので続行
    }
  }

  Future<void> _syncRevenueCatUser(String userId) async {
    try {
      await Purchases.logIn(userId);

      // 課金情報の同期
      final customerInfo = await Purchases.getCustomerInfo();
      await _syncBillingInfoToFirestore(userId, customerInfo);
      await _updateUserPremiumStatus(userId, customerInfo);
    } catch (e) {
      if (kDebugMode) {
        print('RevenueCat sync error: $e');
      }
      throw e;
    }
  }

  Future<void> _syncBillingInfoToFirestore(
    String userId,
    CustomerInfo customerInfo,
  ) async {
    try {
      final billingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing')
          .doc('subscription_status');

      final now = DateTime.now();
      final entitlementsData = <String, dynamic>{};

      for (var entry in customerInfo.entitlements.all.entries) {
        final entitlement = entry.value;
        entitlementsData[entry.key] = {
          'isActive': entitlement.isActive,
          'willRenew': entitlement.willRenew,
          'productIdentifier': entitlement.productIdentifier,
          'latestPurchaseDate': _safeDateTimeToString(
            entitlement.latestPurchaseDate,
          ),
          'expirationDate': _safeDateTimeToString(entitlement.expirationDate),
        };
      }

      final billingData = {
        'isPremium': customerInfo.entitlements.active.isNotEmpty,
        'hasActiveSubscription': customerInfo.activeSubscriptions.isNotEmpty,
        'originalAppUserId': customerInfo.originalAppUserId,
        'activeSubscriptions': customerInfo.activeSubscriptions.toList(),
        'entitlements': entitlementsData,
        'lastUpdated': now,
        'lastUpdatedTimestamp': FieldValue.serverTimestamp(),
      };

      await billingRef.set(billingData, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Billing Firestore sync error: $e');
      }
      // 課金情報同期の失敗は致命的ではない
    }
  }

  Future<void> _updateUserPremiumStatus(
    String userId,
    CustomerInfo customerInfo,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      final isPremium = customerInfo.entitlements.active.isNotEmpty;

      await userRef.update({
        'isPremiumUser': isPremium,
        'hasActiveSubscription': customerInfo.activeSubscriptions.isNotEmpty,
        'billingLastSyncedAt': DateTime.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Premium status update error: $e');
      }
    }
  }

  Future<void> _updateUserLoginInfo(String userId) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      final now = DateTime.now();
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final currentLoginCount = userDoc.data()?['loginCount'] ?? 0;
        await userRef.update({
          'lastLoginAt': now,
          'lastOpenedAt': now,
          'loginCount': currentLoginCount + 1,
          'lastSyncedAt': now,
        });
      } else {
        await userRef.set({
          'lastLoginAt': now,
          'lastOpenedAt': now,
          'loginCount': 1,
          'createdAt': now,
          'lastSyncedAt': now,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) {
        print('User login info update error: $e');
      }
    }
  }

  Future<void> _recordAppUsage(String userId) async {
    try {
      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('usage_history')
          .add({'openedAt': now, 'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      if (kDebugMode) {
        print('App usage recording error: $e');
      }
    }
  }

  String? _safeDateTimeToString(dynamic dateTime) {
    try {
      if (dateTime == null) return null;
      if (dateTime is DateTime) return dateTime.toIso8601String();
      if (dateTime is String) return dateTime;
      return dateTime.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> close() {
    if (kDebugMode) {
      print('AppInitializationBloc closed');
    }
    return super.close();
  }
}
