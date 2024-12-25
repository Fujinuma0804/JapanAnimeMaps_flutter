import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CoinChargingScreen extends StatefulWidget {
  const CoinChargingScreen({Key? key}) : super(key: key);

  @override
  _CoinChargingScreenState createState() => _CoinChargingScreenState();
}

class _CoinChargingScreenState extends State<CoinChargingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedAmount = 0;

  final List<Map<String, dynamic>> _chargingOptions = [
    {'amount': 1000, 'price': 1150, 'bonus': 0},
    {'amount': 2000, 'price': 2300, 'bonus': 0},
    {'amount': 3000, 'price': 3450, 'bonus': 0},
    {'amount': 4000, 'price': 4600, 'bonus': 0},
    {'amount': 5000, 'price': 5750, 'bonus': 0},
    {'amount': 10000, 'price': 11500, 'bonus': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'コインチャージ',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00008b)),
      ),
      body: Column(
        children: [
          _buildCurrentBalance(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'チャージする金額を選択',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildChargingOptions(),
                  const SizedBox(height: 24),
                  if (_selectedAmount > 0) _buildChargeButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('エラーが発生しました');
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final coins =
              (data != null && data['coins'] is int) ? data['coins'] as int : 0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '現在の残高',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$coins コイン',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00008b),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildChargingOptions() {
    return _chargingOptions.map((option) {
      final bool isSelected = _selectedAmount == option['amount'];
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedAmount = option['amount'];
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00008b).withOpacity(0.05)
                  : Colors.white,
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF00008b) : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Radio<int>(
                  value: option['amount'],
                  groupValue: _selectedAmount,
                  onChanged: (value) {
                    setState(() {
                      _selectedAmount = value!;
                    });
                  },
                  activeColor: const Color(0xFF00008b),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${option['amount']} コイン',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (option['bonus'] > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${option['bonus']} コインボーナス',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '¥${option['price']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008b),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildChargeButton() {
    final selectedOption = _chargingOptions.firstWhere(
      (option) => option['amount'] == _selectedAmount,
    );

    return ElevatedButton(
      onPressed: () => _showConfirmationDialog(selectedOption),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00008b),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        '¥${selectedOption['price']}を支払う',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showConfirmationDialog(Map<String, dynamic> option) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チャージ確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${option['amount']} コインをチャージします。'),
            if (option['bonus'] > 0) Text('(+${option['bonus']} コインのボーナス付き)'),
            const SizedBox(height: 8),
            Text('支払い金額: ¥${option['price']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processCharge(option);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00008b),
            ),
            child: const Text(
              'チャージする',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCharge(Map<String, dynamic> option) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId == null) {
          throw Exception('ユーザーが認証されていません');
        }

        final userDoc =
            await transaction.get(_firestore.collection('users').doc(userId));

        final currentCoins = (userDoc.data()?['coins'] ?? 0) as int;
        final addedCoins = option['amount'] + option['bonus'];
        final newCoins = currentCoins + addedCoins;

        transaction.update(
          userDoc.reference,
          {'coins': newCoins},
        );

        transaction.set(
          _firestore.collection('coin_transactions').doc(),
          {
            'userId': userId,
            'amount': option['amount'],
            'bonus': option['bonus'],
            'price': option['price'],
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'charge',
          },
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('コインのチャージが完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
