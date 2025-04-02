import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingRequestsWidget extends StatefulWidget {
  final String rideId;

  const PendingRequestsWidget({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<PendingRequestsWidget> createState() => _PendingRequestsWidgetState();
}

class _PendingRequestsWidgetState extends State<PendingRequestsWidget> {
  bool _isLoading = true;
  int _pendingCount = 0;
  Stream<QuerySnapshot>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _setupRequestsStream();
  }

  void _setupRequestsStream() {
    _requestsStream = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('rideId', isEqualTo: widget.rideId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  void _navigateToRequestsScreen() {
    Navigator.pushNamed(
      context,
      '/manage-requests',
      arguments: {'rideId': widget.rideId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final pendingCount = snapshot.data?.docs.length ?? 0;

        if (pendingCount == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton(
            onPressed: _navigateToRequestsScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active),
                const SizedBox(width: 8),
                Text(
                  'View $pendingCount pending request${pendingCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}