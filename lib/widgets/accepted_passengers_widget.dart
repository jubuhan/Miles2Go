import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AcceptedPassengersWidget extends StatelessWidget {
  final String rideId;

  const AcceptedPassengersWidget({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Simple query without composite index
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rideRequests')
          .where('rideId', isEqualTo: rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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

        // Filter for only accepted requests
        final acceptedDocs = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'accepted';
        }).toList() ?? [];
        
        if (acceptedDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No passengers yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PASSENGERS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: acceptedDocs.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade300,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final data = acceptedDocs[index].data() as Map<String, dynamic>;
                  final userName = data['userName'] ?? 'Unknown User';
                  final requestedSeats = data['requestedSeats'] ?? 1;
                  
                  // Get passenger's custom pickup location (it could be an intermediate point)
                  final passengerPickup = data['passengerPickup'] ?? data['from'] ?? '';
                  
                  // Get passenger's custom dropoff location (it could be an intermediate point)
                  final passengerDropoff = data['passengerDropoff'] ?? data['to'] ?? '';
                  
                  final requestedAt = data['requestedAt'] != null
                      ? (data['requestedAt'] as Timestamp).toDate()
                      : null;
                  
                  String formattedDate = '';
                  if (requestedAt != null) {
                    formattedDate = '${requestedAt.day}/${requestedAt.month}/${requestedAt.year}';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        Icons.person,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup: $passengerPickup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Dropoff: $passengerDropoff',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '$requestedSeats ${requestedSeats > 1 ? 'seats' : 'seat'}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      // Show more details about the passenger
                      _showPassengerDetails(context, data);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _showPassengerDetails(BuildContext context, Map<String, dynamic> passengerData) {
    final userName = passengerData['userName'] ?? 'Unknown User';
    final requestedSeats = passengerData['requestedSeats'] ?? 1;
    
    // Get passenger's custom pickup and dropoff locations
    final passengerPickup = passengerData['passengerPickup'] ?? passengerData['from'] ?? '';
    final passengerDropoff = passengerData['passengerDropoff'] ?? passengerData['to'] ?? '';
    
    // Get contact info if available
    final contact = passengerData['contact'] ?? 'Not provided';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Pickup', passengerPickup),
            const SizedBox(height: 8),
            _buildDetailRow('Dropoff', passengerDropoff),
            const SizedBox(height: 8),
            _buildDetailRow('Seats', requestedSeats.toString()),
            const SizedBox(height: 8),
            _buildDetailRow('Contact', contact),
            const SizedBox(height: 8),
            _buildDetailRow('Status', 'Accepted'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}