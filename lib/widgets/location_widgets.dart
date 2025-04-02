import 'package:flutter/material.dart';
import 'package:google_place/google_place.dart';

// Common widgets for location-based screens
class LocationWidgets {
  // Build a predictions list
  static Widget buildPredictionsList({
    required List<AutocompletePrediction> predictions,
    required Function(AutocompletePrediction, bool) onSelect,
    required bool isOrigin,
    required double top,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: predictions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final prediction = predictions[index];
            return ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF1A3A4A)),
              title: Text(
                prediction.structuredFormatting?.mainText ?? prediction.description ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A3A4A),
                ),
              ),
              subtitle: Text(
                prediction.structuredFormatting?.secondaryText ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                onSelect(prediction, isOrigin);
              },
            );
          },
        ),
      ),
    );
  }

  // Build a location input field
  static Widget buildLocationField({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
    required VoidCallback onTap,
    required VoidCallback onCurrentLocation,
    required Color borderColor,
    Icon? prefixIcon,
    Icon? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black54),
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: 2.0)
        ),
        prefixIcon: prefixIcon ?? const Icon(Icons.search, color: Colors.black54),
        suffixIcon: IconButton(
          icon: suffixIcon ?? const Icon(Icons.my_location, color: Colors.black54),
          onPressed: onCurrentLocation,
        ),
      ),
    );
  }

  // Build a date picker field
  static Widget buildDateField({
    required String? selectedDate,
    required VoidCallback onTap,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.black54),
            const SizedBox(width: 12),
            Text(
              selectedDate ?? 'Select Date',
              style: TextStyle(
                color: selectedDate != null ? Colors.black54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a passengers selector
  static Widget buildPassengersSelector({
    required int passengerCount,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2.0),
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.black54),
          const SizedBox(width: 12),
          const Text(
            'passengers',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.black54),
            onPressed: onDecrement,
          ),
          Text(
            passengerCount.toString(),
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black54),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }

  // Build a drag handle for bottom sheets
  static Widget buildDragHandle(Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}