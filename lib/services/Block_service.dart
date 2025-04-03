import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/walletconnect.dart';
import 'package:web_socket_channel/io.dart';
import 'package:convert/convert.dart';

class BlockchainService {
  final String _rpcUrl = 'https://eth-sepolia.g.alchemy.com/v2/tCk57hVUM-QpnVmUQXEZjpz3Dc8Zo9m6';
  final String _wsUrl = 'wss://eth-sepolia.g.alchemy.com/v2/tCk57hVUM-QpnVmUQXEZjpz3Dc8Zo9m6';
  final String _contractAddress = '0x8426295e35e4e522ae3dddb19197a6c6d201a279';

  late DeployedContract _contract;
  late Web3Client _web3client;
  late WalletConnectService _walletService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;

  BlockchainService._internal() {
    _web3client = Web3Client(_rpcUrl, http.Client(), socketConnector: () {
      return IOWebSocketChannel.connect(_wsUrl).cast<String>();
    });
    _walletService = WalletConnectService();
    _initContract();
  }

  Future<void> _initContract() async {
    try {
      String abiString = await rootBundle.loadString('assets/contracts/RidePayment.json');
      var abiJson = jsonDecode(abiString);
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abiJson['abi']), 'RidePayment'),
        EthereumAddress.fromHex(_contractAddress),
      );
      log('Contract initialized at $_contractAddress');
    } catch (e) {
      log('Error initializing contract: $e');
    }
  }

  Future<String?> processRidePayment({
    required BuildContext context,
    required String rideId,
    required String driverWalletAddress,
    required double amountInEth,
    Function(String)? logUpdate,
  }) async {
    try {
      if (!_walletService.isConnected) {
        logUpdate?.call('Wallet not connected, reconnecting...');
        await _walletService.connectWallet(logUpdate ?? (s) => log(s));
        if (!_walletService.isConnected) throw Exception('Wallet connection failed');
      }

      final passengerId = FirebaseAuth.instance.currentUser?.uid;
      if (passengerId == null) throw Exception('User not authenticated');

      final passengerWalletAddress = _walletService.walletAddress;
      if (passengerWalletAddress == null) throw Exception('Passenger wallet not found');

      logUpdate?.call('Passenger wallet: ${passengerWalletAddress.substring(0, 10)}...');
      logUpdate?.call('Driver wallet: ${driverWalletAddress.substring(0, 10)}...');

      final amountInWei = (amountInEth * 1e18).toInt();
      final data = _encodePayForRideFunction(rideId, driverWalletAddress);
      if (data == null) throw Exception('Failed to encode payForRide function');

      logUpdate?.call('Sending ${amountInEth.toStringAsFixed(6)} ETH to contract...');
      final txHash = await _walletService.sendTransaction(
        to: _contractAddress,
        value: '0x${amountInWei.toRadixString(16)}',
        data: data,
      );

      if (txHash == null) throw Exception('Transaction failed or rejected');

      logUpdate?.call('Transaction submitted: ${txHash.substring(0, 10)}...');
      await _savePaymentTransaction(
        rideId: rideId,
        driverWalletAddress: driverWalletAddress,
        passengerWalletAddress: passengerWalletAddress,
        amount: amountInEth,
        txHash: txHash,
      );
      return txHash;
    } catch (e) {
      log('Error processing payment: $e');
      logUpdate?.call('Payment error: $e');
      return null;
    }
  }

  String? _encodePayForRideFunction(String rideId, String driverAddress) {
    try {
      final payForRideFunction = _contract.function('payForRide');
      final encodedFunction = payForRideFunction.encodeCall([
        rideId,
        EthereumAddress.fromHex(driverAddress),
      ]);
      final hexData = '0x${hex.encode(encodedFunction)}';
      log('Encoded payForRide: $hexData');
      return hexData;
    } catch (e) {
      log('Error encoding payForRide: $e');
      return null;
    }
  }

  Future<void> _savePaymentTransaction({
    required String rideId,
    required String driverWalletAddress,
    required String passengerWalletAddress,
    required double amount,
    required String txHash,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).collection('payments').add({
        'rideId': rideId,
        'amount': amount,
        'currency': 'ETH',
        'driverWallet': driverWalletAddress.toLowerCase(),
        'passengerWallet': passengerWalletAddress.toLowerCase(),
        'txHash': txHash,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'paymentType': 'crypto',
        'network': 'sepolia',
      });

      await _firestore.collection('rides').doc(rideId).set({
        'paymentStatus': 'paid',
        'paymentMethod': 'crypto',
        'paymentTxHash': txHash,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log('Payment saved to Firestore');
    } catch (e) {
      log('Error saving payment: $e');
    }
  }

  Future<String> checkPaymentStatus(String txHash) async {
    try {
      final receipt = await _web3client.getTransactionReceipt(txHash);
      return receipt?.status == true ? 'confirmed' : receipt == null ? 'pending' : 'failed';
    } catch (e) {
      log('Error checking payment status: $e');
      return 'unknown';
    }
  }
}