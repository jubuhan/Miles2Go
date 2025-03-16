import 'package:flutter/material.dart';
import 'package:miles2go/screens/bottom_navigation.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _selectedIndex = 2; // Set to match the current page in bottom navigation

  // Static demo notifications
  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'Decline ride request',
      message: 'Jenny wisdom decline your ride request. find new ride.',
      timeAgo: '2min ago',
      type: 'decline',
    ),
    NotificationItem(
      title: 'Add money',
      message: 'Congratulation \$10.00 successfully added in your wallet.',
      timeAgo: '2min ago',
      type: 'wallet',
    ),
    NotificationItem(
      title: 'Accept request',
      message: 'Congratulation jecob johan accept your ride request',
      timeAgo: '2min ago',
      type: 'accept',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildNotificationsList(),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    // Choose icon based on notification type
    IconData iconData;
    switch (notification.type) {
      case 'decline':
        iconData = Icons.notifications_none;
        break;
      case 'accept':
        iconData = Icons.notifications_none;
        break;
      case 'wallet':
        iconData = Icons.notifications_none;
        break;
      default:
        iconData = Icons.notifications_none;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Notification content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationItem {
  final String title;
  final String message;
  final String timeAgo;
  final String type;

  NotificationItem({
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.type,
  });
}