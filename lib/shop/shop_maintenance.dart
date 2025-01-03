import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({Key? key}) : super(key: key);

  @override
  _MaintenanceScreenState createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  MaintenanceData? _maintenanceData;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    _fetchMaintenanceData();
  }

  Future<void> _fetchMaintenanceData() async {
    try {
      // ShopMaintenanceコレクションから最新の1件のみを取得
      final querySnapshot = await FirebaseFirestore.instance
          .collection('shopMaintenance')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _maintenanceData =
              MaintenanceData.fromFirestore(querySnapshot.docs.first.data());
        });
      }
    } catch (e) {
      print('Error fetching maintenance data: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('yyyy年M月d日 HH時mm分').format(dateTime);
  }

  Widget _buildDelayedAnimation({
    required Widget child,
    required Duration delay,
    required Duration duration,
    Curve curve = Curves.easeOutCubic,
    Offset? slideOffset,
  }) {
    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: duration,
          curve: curve,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: slideOffset != null
                    ? Offset(
                        slideOffset.dx * (1 - value),
                        slideOffset.dy * (1 - value),
                      )
                    : Offset(0, 15 * (1 - value)),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: const Duration(seconds: 3),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.settings,
                        size: 80,
                        color: Color(0xFF00008b),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              _buildDelayedAnimation(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutQuint,
                child: Text(
                  'システムメンテナンス中',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008b),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDelayedAnimation(
                delay: const Duration(milliseconds: 600),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '現在システムメンテナンスを実施しております。\nご不便をおかけし申し訳ございませんが、\n今しばらくお待ちください。\nまた、他サービスはご利用いただけます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildDelayedAnimation(
                delay: const Duration(milliseconds: 900),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutQuart,
                slideOffset: const Offset(0, 30),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildDelayedAnimation(
                        delay: const Duration(milliseconds: 1100),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        child: Text(
                          '予定時間',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDelayedAnimation(
                        delay: const Duration(milliseconds: 1300),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutQuart,
                        slideOffset: const Offset(-30, 0),
                        child: Text(
                          '開始：${_formatDateTime(_maintenanceData?.startTime)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDelayedAnimation(
                        delay: const Duration(milliseconds: 1500),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutQuart,
                        slideOffset: const Offset(30, 0),
                        child: Text(
                          '終了：${_formatDateTime(_maintenanceData?.endTime)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildDelayedAnimation(
                delay: const Duration(milliseconds: 1800),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '時刻は予定時間です。\n諸事情により時間変更される可能性があります。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceData {
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;

  MaintenanceData({
    this.startTime,
    this.endTime,
    this.createdAt,
  });

  factory MaintenanceData.fromFirestore(Map<String, dynamic> data) {
    return MaintenanceData(
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
