import 'package:flutter/material.dart';
import '../screens/service_selection_screen.dart';

class WalletSelectionPage extends StatefulWidget {
  const WalletSelectionPage({Key? key}) : super(key: key);

  @override
  State<WalletSelectionPage> createState() => _WalletSelectionPageState();
}

class _WalletSelectionPageState extends State<WalletSelectionPage> {
  bool _isLoading = false;

  Future<bool> _checkKYCStatus(String walletType) async {
    // Implement your KYC verification logic here
    // This is a placeholder - replace with actual API calls
    await Future.delayed(const Duration(seconds: 1)); // Simulated API call
    return true; // Return actual KYC status
  }

  Future<bool> _connectWallet(String walletType) async {
    // Implement your wallet connection logic here
    // This is a placeholder - replace with actual wallet connection
    await Future.delayed(const Duration(seconds: 1)); // Simulated connection
    return true; // Return actual connection status
  }

  Future<void> _handleWalletSelection(String walletType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check KYC status
      final isKYCApproved = await _checkKYCStatus(walletType);
      
      if (!isKYCApproved) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC verification required for this wallet')),
        );
        return;
      }

      // Connect wallet
      final isConnected = await _connectWallet(walletType);
      
      if (!mounted) return;
      
      if (isConnected) {
        // Navigate to service selection screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ServiceSelectionScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect wallet')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title at the top
                  // const Text(
                  //   'CONNECT YOUR WALLET',
                  //   style: TextStyle(
                  //     fontSize: 25,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.black,
                  //   ),
                  // ),
                  
                  // Expanded to push content to top and bottom
                  Expanded(
                    child: Center(
                      // Image centered in the middle
                      child: Image.asset(
                        'assets/images/wallet_image.jpg',
                        height: 300, // Increased height for better visibility
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Container at the bottom
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      children: [
                        _buildWalletOption(
                          onTap: () => _handleWalletSelection('binance'),
                          icon: Icons.currency_bitcoin,
                          title: 'BINANCE',
                          color: Colors.orange,
                        ),
                        const Divider(
                          color: Colors.black54,
                          height: 40,
                        ),
                        _buildWalletOption(
                          onTap: () => _handleWalletSelection('bybit'),
                          icon: Icons.account_balance_wallet,
                          title: 'BYBIT',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletOption({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.black54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}