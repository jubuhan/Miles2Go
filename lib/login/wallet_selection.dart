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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.teal.shade800,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONNECT YOUR WALLET',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _buildWalletOption(
                            onTap: () => _handleWalletSelection('binance'),
                            icon: Icons.currency_bitcoin,
                            title: 'Binance Wallet',
                            color: Colors.orange,
                          ),
                          const Divider(
                            color: Colors.white24,
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}