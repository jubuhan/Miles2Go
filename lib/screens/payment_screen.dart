import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ride_history_service.dart';
import '../services/block_service.dart'; // Assuming this is a typo and should be blockchain_service.dart
import '../services/walletconnect.dart';
import '../services/database_service.dart';
import './bottom_navigation.dart';

class PaymentScreen extends StatefulWidget {
  final String rideId;
  final String requestId;
  final Map<String, dynamic> rideData;

  const PaymentScreen({
    Key? key,
    required this.rideId,
    required this.requestId,
    required this.rideData,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedIndex = 1;
  bool _isLoading = false;
  bool _processingPayment = false;
  final RideHistoryService _historyService = RideHistoryService();
  final BlockchainService _blockchainService = BlockchainService();
  final WalletConnectService _walletService = WalletConnectService();
  final DatabaseServices _databaseServices = DatabaseServices();
  bool _rideHistorySaved = false;
  String _paymentStatus = '';

  @override
  void initState() {
    super.initState();
    _saveRideToHistory();
    _initWalletConnect();
    log('rideData: ${widget.rideData}');
  }

  Future<void> _initWalletConnect() async {
  try {
    debugPrint('Initializing wallet connection...');
    await _walletService.initWalletConnect(
      onSessionRestored: (address) {
        debugPrint('Session restored with address: $address');
        setState(() {}); // Refresh UI if wallet is connected
      },
    );
  } catch (e) {
    debugPrint('Error initializing WalletConnect: $e');
    _showError('Failed to initialize wallet: $e');
  }
}

  Future<void> _saveRideToHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _historyService.saveRideToHistory(
        rideId: widget.rideId,
        requestId: widget.requestId,
        isDriver: false,
      );

      setState(() {
        _rideHistorySaved = true;
        _isLoading = false;
      });
    } catch (e) {
      log('Error saving ride history: $e');
      _showError('Failed to save ride history');

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updatePaymentStatus(String status) {
    setState(() {
      _paymentStatus = status;
    });
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _historyService.updatePaymentStatus(
          rideId: widget.rideId,
          requestId: widget.requestId,
          isDriver: false,
          passengerId: user.uid,
        );
      }

      setState(() {
        _isLoading = false;
      });

      _showSuccess('Payment will be processed later.');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      log('Error processing payment: $e');
      _showError('Payment processing failed: ${e.toString()}');

      setState(() {
        _isLoading = false;
      });
    }
  }
Future<void> _processCryptoPayment() async {
  if (_processingPayment) return;

  setState(() {
    _processingPayment = true;
    _paymentStatus = 'Preparing payment...';
  });

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (!_rideHistorySaved) {
      await _historyService.saveRideToHistory(
        rideId: widget.rideId,
        requestId: widget.requestId,
        isDriver: false,
      );
      _rideHistorySaved = true;
    }

    if (!_walletService.isConnected) {
      _updatePaymentStatus('Connecting wallet...');
      await _walletService.connectWallet(_updatePaymentStatus);
      if (!_walletService.isConnected) throw Exception('Failed to connect wallet');
    }
    log('Wallet connected: ${_walletService.walletAddress}');

    final historyDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('rideHistory')
        .doc(widget.rideId)
        .get();
    if (!historyDoc.exists) throw Exception('Ride history not found');

    final historyData = historyDoc.data();
    if (historyData == null) throw Exception('Ride history data is empty');

    final driverId = historyData['driverId']?.toString();
    if (driverId == null) throw Exception('Driver ID not found');

    final driverData = await _databaseServices.getUserData(driverId);
    if (driverData == null) throw Exception('Driver profile not found');

    final driverWalletAddress = driverData['wallet']?['walletAddress'] ?? driverData['walletAddress'];
    if (driverWalletAddress == null) throw Exception('Driver wallet address not available');

    _updatePaymentStatus('Driver wallet: ${driverWalletAddress.substring(0, 10)}...');

    double price = (widget.rideData['price'] is num ? widget.rideData['price'] : 0.0).toDouble();
    final ethPrice = price * 0.0005;

    _updatePaymentStatus('Processing ${ethPrice.toStringAsFixed(6)} ETH payment...');
    final txHash = await _blockchainService.processRidePayment(
      context: context,
      rideId: widget.rideId,
      driverWalletAddress: driverWalletAddress,
      amountInEth: ethPrice,
      logUpdate: _updatePaymentStatus,
    );

    if (txHash == null) throw Exception('Transaction failed or was rejected');

    await _historyService.updatePaymentStatus(
      rideId: widget.rideId,
      requestId: widget.requestId,
      isDriver: false,
      passengerId: user.uid,
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('payments').add({
      'rideId': widget.rideId,
      'amount': ethPrice,
      'currency': 'ETH',
      'driverWallet': driverWalletAddress.toLowerCase(),
      'passengerWallet': _walletService.walletAddress!.toLowerCase(),
      'txHash': txHash,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'paymentType': 'crypto',
      'network': 'sepolia',
    });

    await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).set({
      'paymentStatus': 'paid',
      'paymentMethod': 'crypto',
      'paymentTxHash': txHash,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _processingPayment = false;
      _paymentStatus = '';
    });
    _showSuccess('Payment successful! Tx: ${txHash.substring(0, 10)}...');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  } catch (e) {
    log('Crypto payment error: $e, Stack: ${StackTrace.current}');
    _showError('Payment failed: $e');
    setState(() {
      _processingPayment = false;
      _paymentStatus = '';
    });
  }
}
  void _skipPayment() {
    _showSuccess('You can pay later from your ride history');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final String driverName = widget.rideData['driverName'] ?? 'Driver';

    double price = 0.0;
    if (widget.rideData['price'] is num) {
      price = (widget.rideData['price'] as num).toDouble();
    } else if (widget.rideData['price'] is String) {
      price = double.tryParse(widget.rideData['price']) ?? 0.0;
    } else if (widget.rideData['pricePerSeat'] is num) {
      price = (widget.rideData['pricePerSeat'] as num).toDouble();
    } else if (widget.rideData['pricePerSeat'] is String) {
      price = double.tryParse(widget.rideData['pricePerSeat']) ?? 0.0;
    }

    final ethAmount = price * 0.0005;

    String pickupLocation = '';
    if (widget.rideData.containsKey('pickupLocation')) {
      if (widget.rideData['pickupLocation'] is Map) {
        pickupLocation = widget.rideData['pickupLocation']['name'] ?? 'Pickup location';
      } else if (widget.rideData['pickupLocation'] is String) {
        pickupLocation = widget.rideData['pickupLocation'];
      }
    } else if (widget.rideData.containsKey('passengerPickup')) {
      pickupLocation = widget.rideData['passengerPickup'] ?? 'Pickup location';
    } else {
      pickupLocation = 'Pickup location';
    }

    String destination = '';
    if (widget.rideData.containsKey('to')) {
      if (widget.rideData['to'] is Map) {
        destination = widget.rideData['to']['name'] ?? 'Destination';
      } else if (widget.rideData['to'] is String) {
        destination = widget.rideData['to'];
      }
    } else {
      destination = 'Destination';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave Without Paying?'),
                content: const Text(
                  'You can pay later from your ride history. Are you sure you want to leave now?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _skipPayment();
                    },
                    child: const Text('YES, PAY LATER'),
                  ),
                ],
              ),
            );
          },
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ride Completed',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You have reached your destination',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ride Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Driver',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.green, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pick Up',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    pickupLocation,
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.only(left: 7),
                          width: 2,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Drop Off',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    destination,
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'USD Amount',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ETH Amount (Sepolia)',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${ethAmount.toStringAsFixed(6)} ETH',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_processingPayment)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _paymentStatus,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processingPayment ? null : _processCryptoPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                      ),
                      icon: const Icon(Icons.currency_bitcoin, color: Colors.white),
                      label: const Text(
                        'PAY WITH ETH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processingPayment ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.green.withOpacity(0.6),
                      ),
                      child: const Text(
                        'PAY WITH CASH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _processingPayment ? null : _skipPayment,
                      child: const Text(
                        'PAY LATER',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Miles2GoBottomNav(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
    );
  }
}