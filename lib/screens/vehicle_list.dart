import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:miles2go/controller/rides_controller.dart';
import 'package:miles2go/screens/publish_ride.dart';
import 'package:miles2go/services/database_service.dart';
import 'add_vehicle_page.dart'; // Import AddVehiclePage
import './bottom_navigation.dart'; // Import bottom nav widget

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  // Navigation state
  int _selectedIndex = 2; // Set to 2 for Rides tab
  RideController rideController = Get.put(RideController());

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Add navigation logic here if needed
    // For demonstration, we're just updating the selected index
  }

  @override
  Widget build(BuildContext context) {
    //  DatabaseServices().getUserVehicles();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            color: Colors.white,
          ),
          Column(
            children: [
              // List of vehicles
              Expanded(
                child: Obx(
                   () {
                    return ListView.builder(
                      itemCount: rideController.vehiclesList.length, // Number of vehicles
                      itemBuilder: (context, index) {
                        final vehicle = rideController.vehiclesList[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              // Navigate directly to PublishRideScreen when vehicle is tapped
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PublishRideScreen(),
                                ),
                              );
                            },
                            child: Container(
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
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Text(
                                  //   'KL10A00${index + 1}',
                                  //   style: const TextStyle(
                                  //     fontSize: 18,
                                  //     fontWeight: FontWeight.normal,
                                  //     color: Colors.black
                                  //   ),
                                    
                                  // ),
                                  // const SizedBox(height: 8),
                                  // const Text('Vehicle Type: Car', style: TextStyle(color: Colors.black54)),
                                  // const Text('Vehicle Name: Bike', style: TextStyle(color: Colors.black54)),
                                  // const Text('No. of Seats: 4', style: TextStyle(color: Colors.black54)),
                                  // const Text('No. of Rides: 10', style: TextStyle(color: Colors.black54)),
                                  
                                   Text('PLATE: ${vehicle["plate"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                   Text('REG ID:  ${vehicle["regId"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                   Text('MODEL: ${vehicle["model"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                   Text('VEHICLE NAME: ${vehicle["vehicleName"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                   Text('VEHICLE TYPE:  ${vehicle["vehicleType"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                   Text('NO OF SEAT: ${vehicle["seats"]}', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
              // Add new vehicle button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to AddVehiclePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddVehiclePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Center(
                    child: Text(
                      'ADD NEW VEHICLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
      // Add the bottom navigation bar
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}