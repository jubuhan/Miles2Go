import 'package:flutter/material.dart';
import 'package:miles2go/screens/profile_setting.dart';
import 'package:miles2go/screens/ride_search_screen.dart';
import 'package:miles2go/screens/service_selection_screen.dart';

class Miles2GoBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const Miles2GoBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A4A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          onTap(index);
          // Navigate to the respective page when a tab is tapped
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ServiceSelectionScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => RideSearchScreen()),  // Remove const
  );
  break;
            // case 2:
            //   Navigator.pushReplacement(
            //     context,
            //     MaterialPageRoute(builder: (context) => const MyRidesPage()),
            //   );
            //   break;
             case 3:
               Navigator.pushReplacement(
                 context,
                 MaterialPageRoute(builder: (context) =>  ProfileSettingsPage()),
               );
               break;
          }
        },
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'My Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
