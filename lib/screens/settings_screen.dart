import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techsphere/screens/login_screen.dart';
import 'package:techsphere/widgets/progress_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  String _id = '';
  String _nickname = '';
  String _photoUrl = '';
  String _aboutMe = '';
  bool _isLoading = false;

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _id = _prefs!.getString('id') ?? '';
      _nickname = _prefs!.getString('nickname') ?? '';
      _photoUrl = _prefs!.getString('photoUrl') ?? '';
      _aboutMe = _prefs!.getString('aboutMe') ?? '';
      _nicknameController.text = _nickname;
      _aboutMeController.text = _aboutMe;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profilePhotos')
          .child('$_id.jpg');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        uploadTask = ref.putFile(File(picked.path));
      }

      await uploadTask;
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('usersChat')
          .doc(_id)
          .update({'photoUrl': url});
      await _prefs!.setString('photoUrl', url);
      setState(() {
        _photoUrl = url;
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Profile photo updated!');
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: 'Upload failed: $e');
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final aboutMe = _aboutMeController.text.trim();
    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: 'Nickname cannot be empty');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('usersChat')
          .doc(_id)
          .update({'nickname': nickname, 'aboutMe': aboutMe});
      await _prefs!.setString('nickname', nickname);
      await _prefs!.setString('aboutMe', aboutMe);
      setState(() {
        _nickname = nickname;
        _aboutMe = aboutMe;
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Profile saved!');
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: 'Save failed: $e');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    await _prefs?.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? circularProgress()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _photoUrl.isNotEmpty
                              ? CachedNetworkImageProvider(_photoUrl)
                              : null,
                          child: _photoUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.white)
                              : null,
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.lightBlueAccent,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.edit,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Nickname',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _aboutMeController,
                    decoration: const InputDecoration(
                      labelText: 'About Me',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
