import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';
import '../widgets/neo_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<DataProvider>(context, listen: false).localUser;
      if (user != null) {
        _nameController.text = user.name.replaceAll(' (You)', '');
        if (user.upiId != null) {
          _upiController.text = user.upiId!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final upi = _upiController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name cannot be empty')));
      return;
    }
    if (upi.isNotEmpty) {
      final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
      if (!upiRegex.hasMatch(upi)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid UPI ID (e.g. name@bank)')));
        return;
      }
    }
    dataProvider.updateLocalUserProfile(name, upi.isEmpty ? null : upi);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully!')));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeoCard(
              color: AppTheme.neoYellow,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('DISPLAY NAME', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(color: Colors.black54),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text('UPI ID (Optional)', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _upiController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'example@upi',
                      hintStyle: TextStyle(color: Colors.black54),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your UPI ID is used to generate QR codes so friends can pay you back instantly.',
                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            NeoButton(
              onPressed: _saveProfile,
              color: AppTheme.neoPink,
              child: const Center(child: Text('SAVE PROFILE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18))),
            ),
          ],
        ),
      ),
    );
  }
}
