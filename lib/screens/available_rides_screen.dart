import 'package:flutter/material.dart';
import 'waiting_confirmation_screen.dart';
import './bottom_navigation.dart'; // Import bottom nav widget

class AvailableRidesScreen extends StatefulWidget {
  final String from;
  final String to;
  final String date;
  final String passengers;

  const AvailableRidesScreen({
    Key? key,
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
  }) : super(key: key);

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  // Navigation state
  int _selectedIndex = 1; // Set to 1 for Search tab

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Add navigation logic here if needed
    // For demonstration, we're just updating the selected index
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journey Details Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                  
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJourneyDetail('From', widget.from),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('To', widget.to),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('Date', widget.date),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('Passengers', widget.passengers),
                  ],
                ),
              ),
            ),
            // Available Rides Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'AVAILABLE RIDES (${_getDummyRides().length})',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rides List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _getDummyRides().length,
                itemBuilder: (context, index) {
                  final ride = _getDummyRides()[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildRideCard(
                      context: context,
                      name: ride['name']!,
                      startTime: ride['startTime']!,
                      endTime: ride['endTime']!,
                      price: ride['price']!,
                      distance: ride['distance']!,
                      rating: ride['rating']!,
                      carModel: ride['carModel']!,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Add the bottom navigation bar
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildJourneyDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard({
    required BuildContext context,
    required String name,
    required String startTime,
    required String endTime,
    required String price,
    required String distance,
    required String rating,
    required String carModel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
      ),
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Info Row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade400,
                child: Icon(Icons.person, color: Colors.white.withOpacity(0.8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.yellow[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.directions_car, color: Colors.black54, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          carModel,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Time and Distance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.black54, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$startTime - $endTime',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.route, color: Colors.black54, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    distance,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Request Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WaitingConfirmationScreen(
                      driverName: name,
                      from: widget.from,
                      to: widget.to,
                      date: widget.date,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'REQUEST RIDE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getDummyRides() {
    return [
      {
        'name': 'JUBUHAN',
        'startTime': '8:30 AM',
        'endTime': '9:15 AM',
        'price': '₹110',
        'distance': '8 km',
        'rating': '4.8',
        'carModel': 'Swift',
      },
      {
        'name': 'AGNES',
        'startTime': '9:00 AM',
        'endTime': '9:45 AM',
        'price': '₹95',
        'distance': '8 km',
        'rating': '4.6',
        'carModel': 'i20',
      },
      {
        'name': 'VIVEK PS',
        'startTime': '9:30 AM',
        'endTime': '10:15 AM',
        'price': '₹105',
        'distance': '8 km',
        'rating': '4.7',
        'carModel': 'Baleno',
      },
    ];
  }
}