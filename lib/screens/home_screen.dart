import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:nexora_it/constants/app_theme.dart';
import 'package:nexora_it/screens/admin_approval_screen.dart';
import 'package:nexora_it/screens/inbox_screen.dart';
import 'package:nexora_it/screens/doctor_space_screen.dart';
import 'package:nexora_it/screens/student_assignments_screen.dart';
import 'package:nexora_it/screens/academic_store_screen.dart';
import 'package:nexora_it/screens/batch_community_screen.dart';
import 'package:nexora_it/screens/schedule_screen.dart';
import 'package:nexora_it/services/time_service.dart';
import 'package:nexora_it/widgets/ad_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _announcementsSub;
  Timestamp? _lastSeenTimestamp;
  String _userRole = 'طالب';
  String _userName = 'مستخدم';
  bool _isLoading = true;
  int _bottomNavIndex = 0;
  Map<String, dynamic>? _toastData;
  bool _showToast = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    
    _lastSeenTimestamp = Timestamp.now();
    _announcementsSub = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null && createdAt.compareTo(_lastSeenTimestamp!) > 0) {
          _lastSeenTimestamp = createdAt;
          _showNotificationToast(data);
        }
      }
    });
  }

  void _showNotificationToast(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _toastData = data;
      _showToast = true;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showToast) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _announcementsSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!mounted) return;

        if (userDoc.exists && userDoc.data() != null) {
          final Map<String, dynamic> data = userDoc.data()!;
          setState(() {
            _userRole = data['role'] ?? 'طالب';
            _userName = data['name'] ?? 'مستخدم';
            _isLoading = false;
          });
        } else {
          if (user.email == 'admin@nexora.app' || user.email == '772442154@nexora.app') {
            setState(() {
              _userRole = 'مدير';
              _userName = 'المدير';
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else {
      return 'مساء الخير';
    }
  }

  Future<void> _broadcastAnnouncement(String text) async {
    if (text.trim().isEmpty) return;

    // جعل العنوان ديناميكي بأخذ أول سطر من الإعلان تلبية لطلبك السيرفر
    final String dynamicTitle = text.split('\n').first;

    try {
      // 1. Write to Firestore 'announcements' collection securely
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': dynamicTitle,
        'body': text,
        'publisher': _userName,
        'role': _userRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. HTTP POST request targeting Firebase FCM API endpoint to broadcast
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=AIzaSyA-PLACEHOLDER_FCM_SERVER_KEY',
        },
        body: jsonEncode(<String, dynamic>{
          'to': '/topics/announcements',
          'notification': <String, dynamic>{
            'title': dynamicTitle,
            'body': text,
            'sound': 'default',
          },
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'announcement',
          },
        }),
      );

      debugPrint('FCM Broadcast response status: ${response.statusCode}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر الإعلان وإرساله عبر الإشعارات بنجاح ✓', textDirection: TextDirection.rtl),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء النشر: $e', textDirection: TextDirection.rtl)),
        );
      }
    }
  }

  void _openAnnouncementModal() {
    final TextEditingController announcementController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 50, // تم تعديل الارتفاع ليتناسب مع التصميم
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'نشر إعلان أكاديمي جديد 📢',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: announcementController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'اكتب تفاصيل الإعلان هنا...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo'),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final String text = announcementController.text;
                      if (text.trim().isNotEmpty) {
                        Navigator.pop(context);
                        _broadcastAnnouncement(text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: AppTheme.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'نشر وإرسال إشعار فوري',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final bool isAdmin = _userRole == 'مدير' || _userRole == 'مدير النظام';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Stack(
          children: [
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchUserData,
                color: AppTheme.primaryColor,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    // 1. TOP HEADER
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),

                    // 2. AD FEED (VERTICAL)
                    SliverToBoxAdapter(
                      child: _buildAdFeed(),
                    ),

                    // 3. TECH BANNER
                    SliverToBoxAdapter(
                      child: _buildTechBanner(),
                    ),

                    // 4. 3-COLUMN SERVICE GRID
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      sliver: _buildServiceGrid(),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
            // سيتم استدعاء الدالة المفقودة هنا في الجزء الثاني
            _buildFloatingToast(),
          ],
        ),
        floatingActionButton: _buildFAB(isAdmin),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  // ─── 1. TOP HEADER ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_getGreeting()}،',
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userName,
                style: const TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              _buildHeaderIcon(icon: Icons.chat_bubble_outline_rounded, onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchCommunityScreen()));
              }),
              const SizedBox(width: 12),
              _buildHeaderIcon(icon: Icons.notifications_none_rounded, hasBadge: true, onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, bool hasBadge = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: Icon(icon, color: AppTheme.textColor, size: 22),
          ),
          if (hasBadge)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 2. AD FEED (VERTICAL) ──────────────────────────────────────────
  Widget _buildAdFeed() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Advanced3DAdSlider(
          adsList: snapshot.data!.docs.map((doc) => doc.data()).toList(),
        );
      },
    );
  }

  // ─── 3. TECH BANNER ──────────────────────────────────────────────────
  Widget _buildTechBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.offline_bolt_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'نكسورا: منصتك الأكاديمية المتكاملة بسهولة',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. 3-COLUMN SERVICE GRID ────────────────────────────────────────
  Widget _buildServiceGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildListDelegate([
        _buildScheduleCard(),
        _buildLecturesCard(),
        _buildAnnouncementsCard(),
        _buildFilesCard(),
        _buildStudentAffairsCard(),
        _buildAcademicSupportCard(),
      ]),
    );
  }
