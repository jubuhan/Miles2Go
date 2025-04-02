import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ride_history_service.dart';
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
  int _selectedIndex = 1; // Set to 1 for Find Rides tab
  bool _isLoading = false;
  final RideHistoryService _historyService = RideHistoryService();
  bool _rideHistorySaved = false;
  
  @override
  void initState() {
    super.initState();
    _saveRideToHistory();
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
      print('Error saving ride history: $e');
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
    // Add navigation logic here if needed
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
  
  // Method to process payment (in a real app, this would connect to a payment gateway)
  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real app, you would process payment through a payment gateway here
      // For now, we'll just show success and go back to home
      
      // Payment successful, update status
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
      
      // Navigate back to home after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      print('Error processing payment: $e');
      _showError('Payment processing failed: ${e.toString()}');
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Method to skip payment (pay later option)
  void _skipPayment() {
    _showSuccess('You can pay later from your ride history');
    
    // Navigate back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculate ride info - with safe handling of types
    final String driverName = widget.rideData['driverName'] ?? 'Driver';
    
    // Safely handle price which might be a string or a number
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
    
    // Safely handle pickup location
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
    
    // Safely handle destination
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
            // Show confirmation dialog
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
                  // Ride completed card
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
                  
                  // Ride summary
                  const Text(
                    'Ride Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Driver info
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
                  
                  // Route info
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
                  
                  // Payment details
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
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
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Payment buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'PAY NOW',
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
                      onPressed: _skipPayment,
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