import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nexora_it/core/nexora_theme.dart';
import 'package:nexora_it/screens/login_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_file_screen.dart';
import 'available_downloads_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unified Dashboard - Stage 2 Pure Firebase
// ─────────────────────────────────────────────────────────────────────────────

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with TickerProviderStateMixin {
  String _userRole = 'طالب';
  String _userName = 'مستخدم نكسورا';
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isUploading = false;

  final List<Map<String, String>> _courses = const <Map<String, String>>[
    <String, String>{'id': 'cs101', 'name': 'علوم الحاسوب', 'code': 'CS101'},
    <String, String>{'id': 'it202', 'name': 'شبكات وأمن معلومات', 'code': 'IT202'},
    <String, String>{'id': 'math105', 'name': 'رياضيات تطبيقية', 'code': 'MATH105'},
    <String, String>{'id': 'se301', 'name': 'هندسة البرمجيات', 'code': 'SE301'},
  ];
  String _selectedCourseId = 'cs101';

  final TextEditingController _announcementController = TextEditingController();
  final TextEditingController _assignmentNameController = TextEditingController();
  final TextEditingController _assignmentDeadlineController = TextEditingController();
  final TextEditingController _lectureNameController = TextEditingController();

  late final AnimationController _glowController;
  late final AnimationController _fadeController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fetchUserData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _announcementController.dispose();
    _assignmentNameController.dispose();
    _assignmentDeadlineController.dispose();
    _lectureNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.email == 'admin@nexora-it.app' ||
            user.email == '772442154@nexora-it.app') {
          setState(() {
            _userRole = 'الادمن';
            _userName = 'الادمن - حسام';
            _isAdmin = true;
            _isLoading = false;
          });
          return;
        }

        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          final Map<String, dynamic> data = userDoc.data()!;
          setState(() {
            _userRole = data['role'] ?? 'طالب';
            _userName = data['name'] ?? 'مستخدم نكسورا';
            _isAdmin = _userRole == 'الادمن';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء تحميل بيانات المستخدم: $e');
    }
  }

  // ── Google Drive Uploader ──
  Future<void> _pickAndUploadFile(String folder, Future<void> Function(String url, String name) onSuccess) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final PlatformFile pickedFile = result.files.first;
        final Uint8List? bytes = pickedFile.bytes;
        if (bytes == null) {
          _showSnackBar('لم يتم العثور على بيانات الملف');
          return;
        }

        setState(() => _isUploading = true);
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

        final Reference ref = FirebaseStorage.instance.ref().child('uploads/$fileName');
        await ref.putData(bytes);
        final String fileUrl = await ref.getDownloadURL();
        await onSuccess(fileUrl, pickedFile.name);

        setState(() => _isUploading = false);
        _showSnackBar('تم الرفع بنجاح');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar('خطأ في الرفع: $e');
    }
  }

  // ── Actions ──
  Future<void> _publishAnnouncement() async {
    final String text = _announcementController.text.trim();
    if (text.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('announcements').add(<String, dynamic>{
        'text': text,
        'senderName': _userName,
        'senderRole': _userRole,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _announcementController.clear();
      _showSnackBar('تم نشر التنبيه العاجل بنجاح');
    } catch (e) {
      _showSnackBar('فشل النشر: $e');
    }
  }

  Future<void> _approveUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update(<String, dynamic>{
        'isApproved': true,
        'status': 'approved',
      });
      _showSnackBar('تمت الموافقة بنجاح');
    } catch (e) {
      _showSnackBar('فشل الموافقة: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: NexoraTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: NexoraTheme.accentColor, width: 1.5),
        ),
      ),
    );
  }

  Future<bool> _isDownloaded(String fileName) async {
    if (kIsWeb) return false;
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File('${dir.path}/$fileName');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  void _openNotificationCenter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: NexoraTheme.cardColor.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: const Border(
                top: BorderSide(color: NexoraTheme.accentColor, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: NexoraTheme.accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'صندوق الإشعارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('announcements')
                          .orderBy('timestamp', descending: true)
                          .snapshots(includeMetadataChanges: true),
                      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('لا توجد إشعارات', style: TextStyle(color: Colors.white)),
                          );
                        }
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, dynamic> data = docs[index].data();
                            final String role = data['senderRole'] ?? '';
                            final String name = data['senderName'] ?? '';
                            final String text = data['text'] ?? '';

                            String prefix = '👤 ';
                            if (role == 'الادمن') prefix = '⚡ ';
                            if (role == 'دكتور') prefix = '📢 ';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: NexoraTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: NexoraTheme.dividerColor),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: NexoraTheme.accentColor.withValues(alpha: 0.15),
                                  child: Text(prefix, style: const TextStyle(fontSize: 18)),
                                ),
                                title: Text(
                                  '$prefix [$role] $name',
                                  style: const TextStyle(color: NexoraTheme.accentColor, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: NexoraTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(NexoraTheme.accentColor),
          ),
        ),
      );
    }

    final bool isRep = _userRole == 'مندوب';
    final bool isDoctor = _userRole == 'دكتور';
    final bool isAdminRole = _userRole == 'الادمن' || _isAdmin;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NexoraTheme.backgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: NexoraTheme.backgroundColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          title: const Text(
            'منصة نكسورا الأكاديمية',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: <Widget>[
            _buildNotificationBell(),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: NexoraTheme.errorColor),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder<void>(
                    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
                      return FadeTransition(opacity: animation, child: const LoginScreen());
                    },
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                  (_) => false,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            _DashboardGridBackground(glowAnimation: _glowAnimation),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_isUploading) _buildUploadLoader(),
                      const SizedBox(height: 16),
                      Text(
                        'مرحباً بك، $_userName',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'نوع الحساب: $_userRole',
                        style: const TextStyle(color: NexoraTheme.accentColor, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'المقررات الأكاديمية النشطة',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildCourseNavigation(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableDownloadsScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NexoraTheme.cardColor,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: NexoraTheme.dividerColor)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.cloud_download_rounded, color: NexoraTheme.accentColor),
                          label: const Text('تطبيقات وملفات هامة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildContentArea(),
                      const SizedBox(height: 32),
                      if (isRep || isAdminRole) ...<Widget>[
                        _buildToolkitExpansionTile('أدوات المندوب المعتمد', Icons.support_agent_rounded, _buildRepPanel()),
                        const SizedBox(height: 16),
                      ],
                      if (isDoctor || isAdminRole) ...<Widget>[
                        _buildToolkitExpansionTile('أدوات الدكتور الأكاديمي', Icons.workspace_premium_rounded, _buildDoctorPanel()),
                        const SizedBox(height: 16),
                      ],
                      if (isAdminRole) ...<Widget>[
                        _buildToolkitExpansionTile('أدوات القبول (الادمن)', Icons.admin_panel_settings_rounded, _buildAdminPanel()),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('announcements').snapshots(includeMetadataChanges: true),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return GestureDetector(
          onTap: _openNotificationCenter,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (BuildContext context, Widget? child) {
              return Container(
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: count > 0 ? <BoxShadow>[
                    BoxShadow(
                      color: NexoraTheme.accentColor.withValues(alpha: 0.5 * (_pulseAnimation.value - 1.0)),
                      blurRadius: 10 * _pulseAnimation.value,
                      spreadRadius: 2 * _pulseAnimation.value,
                    )
                  ] : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Icon(Icons.notifications_active_rounded, color: NexoraTheme.accentColor, size: 28),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: NexoraTheme.errorColor, shape: BoxShape.circle),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUploadLoader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: NexoraTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexoraTheme.accentColor, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: NexoraTheme.accentColor, blurRadius: 16, spreadRadius: -5),
        ],
      ),
      child: const Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(NexoraTheme.accentColor)),
          ),
          SizedBox(width: 16),
          Text('جاري رفع الملف إلى الخادم...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCourseNavigation() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _courses.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, String> course = _courses[index];
          final bool isSelected = course['id'] == _selectedCourseId;

          return GestureDetector(
            onTap: () => setState(() => _selectedCourseId = course['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NexoraTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? NexoraTheme.accentColor : NexoraTheme.dividerColor,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? const <BoxShadow>[
                  BoxShadow(color: NexoraTheme.accentColor, blurRadius: 16, spreadRadius: -5)
                ] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    course['name']!,
                    style: TextStyle(
                      color: isSelected ? NexoraTheme.accentColor : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(course['code']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NexoraTheme.cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NexoraTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.video_library_rounded, color: NexoraTheme.accentColor, size: 22),
              SizedBox(width: 10),
              Text('المحاضرات والمستندات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .doc(_selectedCourseId)
                .collection('lectures')
                .orderBy('timestamp', descending: true)
                .snapshots(includeMetadataChanges: true),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('لا توجد ملفات مرفوعة.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> data = docs[index].data();
                  final String name = data['name'] ?? '';
                  final String fileName = data['fileName'] ?? name;
                  return FutureBuilder<bool>(
                    future: _isDownloaded(fileName),
                    builder: (BuildContext ctx, AsyncSnapshot<bool> dlSnap) {
                      final bool isLocal = dlSnap.data ?? false;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: NexoraTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isLocal ? NexoraTheme.successColor : NexoraTheme.dividerColor),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(isLocal ? Icons.check_circle_rounded : Icons.cloud_download_rounded, 
                            color: isLocal ? NexoraTheme.successColor : NexoraTheme.accentColor, size: 28),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('بواسطة: ${data['uploadedBy'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          trailing: const Icon(Icons.download_rounded, color: Colors.white70),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolkitExpansionTile(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: NexoraTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NexoraTheme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            iconColor: NexoraTheme.accentColor,
            collapsedIconColor: Colors.white70,
            leading: Icon(icon, color: NexoraTheme.accentColor),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            children: children,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRepPanel() {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('رفع مستند للمقرر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolkitButton('اختيار ورفع ملف (PDF/Docs)', Icons.upload_file_rounded, () {
              _pickAndUploadFile('lectures/$_selectedCourseId', (String url, String name) async {
                await FirebaseFirestore.instance.collection('courses').doc(_selectedCourseId).collection('lectures').add(<String, dynamic>{
                  'name': name,
                  'fileName': name,
                  'fileUrl': url,
                  'uploadedBy': _userName,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              });
            }),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: NexoraTheme.dividerColor)),
            const Text('إضافة تكليف أكاديمي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInputTextField(_assignmentNameController, 'عنوان التكليف', Icons.assignment_outlined),
            const SizedBox(height: 12),
            _buildInputTextField(_assignmentDeadlineController, 'الموعد (مثال: 2026-08-01)', Icons.date_range_rounded),
            const SizedBox(height: 16),
            _buildToolkitButton('نشر التكليف', Icons.send_rounded, () async {
              if (_assignmentNameController.text.isEmpty) return;
              await FirebaseFirestore.instance.collection('courses').doc(_selectedCourseId).collection('assignments').add(<String, dynamic>{
                'name': _assignmentNameController.text,
                'deadline': _assignmentDeadlineController.text,
                'postedBy': _userName,
                'timestamp': FieldValue.serverTimestamp(),
              });
              _assignmentNameController.clear();
              _showSnackBar('تم نشر التكليف');
            }),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: NexoraTheme.dividerColor)),
            const Text('تطبيقات وملفات عامة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolkitButton('رفع تطبيق/ملف جديد', Icons.post_add_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddFileScreen(userName: _userName, userRole: _userRole)));
            }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildDoctorPanel() {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('إرسال تنبيه عاجل للطلاب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInputTextField(_announcementController, 'نص التنبيه العاجل', Icons.campaign_rounded),
            const SizedBox(height: 16),
            _buildToolkitButton('نشر الإعلان', Icons.send_rounded, _publishAnnouncement),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: NexoraTheme.dividerColor)),
            const Text('رفع محاضرة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolkitButton('اختيار ورفع فيديو/ملف', Icons.video_call_rounded, () {
              _pickAndUploadFile('lectures/$_selectedCourseId', (String url, String name) async {
                await FirebaseFirestore.instance.collection('courses').doc(_selectedCourseId).collection('lectures').add(<String, dynamic>{
                  'name': name,
                  'fileName': name,
                  'fileUrl': url,
                  'uploadedBy': _userName,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              });
            }),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: NexoraTheme.dividerColor)),
            const Text('تطبيقات وملفات عامة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolkitButton('رفع تطبيق/ملف جديد', Icons.post_add_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddFileScreen(userName: _userName, userRole: _userRole)));
            }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAdminPanel() {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('الحسابات المعلقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'pending').snapshots(includeMetadataChanges: true),
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300, width: 2),
                      ),
                      child: Text(
                        'Error: ${snapshot.error.toString()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('لا توجد طلبات معلقة.', style: TextStyle(color: Colors.white70));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> data = docs[index].data();
                    final String uid = docs[index].id;
                    final String profileUrl = data['profilePictureUrl'] ?? '';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: NexoraTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: NexoraTheme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: profileUrl.startsWith('http')
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: profileUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (BuildContext c, String url) => const CircularProgressIndicator(),
                                      errorWidget: (BuildContext c, String url, Object err) => const Icon(Icons.error),
                                    ),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person_rounded)),
                            title: Text(data['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: data['role'] == 'دكتور' || data['role'] == 'طبيب'
                                          ? const Color(0xFF00B8E0).withOpacity(0.15)
                                          : data['role'] == 'طالب'
                                              ? NexoraTheme.successColor.withOpacity(0.15)
                                              : Colors.purpleAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: data['role'] == 'دكتور' || data['role'] == 'طبيب'
                                            ? const Color(0xFF00B8E0)
                                            : data['role'] == 'طالب'
                                                ? NexoraTheme.successColor
                                                : Colors.purpleAccent,
                                      ),
                                    ),
                                    child: Text(
                                      data['role'] ?? 'مستخدم',
                                      style: TextStyle(
                                        color: data['role'] == 'دكتور' || data['role'] == 'طبيب'
                                            ? const Color(0xFF00D2FF)
                                            : data['role'] == 'طالب'
                                                ? NexoraTheme.successColor
                                                : Colors.purpleAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${data['phone']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: NexoraTheme.successColor),
                              onPressed: () => _approveUser(uid),
                              child: const Text('موافقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (data['profilePictureUrl'] != null && data['profilePictureUrl'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  data['profilePictureUrl'],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: NexoraTheme.backgroundColor,
                                      child: const Center(child: CircularProgressIndicator()),
                                    );
                                  },
                                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: NexoraTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: NexoraTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: NexoraTheme.dividerColor)),
            const Text('تطبيقات وملفات عامة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildToolkitButton('رفع تطبيق/ملف جديد', Icons.post_add_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddFileScreen(userName: _userName, userRole: _userRole)));
            }),
          ],
        ),
      ),
    ];
  }

  Widget _buildInputTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        filled: true,
        fillColor: NexoraTheme.backgroundColor,
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: NexoraTheme.dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: NexoraTheme.dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: NexoraTheme.accentColor, width: 2)),
      ),
    );
  }

  Widget _buildToolkitButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: NexoraTheme.accentColor),
        style: ElevatedButton.styleFrom(
          backgroundColor: NexoraTheme.accentColor.withValues(alpha: 0.15),
          foregroundColor: NexoraTheme.accentColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: NexoraTheme.accentColor.withValues(alpha: 0.5)),
          ),
        ),
        onPressed: onPressed,
        label: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class _DashboardGridBackground extends StatelessWidget {
  const _DashboardGridBackground({required this.glowAnimation});

  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _GridPainter(glowAnimation.value),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.glow);

  final double glow;
  static const double _spacing = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFF00D2FF).withValues(alpha: 0.02 + 0.015 * glow)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final Paint dotPaint = Paint()
      ..color = const Color(0xFF00D2FF).withValues(alpha: 0.06 + 0.03 * glow)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += _spacing) {
      for (double y = 0; y < size.height; y += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.glow != glow;
}