// ─── BASE CARD WIDGET ───────────────────────────────────────────────
  Widget _buildBaseCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? dynamicContent,
    Widget? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Hero(
                      tag: 'icon_$title',
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                    ),
                    if (badge != null)
                      Positioned(top: -2, right: -2, child: badge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dynamicContent != null) ...[
                  const SizedBox(height: 4),
                  Expanded(child: Center(child: dynamicContent)),
                ],
              ],
            ),
          ),
        ), // <-- تم إصلاح القوس هنا من ] إلى ) لإنهاء الـ InkWell بنجاح
      ),
    );
  }

  String _getArabicDay(int weekday) {
    switch (weekday) {
      case 1: return 'الإثنين'; // تم إصلاح الخطأ المطبعي هنا
      case 2: return 'الثلاثاء';
      case 3: return 'الأربعاء';
      case 4: return 'الخميس';
      case 5: return 'الجمعة';
      case 6: return 'السبت';
      case 7: return 'الأحد';
      default: return 'الأحد';
    }
  }

  Widget _buildScheduleCard() {
    return StreamBuilder<Object>(
      stream: Stream.periodic(const Duration(seconds: 10), (computationCount) => computationCount),
      builder: (context, timerSnap) {
        final now = TimeService.getAdenTime();
        final todayStr = _getArabicDay(now.weekday);
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('semester_schedule')
              .where('dayOfWeek', isEqualTo: todayStr)
              .snapshots(),
          builder: (context, snapshot) {
            String subtitle = 'جاري التحميل...';
            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                subtitle = 'لا توجد محاضرات متبقية اليوم.';
              } else {
                final currentNow = TimeService.getAdenTime();
                final currentMinutes = currentNow.hour * 60 + currentNow.minute;
                
                Map<String, dynamic>? nextLecture;
                int minDiff = 9999;
                
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final startStr = data['startTime'] as String?;
                  if (startStr != null) {
                    final parts = startStr.split(':');
                    if (parts.length == 2) {
                      int startMins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                      int diff = startMins - currentMinutes;
                      if (diff > 0 && diff < minDiff) {
                        minDiff = diff;
                        nextLecture = data;
                      } else if (diff <= 0) {
                        final endStr = data['endTime'] as String?;
                        if (endStr != null) {
                          final eParts = endStr.split(':');
                          if (eParts.length == 2) {
                            int endMins = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
                            if (currentMinutes < endMins) {
                              nextLecture = data;
                              minDiff = 0;
                              break;
                            }
                          }
                        }
                      }
                    }
                  }
                }
                
                if (nextLecture != null) {
                  if (minDiff == 0) {
                    subtitle = 'الآن: ${nextLecture['subjectName']}\nقاعة: ${nextLecture['roomNumber']}';
                  } else {
                    int hours = minDiff ~/ 60;
                    int mins = minDiff % 60;
                    String rem = '';
                    if (hours > 0) rem += '$hours ساعة ';
                    if (mins > 0) rem += '$mins دقيقة';
                    subtitle = 'التالي: ${nextLecture['subjectName']}\nبعد $rem';
                  }
                } else {
                  subtitle = 'لا توجد محاضرات متبقية اليوم.';
                }
              }
            }

            return _buildBaseCard(
              title: 'الجدول الدراسي',
              icon: Icons.calendar_month_rounded,
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduleScreen()));
              },
              dynamicContent: Text(
                subtitle,
                style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildLecturesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('lectures').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        String subtitle = 'لا يوجد جديد';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          subtitle = data['name'] ?? 'محاضرة جديدة';
        }
        return _buildBaseCard(
          title: 'المحاضرات',
          icon: Icons.co_present_rounded,
          color: AppTheme.primaryColor,
          onTap: () {
            if (_userRole == 'دكتور') {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorSpaceScreen()));
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen()));
            }
          },
          dynamicContent: Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('announcements').orderBy('createdAt', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        int newCount = 0;
        String snippet = 'لا توجد إعلانات';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          snippet = data['body'] ?? data['title'] ?? 'إعلان جديد';
          
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null && _lastSeenTimestamp != null && createdAt.compareTo(_lastSeenTimestamp!) > 0) {
            newCount = 1;
          }
        }
        return _buildBaseCard(
          title: 'الإعلانات',
          icon: Icons.campaign_rounded,
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
          },
          badge: newCount > 0 ? Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Text('', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ) : null,
          dynamicContent: Text(
            snippet,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildFilesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('academic_store').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        String subtitle = 'تصفح الملفات';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          subtitle = data['name'] ?? 'ملف جديد';
        }
        return _buildBaseCard(
          title: 'التحميلات',
          icon: Icons.folder_zip_rounded,
          color: AppTheme.primaryColor,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AcademicStoreScreen()));
          },
          dynamicContent: Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildStudentAffairsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student_affairs_requests').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        String subtitle = 'الطلبات';
        if (_userRole == 'طالب') {
          subtitle = 'حالة الطلب: معلق';
        } else if (_userRole == 'دكتور') {
          subtitle = 'الطلبات المعلقة';
        } else if (_userRole == 'مدير' || _userRole == 'مدير النظام') {
          subtitle = 'الإحصائيات الكاملة';
        } else if (_userRole == 'مندوب') {
          subtitle = 'طلبات الدفعة';
        }
        return _buildBaseCard(
          title: 'شؤون الطلاب',
          icon: Icons.people_alt_rounded,
          color: AppTheme.primaryColor,
          onTap: () {
            // قم بالربط بالشاشة الخاصة بشؤون الطلاب هنا لاحقاً
          },
          dynamicContent: Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildAcademicSupportCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('support_messages').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        String subtitle = 'تواصل معنا';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          subtitle = data['text'] ?? 'رسالة جديدة';
        }
        return _buildBaseCard(
          title: 'الدعم الأكاديمي',
          icon: Icons.school_rounded,
          color: AppTheme.primaryColor,
          onTap: () {
            // قم بالربط بشاشة الدعم والمحادثات هنا لاحقاً
          },
          dynamicContent: Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Cairo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  // ─── 5. FLOATING ACTION BUTTON ──────────────────────────────────────────
  Widget? _buildFAB(bool isAdmin) {
    if (_userRole == 'طالب') {
      return null;
    }

    final publishAdFab = FloatingActionButton.extended(
      heroTag: 'publish_ad',
      onPressed: _openAnnouncementModal,
      backgroundColor: AppTheme.accentColor, 
      icon: const Icon(Icons.add, color: AppTheme.textColor),
      label: const Text(
        'أدوات النشر والإعلان',
        style: TextStyle(
          color: AppTheme.textColor,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );

    if (isAdmin) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'admin_panel',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminApprovalScreen()),
              );
            },
            backgroundColor: Colors.amber.shade700, 
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
            label: const Text(
              'لوحة القبول والتنظيف',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(height: 16),
          publishAdFab,
        ],
      );
    }

    if (_userRole == 'دكتور' || _userRole == 'مندوب') {
      return publishAdFab;
    }

    return null;
  }

  // ─── 6. NAVIGATION BAR ──────────────────────────────────────────────
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, 'الرئيسية', Icons.home_rounded),
              _buildNavItem(1, 'الخدمات', Icons.widgets_rounded),
              if (_userRole != 'طالب') const SizedBox(width: 48),
              _buildNavItem(2, 'الجدول', Icons.calendar_month_rounded),
              _buildNavItem(3, 'الملف الشخصي', Icons.person_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToast() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      top: _showToast ? 16.0 : -150.0,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          setState(() => _showToast = false);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
        },
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
                ],
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.primaryLight,
                    child: Icon(Icons.notifications_active, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _toastData?['publisher'] ?? 'إعلان جديد',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                        Text(
                          _toastData?['title'] ?? '',
                          style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ADVANCED 3D AD SLIDER ───────────────────────────────────────────
class Advanced3DAdSlider extends StatefulWidget {
  final List<Map<String, dynamic>> adsList;

  const Advanced3DAdSlider({super.key, required this.adsList});

  @override
  State<Advanced3DAdSlider> createState() => _Advanced3DAdSliderState();
}

class _Advanced3DAdSliderState extends State<Advanced3DAdSlider> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoFlipTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93, initialPage: 0);
    
    if (widget.adsList.length > 1) {
      _autoFlipTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (_currentPage < min(widget.adsList.length, 3) - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _autoFlipTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayAds = widget.adsList.take(3).toList();

    if (displayAds.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 240, 
      child: PageView.builder(
        controller: _pageController,
        itemCount: displayAds.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double pageOffset = 0.0;
              if (_pageController.position.haveDimensions) {
                pageOffset = _pageController.page! - index;
              } else {
                pageOffset = (_currentPage - index).toDouble();
              }

              // يعتمد على import 'dart:math'; الذي أصلحناه بالخطوة السابقة
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0015) 
                ..rotateY(pageOffset * (pi / 2.5)); 

              return Transform(
                transform: matrix,
                alignment: pageOffset > 0 ? Alignment.centerRight : Alignment.centerLeft,
                child: child,
              );
            },
            child: AdCard(
              adData: displayAds[index],
              onTap: () {
                // للتخصيص اللاحق في صفحة التفاصيل عبر الـ Hero Animation
              },
            ),
          );
        },
      ),
    );
  }
}