import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techsphere/screens/home_screen.dart';
import 'package:techsphere/widgets/progress_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadySignedIn();
  }

  Future<void> _checkAlreadySignedIn() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final bool signedIn = await _googleSignIn.isSignedIn();
    if (signedIn && mounted) {
      final uid = prefs.getString('id') ?? '';
      if (uid.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(currentUserId: uid)),
        );
        return;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final UserCredential result =
          await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = result.user;

      if (firebaseUser == null) {
        Fluttertoast.showToast(msg: 'Sign in failed. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      // Check if user already exists in Firestore
      final QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('usersChat')
          .where('id', isEqualTo: firebaseUser.uid)
          .get();

      final prefs = await SharedPreferences.getInstance();

      if (existing.docs.isEmpty) {
        // New user — create profile
        await FirebaseFirestore.instance
            .collection('usersChat')
            .doc(firebaseUser.uid)
            .set({
          'nickname': firebaseUser.displayName ?? '',
          'photoUrl': firebaseUser.photoURL ?? '',
          'id': firebaseUser.uid,
          'aboutMe': 'I am using TechSphere',
          'createdAt':
              DateTime.now().microsecondsSinceEpoch.toString(),
          'chattingWith': null,
          'isOnline': false,
          'lastSeen': null,
          'typingTo': null,
        });
        await prefs.setString('id', firebaseUser.uid);
        await prefs.setString('nickname', firebaseUser.displayName ?? '');
        await prefs.setString('photoUrl', firebaseUser.photoURL ?? '');
        await prefs.setString('aboutMe', 'I am using TechSphere');
      } else {
        final data =
            existing.docs[0].data() as Map<String, dynamic>;
        await prefs.setString('id', data['id'] as String? ?? firebaseUser.uid);
        await prefs.setString(
            'nickname', data['nickname'] as String? ?? '');
        await prefs.setString(
            'photoUrl', data['photoUrl'] as String? ?? '');
        await prefs.setString('aboutMe', data['aboutMe'] as String? ?? '');
      }

      Fluttertoast.showToast(msg: 'Welcome to TechSphere!');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => HomeScreen(currentUserId: firebaseUser.uid)),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Sign in failed: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.lightBlueAccent, Colors.purpleAccent],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'TechSphere',
              style: TextStyle(
                fontSize: 72.0,
                color: Colors.white,
                fontFamily: 'Signatra',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect. Chat. Collaborate.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _handleSignIn,
              child: Container(
                width: 270.0,
                height: 65.0,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/google_signin_button.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) circularProgress(),
          ],
        ),
      ),
    );
  }
}
