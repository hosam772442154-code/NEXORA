import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:nexora_it/main.dart'; // To access themeNotifier

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  double _attendanceRate = 0.0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _userData = doc.data();
        _nameController.text = _userData?['name'] ?? '';
        _bioController.text = _userData?['bio'] ?? 'طالب جامعي شغوف بالتقنية.';
      }

      // Calculate attendance rate
      if (_userData?['role'] == 'طالب') {
        final attQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: user.uid)
            .get();
        
        int total = attQuery.docs.length;
        int presentCount = attQuery.docs.where((d) => d.data()['status'] == 'حضور').length;
        
        if (total > 0) {
          _attendanceRate = presentCount / total;
        } else {
          _attendanceRate = 1.0; // default 100% if no records yet
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: \$e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد التعديل', style: TextStyle(fontFamily: 'Cairo')),
          content: const Text('هل تريد حفظ التعديلات على ملفك الشخصي؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الملف بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء التحديث', style: TextStyle(fontFamily: 'Cairo'))));
      }
    }

    await _fetchProfileData();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير الصورة', style: TextStyle(fontFamily: 'Cairo')),
          content: const Text('هل تريد تعيين هذه الصورة كصورة شخصية لك؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance.ref().child('avatars').child('\${user.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'avatarUrl': url});
      
      await _fetchProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة', style: TextStyle(fontFamily: 'Cairo'))));
      }
    }

    setState(() => _isUploading = false);
  }

  Future<void> _onRefresh() async {
    await _fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarUrl = _userData?['avatarUrl'];
    final role = _userData?['role'] ?? 'طالب';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('الملف الشخصي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(themeNotifier.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                });
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.primaryColor,
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppTheme.accentColor, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              if (role == 'طالب') ...[
                const Text('سجل الحضور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _attendanceRate,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: _attendanceRate >= 0.75 ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                      Text(
                        '\${(_attendanceRate * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              const Text('البيانات الشخصية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم بالكامل',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'النبذة التعريفية (Bio)',
                  labelStyle: const TextStyle(fontFamily: 'Cairo'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.info_outline),
                ),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ التعديلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
