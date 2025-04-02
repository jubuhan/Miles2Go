import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:miles2go/controller/rides_controller.dart';
import 'package:miles2go/services/database_service.dart';
import 'otpLic.dart';

class AddVehiclePage extends StatelessWidget {
  AddVehiclePage({super.key});
  RideController rideController = Get.put(RideController());
  TextEditingController regIdController = TextEditingController();
  TextEditingController plateController = TextEditingController();
  TextEditingController vehicleTypeController = TextEditingController();
  TextEditingController vehicleNameController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  TextEditingController seatController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "ADD A NEW VEHICLE",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 24,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add details as per registration certificate",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(regIdController, "Registration ID"),
            _buildTextField(plateController, "Plate"),
            _buildTextField(vehicleTypeController, "Vehicle Type"),
            _buildTextField(vehicleNameController,"Vehicle Name"),
            _buildTextField(modelController,"Model"),
            _buildTextField(seatController,"Seats"),
       
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                User? user = await FirebaseAuth.instance.currentUser;
                if (user != null) {
                  if (regIdController.text.isNotEmpty &&
                      plateController.text.isNotEmpty && 
                      vehicleTypeController.text.isNotEmpty &&
                      vehicleNameController.text.isNotEmpty &&
                      modelController.text.isNotEmpty &&
                       seatController.text.isNotEmpty) {
                    print("reg id :${regIdController.text}");
                    print("plate :${plateController.text}");
                   bool isAddedVehicle = await DatabaseServices().addVehicleDetail(context, user.uid, {
                      "regId": regIdController.text,
                      "plate": plateController.text,
                       "vehicleType":vehicleTypeController.text,
                      "vehicleName":vehicleNameController.text,
                      "model":modelController.text,
                      "seats":seatController.text
                    });

                    if(isAddedVehicle){
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context){}))
                       rideController.vehiclesList.value = await DatabaseServices().getUserVehicles();
                      Navigator.pop(context);
                    }
                  } else {
                    print("Required all fields");
                    
                            ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Invalid - please fill all required fields",
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        
                  }
                }
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => OtpLicensePage(),
                //   ),
                // );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "ADD VEHICLE",
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Check the registered mobile number of RC for OTP",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        obscureText: obscureText,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue, width: 1.5),
          ),
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}
