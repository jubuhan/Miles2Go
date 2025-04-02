import 'dart:convert';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletConnectService {
  Web3App? _web3app;
  SessionData? _sessionData;
  final _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // User ID to associate wallet with
  String? _userId;
  
  // Constructor that accepts userId
  WalletConnectService({String? userId}) {
    _userId = userId ?? _auth.currentUser?.uid;
    debugPrint('WalletConnectService initialized with userId: $_userId');
  }
  
  // Getter for userId
  String? get userId => _userId ?? _auth.currentUser?.uid;
  
  // Method to update userId if not available at initialization
  void setUserId(String id) {
    if (_userId != id) {
      debugPrint('Setting userId to: $id');
      _userId = id;
      
      // If wallet is already connected, update the user document
      if (isConnected) {
        debugPrint('Wallet already connected, updating user document with new userId');
        _updateUserLastActive();
        saveUserToFirestore();
      }
    }
  }
  
  String? get walletAddress {
    if (_sessionData == null) return null;
    final accounts = _sessionData!.namespaces['eip155']?.accounts;
    if (accounts == null || accounts.isEmpty) return null;
    return accounts.first.split(':').last;
  }
  
  bool get isConnected => _sessionData != null && walletAddress != null;

  /// Initialize the WalletConnect client
  Future<void> initWalletConnect({Function(String? address)? onSessionRestored}) async {
    if (_web3app != null) {
      // If already initialized, just check for existing session
      return await _restoreExistingSession(onRestored: onSessionRestored);
    }
    
    try {
      _web3app = await Web3App.createInstance(
        projectId: '2e933723437ddb31f1723a48fded47b6', // Replace with your actual WalletConnect Project ID
        metadata: const PairingMetadata(
          name: 'Miles2Go App',
          description: 'Connect your wallet to Miles2Go',
          url: 'https://miles2go.com/',
          icons: ['https://miles2go.com/logo.png'],
        ),
      );
      
      debugPrint('WalletConnect initialized successfully');
      
      // Check for existing session
      await _restoreExistingSession(onRestored: onSessionRestored);
    } catch (e) {
      debugPrint('Error initializing WalletConnect: $e');
      rethrow;
    }
  }

  /// Check for and restore any existing session
  Future<void> _restoreExistingSession({Function(String? address)? onRestored}) async {
    try {
      final sessionString = await _secureStorage.read(key: 'wallet_session');
      if (sessionString == null) {
        debugPrint('No session found in secure storage');
        if (onRestored != null) onRestored(null);
        return;
      }
      
      // Parse stored session - this is a simplified example
      // In a real app, you would need to handle the session restoration properly
      // according to the WalletConnect v2 SDK
      debugPrint('Found existing session, attempting to restore');
      
      // Check if session is still active
      final sessions = _web3app?.sessions.getAll();
      if (sessions != null && sessions.isNotEmpty) {
        _sessionData = sessions.first;
        debugPrint('Session restored: ${walletAddress}');
        
        // Get current user if needed
        _ensureUserId();
        
        // Check if userId is available
        if (userId == null) {
          debugPrint('Warning: Session restored but userId is null. Cannot update user document.');
        } else {
          debugPrint('Updating user document for userId: $userId');
          // Update the last active timestamp
          await _updateUserLastActive();
        }
        
        // Call the callback if provided
        if (onRestored != null) onRestored(walletAddress);
      } else {
        debugPrint('No active sessions found in WalletConnect client');
        if (onRestored != null) onRestored(null);
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      // If restoration fails, clear the stored session
      await _secureStorage.delete(key: 'wallet_session');
      if (onRestored != null) onRestored(null);
    }
  }

  /// Make sure userId is available
  void _ensureUserId() {
    if (_userId == null) {
      _userId = _auth.currentUser?.uid;
      debugPrint('Retrieved userId from Firebase Auth: $_userId');
    }
  }

  /// Connect to a wallet using WalletConnect
  Future<void> connectWallet(Function(String) logUpdate) async {
    if (_web3app == null) {
      await initWalletConnect();
    }
    
    // Ensure we have a userId
    _ensureUserId();
    if (userId == null) {
      logUpdate('❌ No user ID available. Please log in first.');
      throw Exception('User ID not available. Please log in first.');
    }
    
    try {
      logUpdate('🔄 Initializing connection...');
      
      // Test Firestore connection first
      bool connectionOk = await _testFirestoreConnection();
      if (!connectionOk) {
        logUpdate('❌ Cannot access Firestore. Please check your connection.');
        throw Exception('Cannot access Firestore. Please check your connection.');
      }
      
      final connectResponse = await _web3app!.connect(
        optionalNamespaces: {
          'eip155': const RequiredNamespace(
            chains: ['eip155:1'], // Ethereum Mainnet
            methods: ["personal_sign", "eth_sendTransaction"],
            events: ["chainChanged", "accountsChanged"],
          ),
        },
      );

      final uri = connectResponse.uri;
      if (uri == null) {
        throw Exception('Connection URI not generated');
      }

      logUpdate('🔄 Opening MetaMask...');
      
      // First try to open MetaMask directly
      final url = 'metamask://wc?uri=${Uri.encodeComponent('$uri')}';
      final canOpenApp = await canLaunchUrlString(url);
      
      if (canOpenApp) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web browser
        final webUrl = 'https://metamask.app.link/wc?uri=${Uri.encodeComponent('$uri')}';
        await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
      }

      logUpdate('🔄 Waiting for connection approval...');
      
      // Wait for the user to approve the connection
      _sessionData = await connectResponse.session.future;
      
      // Save the session for later restoration
      await _saveSession();
      
      // Save user data to Firestore
      final saveResult = await saveUserToFirestore();
      if (saveResult) {
        logUpdate('✅ Connected to MetaMask: ${walletAddress}');
      } else {
        logUpdate('⚠️ Connected to MetaMask, but failed to save to database: ${walletAddress}');
      }
    } catch (e) {
      logUpdate('❌ Connection error: ${e.toString()}');
      throw Exception('Failed to connect wallet: ${e.toString()}');
    }
  }

  /// Save the session for later restoration
  Future<void> _saveSession() async {
    if (_sessionData == null) return;
    
    try {
      // Simplified session storage - in a real app, you would need to
      // properly serialize the session according to the SDK
      final sessionToSave = jsonEncode({
        'topic': _sessionData!.topic,
        'pairingTopic': _sessionData!.pairingTopic,
      });
      
      await _secureStorage.write(key: 'wallet_session', value: sessionToSave);
      debugPrint('Session saved successfully');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  /// Test Firestore connection
  Future<bool> _testFirestoreConnection() async {
    if (userId == null) return false;
    
    try {
      debugPrint('Testing Firestore connection for user: $userId');
      
      // Simple write operation to test permissions
      final docRef = _firestore.collection('users').doc(userId);
      
      // Check if document exists
      final docSnapshot = await docRef.get();
      debugPrint('User document exists: ${docSnapshot.exists}');
      
      // Try to write to it
      await docRef.set({
        'lastConnectionTest': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Firestore connection test successful');
      return true;
    } catch (e) {
      debugPrint('Firestore connection test failed: $e');
      return false;
    }
  }

  /// Disconnect the wallet
  Future<void> disconnectWallet() async {
    if (_web3app != null && _sessionData != null) {
      try {
        await _web3app!.disconnectSession(
          topic: _sessionData!.topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
        
        // Ensure userId is available
        _ensureUserId();
        
        // Update user status in Firestore
        if (userId != null && walletAddress != null) {
          await _firestore.collection('users').doc(userId).set({
            'wallet': {
              'isActive': false,
              'disconnectedAt': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
        }
        
        // Clear local storage
        await _secureStorage.delete(key: 'wallet_session');
        
        _sessionData = null;
        debugPrint('Wallet disconnected successfully');
      } catch (e) {
        debugPrint('Error disconnecting wallet: $e');
      }
    }
  }

  /// Request authentication with the connected wallet
  Future<bool> requestAuthWithWallet(Function(String) logUpdate) async {
    if (_web3app == null || _sessionData == null) {
      await connectWallet(logUpdate);
    }

    logUpdate('🔄 Requesting authentication...');

    try {
      final authResponse = await _web3app!.requestAuth(
        pairingTopic: _sessionData!.pairingTopic,
        params: AuthRequestParams(
          chainId: 'eip155:1',
          domain: 'miles2go.com',
          aud: 'https://miles2go.com/login',
        ),
      );

      final authCompletion = await authResponse.completer.future;
      
      if (authCompletion.error == null) {
        logUpdate('✅ Authentication Successful');
        return true;
      } else {
        logUpdate('❌ Auth Error: ${authCompletion.error}');
        return false;
      }
    } catch (e) {
      logUpdate('❌ Authentication failed: ${e.toString()}');
      return false;
    }
  }

  /// Save user wallet data to Firestore within the user document
  Future<bool> saveUserToFirestore() async {
    final address = walletAddress;
    if (address == null) {
      debugPrint('Cannot save user: walletAddress is null');
      return false;
    }
    
    // Ensure userId is available
    _ensureUserId();
    
    // Check if userId is provided
    if (userId == null) {
      debugPrint('No userId provided to associate wallet with user');
      return false;
    }
    
    debugPrint('Attempting to save wallet $address for user $userId');
    
    try {
      // First get document to see if it exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      debugPrint('User document exists: ${userDoc.exists}');
      
      final walletData = {
        'address': address.toLowerCase(),
        'walletType': 'metamask',
        'chainId': 1, // Ethereum Mainnet
        'connectedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      
      // Approach 1: Create/update with merge
      await _firestore.collection('users').doc(userId).set({
        'wallet': walletData,
        'walletAddress': address.toLowerCase(), // For backward compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Successfully saved wallet data with set');
      
      // Verify the update
      final updatedDoc = await _firestore.collection('users').doc(userId).get();
      if (!updatedDoc.exists) {
        debugPrint('Error: Document still does not exist after save');
        return false;
      }
      
      final data = updatedDoc.data();
      if (data == null || !data.containsKey('wallet')) {
        debugPrint('Error: Wallet field not found in document after save');
        debugPrint('Document data: $data');
        
        // Try alternative approach as fallback
        debugPrint('Trying alternative approach...');
        await _firestore.collection('users').doc(userId).set({
          'wallet': walletData,
          'walletAddress': address.toLowerCase(),
        }, SetOptions(merge: true));
        
        return false;
      }
      
      debugPrint('Verification successful: ${data['wallet']}');
      return true;
    } catch (e) {
      debugPrint('Error saving wallet data to user document: $e');
      // Try an alternative approach if first one fails
      try {
        debugPrint('Trying alternative Firestore update approach...');
        
        // Direct field updates as fallback
        await _firestore.collection('users').doc(userId).update({
          'walletAddress': walletAddress!.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Then try to add wallet object
        await _firestore.collection('users').doc(userId).set({
          'wallet': {
            'address': walletAddress!.toLowerCase(),
            'isActive': true,
            'lastActive': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        
        debugPrint('Alternative approach succeeded');
        return true;
      } catch (fallbackError) {
        debugPrint('Alternative approach also failed: $fallbackError');
        return false;
      }
    }
  }
  
  /// Update user's last active timestamp
  Future<bool> _updateUserLastActive() async {
    // Ensure userId is available
    _ensureUserId();
    
    if (userId == null) {
      debugPrint('Cannot update user: userId is null');
      return false;
    }
    
    if (walletAddress == null) {
      debugPrint('Cannot update user: walletAddress is null');
      return false;
    }
    
    try {
      debugPrint('Updating user $userId with wallet $walletAddress last active status');
      
      await _firestore.collection('users').doc(userId).set({
        'wallet': {
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Successfully updated user last active status');
      return true;
    } catch (e) {
      debugPrint('Error updating user last active: $e');
      
      // Check if document exists
      try {
        final docExists = await _firestore.collection('users').doc(userId).get();
        if (!docExists.exists) {
          // Create document if it doesn't exist
          await _firestore.collection('users').doc(userId).set({
            'wallet': {
              'address': walletAddress!.toLowerCase(),
              'walletType': 'metamask',
              'chainId': 1,
              'connectedAt': FieldValue.serverTimestamp(),
              'lastActive': FieldValue.serverTimestamp(),
              'isActive': true,
            },
            'walletAddress': walletAddress!.toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Created new user document');
          return true;
        }
      } catch (innerError) {
        debugPrint('Error checking document existence: $innerError');
      }
      return false;
    }
  }

  /// Send a transaction using the connected wallet
  Future<String?> sendTransaction({
    required String to,
    required String value, // In wei (e.g., "0x1" for 1 wei)
    String? data,
  }) async {
    if (_web3app == null || _sessionData == null) {
      throw Exception('Wallet not connected');
    }
    
    if (walletAddress == null) {
      throw Exception('No wallet address available');
    }
    
    // Ensure userId is available
    _ensureUserId();
    
    try {
      // Update last active timestamp
      await _updateUserLastActive();
      
      final response = await _web3app!.request(
        topic: _sessionData!.topic,
        chainId: 'eip155:1',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': walletAddress,
              'to': to,
              'value': value,
              'data': data ?? '0x',
            }
          ],
        ),
      );
      
      final txHash = response as String;
      
      // Save transaction to Firestore
      await _saveTransactionToFirestore(to, value, data, txHash);
      
      return txHash;
    } catch (e) {
      debugPrint('Error sending transaction: $e');
      return null;
    }
  }
  
  /// Save transaction data to Firestore within the user document
  Future<void> _saveTransactionToFirestore(
    String to,
    String value,
    String? data,
    String txHash,
  ) async {
    if (userId == null || walletAddress == null) return;
    
    try {
      // Create a transaction document with a unique ID
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add({
        'from': walletAddress!.toLowerCase(),
        'to': to,
        'value': value,
        'data': data,
        'txHash': txHash,
        'status': 'pending', // Initial status
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Also update the user document with the latest transaction
      await _firestore.collection('users').doc(userId).set({
        'lastTransaction': {
          'txHash': txHash,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      
      debugPrint('Transaction saved to Firestore');
    } catch (e) {
      debugPrint('Error saving transaction: $e');
    }
  }
  
  /// Get the connected wallet's balance
  Future<String?> getBalance() async {
    if (_web3app == null || _sessionData == null || walletAddress == null) {
      throw Exception('Wallet not connected');
    }
    
    try {
      final response = await _web3app!.request(
        topic: _sessionData!.topic,
        chainId: 'eip155:1',
        request: SessionRequestParams(
          method: 'eth_getBalance',
          params: [walletAddress!, 'latest'],
        ),
      );
      
      return response as String;
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return null;
    }
  }
  
  /// Debug method to print the current user document
  Future<void> debugUserDocument() async {
    if (userId == null) {
      debugPrint('No userId available for debugging');
      return;
    }
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        debugPrint('USER DOCUMENT STRUCTURE:');
        debugPrint(json.encode(data));
        
        if (data != null) {
          if (data.containsKey('wallet')) {
            debugPrint('✅ wallet field exists: ${data['wallet']}');
          } else {
            debugPrint('❌ wallet field missing');
          }
          
          if (data.containsKey('waller')) {
            debugPrint('⚠️ misspelled waller field exists: ${data['waller']}');
          }
        }
      } else {
        debugPrint('❌ User document does not exist');
      }
    } catch (e) {
      debugPrint('Error debugging document: $e');
    }
  }
}