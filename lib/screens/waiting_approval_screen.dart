import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexora_it/constants/app_theme.dart';
// هنا قمنا بحجب الـ Container المتضارب لحل المشكلة فوراً
import 'package:nexora_it/screens/home_screen.dart' hide Container; 

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationInitialized = false;
  bool _hasTriggeredApproval = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initializationSettings,
      );
      if (mounted) {
        setState(() {
          _notificationInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  Future<void> _showApprovalNotification() async {
    if (!_notificationInitialized) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'approval_channel_id',
      'Approval Alerts',
      channelDescription: 'Notifications for account approval status changes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotificationsPlugin.show(
        1001,
        'تم قبول الحساب 🎉',
        'تهانينا! تم قبول حسابك بنجاح في منصة نكسورا الاكاديمية.',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  void _triggerApprovalSequence() {
    if (!mounted || _hasTriggeredApproval) return;
    _hasTriggeredApproval = true;

    // 1. إطلاق الإشعار المحلي
    _showApprovalNotification();

    // 2. عرض نافذة الترحيب المنبثقة
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  Color(0xFF0A1931),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
              border: Border.all(
                color: AppTheme.accentColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentColor, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppTheme.accentColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'أهلاً بك في عائلة نكسورا!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'تم مراجعة بياناتك وقبول حسابك بنجاح. نتمنى لك رحلة أكاديمية متميزة.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: AppTheme.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ابدأ الرحلة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.greenAccent),
                  title: const Text('اتصال هاتف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('tel:772442154'));
                  },
                ),
                Divider(color: Colors.grey.shade800),
                ListTile(
                  leading: const Icon(Icons.message, color: Colors.green),
                  title: const Text('تواصل عبر الواتساب', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse('whatsapp://send?phone=+967772442154'),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) {
                      launchUrl(
                        Uri.parse('https://wa.me/967772442154'),
                        mode: LaunchMode.externalApplication,
                      );
                      return false;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBaseScreen({required Widget content, required List<Color> backgroundColors}) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: backgroundColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: GridPainter(),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectionScreen() {
    return _buildBaseScreen(
      backgroundColors: [const Color(0xFF1A0606), const Color(0xFF310A0A)],
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 60),
          ),
          const SizedBox(height: 40),
          const Text(
            'عذراً، تم رفض طلب انضمامك من قِبل الإدارة. يرجى التواصل مع الدعم الفني',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _showContactOptions(context),
              icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
              label: const Text(
                'اتصل بنا',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingScreen() {
    return _buildBaseScreen(
      backgroundColors: [const Color(0xFF060D1A), const Color(0xFF0A1931)],
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
            child: const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'يرجى الانتظار',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          Text(
            'تم إرسال طلب التسجيل بنجاح! يرجى انتظار موافقة الإدارة لتفعيل حسابك.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15, height: 1.6, fontFamily: 'Cairo'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedBackgroundScreen() {
    return _buildBaseScreen(
      backgroundColors: [const Color(0xFF061A0D), const Color(0xFF0A3119)],
      content: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentColor, size: 80),
          SizedBox(height: 20),
          Text(
            'تم تفعيل الحساب!',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return _buildBaseScreen(
      backgroundColors: [const Color(0xFF1E1E1E), const Color(0xFF121212)],
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 60),
          const SizedBox(height: 20),
          const Text(
            'حدث خطأ أثناء تحديث الحالة',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF060D1A),
        body: Center(
          child: Text('لم يتم العثور على حساب نشط', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorScreen(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentColor),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              if (!snapshot.data!.exists) {
                return _buildRejectionScreen();
              }

              final data = snapshot.data!.data();
              if (data != null) {
                final status = (data['status'] ?? 'pending').toString().trim();
                
                if (status == 'approved') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _triggerApprovalSequence();
                  });
                  return _buildApprovedBackgroundScreen();
                } else if (status == 'rejected') {
                  return _buildRejectionScreen();
                }
              }
            }

            return _buildPendingScreen();
          },
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const double step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}