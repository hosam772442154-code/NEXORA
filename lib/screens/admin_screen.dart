import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexora_it/core/nexora_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Screen – Pending User Requests (Dark Neon Grid)
// ─────────────────────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // ── Approve User ──
  Future<void> _approveUser(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(<String, dynamic>{
        'isApproved': true,
        'status': 'approved',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded,
                  color: NexoraTheme.successColor, size: 20),
              SizedBox(width: 10),
              Text(
                'تمت الموافقة بنجاح ✓',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: NexoraTheme.primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          backgroundColor: NexoraTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: NexoraTheme.successColor),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل الموافقة: $e',
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: NexoraTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Reject / Delete User ──
  Future<void> _rejectUser(String uid) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1B263B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: NexoraTheme.errorColor.withOpacity(0.4)),
            ),
            title: const Text(
              'تأكيد الرفض',
              style: TextStyle(
                  color: NexoraTheme.primaryTextColor,
                  fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'هل أنت متأكد من رفض هذا الطلب؟',
              style: TextStyle(color: NexoraTheme.secondaryTextColor),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: NexoraTheme.secondaryTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NexoraTheme.errorColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('رفض',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(<String, dynamic>{'status': 'rejected'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم رفض الطلب',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white)),
          backgroundColor: NexoraTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('Reject error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C14),
        body: Stack(
          children: <Widget>[
            // Grid background
            _AdminGridBackground(glowAnimation: _glowAnimation),
            // Top glow orb
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (BuildContext context, Widget? child) {
                return Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          NexoraTheme.accentColor
                              .withOpacity(0.10 * _glowAnimation.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Main content
            SafeArea(
              child: Column(
                children: <Widget>[
                  _buildTopBar(),
                  _buildHeader(),
                  Expanded(child: _buildPendingUsersStream()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (BuildContext context, Widget? child) {
              return Material(
                color: const Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NexoraTheme.accentColor
                            .withOpacity(0.3 * _glowAnimation.value),
                      ),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: NexoraTheme.primaryTextColor, size: 22),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          const Text(
            'لوحة القبول',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (BuildContext context, Widget? child) {
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: NexoraTheme.accentColor
                        .withOpacity(0.5 * _glowAnimation.value),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: NexoraTheme.accentColor
                          .withOpacity(0.2 * _glowAnimation.value),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: NexoraTheme.accentColor,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'الحسابات المعلّقة',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'مراجعة طلبات التسجيل الجديدة والموافقة عليها',
            style: TextStyle(
              color: NexoraTheme.secondaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── StreamBuilder (NO role filter – all pending users) ──
  Widget _buildPendingUsersStream() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .snapshots(includeMetadataChanges: true),
      builder: (BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        // ── Error State ──
        if (snapshot.hasError) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade300, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في جلب البيانات',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // ── Loading State ──
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: NexoraTheme.accentColor,
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        // ── Empty State ──
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NexoraTheme.successColor.withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: NexoraTheme.successColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'لا توجد طلبات معلّقة',
                  style: TextStyle(
                    color: NexoraTheme.primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'جميع الطلبات تمت مراجعتها',
                  style: TextStyle(
                    color: NexoraTheme.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // ── Pending Users List ──
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            final String uid = docs[index].id;
            return _PendingUserCard(
              data: data,
              uid: uid,
              glowAnimation: _glowAnimation,
              onApprove: () => _approveUser(uid),
              onReject: () => _rejectUser(uid),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Pending User Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingUserCard extends StatelessWidget {
  const _PendingUserCard({
    required this.data,
    required this.uid,
    required this.glowAnimation,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> data;
  final String uid;
  final Animation<double> glowAnimation;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final String role = (data['role'] ?? 'مستخدم').toString();
    final String name = (data['name'] ?? '—').toString();
    final String email = (data['email'] ?? '—').toString();
    final String phone = (data['phone'] ?? '—').toString();
    final String gender = (data['gender'] ?? '—').toString();

    final bool isDoctor = role == 'دكتور';
    final String subject = (data['subject'] ?? '—').toString();
    final String uniId = (data['uniId'] ?? '—').toString();

    // Role badge colors
    Color roleBadgeColor;
    Color roleBadgeBg;
    IconData roleIcon;
    switch (role) {
      case 'دكتور':
        roleBadgeColor = const Color(0xFF00D2FF);
        roleBadgeBg = const Color(0xFF00D2FF).withOpacity(0.12);
        roleIcon = Icons.workspace_premium_rounded;
        break;
      case 'طالب':
        roleBadgeColor = NexoraTheme.successColor;
        roleBadgeBg = NexoraTheme.successColor.withOpacity(0.12);
        roleIcon = Icons.school_rounded;
        break;
      case 'مندوب':
        roleBadgeColor = Colors.purpleAccent;
        roleBadgeBg = Colors.purpleAccent.withOpacity(0.12);
        roleIcon = Icons.support_agent_rounded;
        break;
      default:
        roleBadgeColor = NexoraTheme.accentColor;
        roleBadgeBg = NexoraTheme.accentColor.withOpacity(0.12);
        roleIcon = Icons.person_rounded;
    }

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (BuildContext context, Widget? child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1729),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: roleBadgeColor.withOpacity(0.20 + 0.10 * glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: roleBadgeColor.withOpacity(0.06 * glowAnimation.value),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Top: Role badge + Gender ──
            Row(
              children: <Widget>[
                // Role Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: roleBadgeBg,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: roleBadgeColor.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(roleIcon, color: roleBadgeColor, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        role,
                        style: TextStyle(
                          color: roleBadgeColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Gender badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: NexoraTheme.accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: NexoraTheme.accentColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        gender == 'ذكر'
                            ? Icons.male_rounded
                            : Icons.female_rounded,
                        color: NexoraTheme.accentColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        gender,
                        style: const TextStyle(
                          color: NexoraTheme.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Pending indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'معلّق',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Name (prominent) ──
            Text(
              name,
              style: const TextStyle(
                color: NexoraTheme.primaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 16),

            // ── Divider ──
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    roleBadgeColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Conditional Details ──
            if (isDoctor) ...<Widget>[
              _buildDetailRow(
                icon: Icons.phone_android_rounded,
                label: 'رقم الهاتف',
                value: phone,
                valueDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.menu_book_rounded,
                label: 'اسم المادة',
                value: subject,
                accentValue: true,
                accentColor: roleBadgeColor,
              ),
            ] else ...<Widget>[
              _buildDetailRow(
                icon: Icons.email_outlined,
                label: 'البريد الإلكتروني',
                value: email,
                valueDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.phone_android_rounded,
                label: 'رقم الهاتف',
                value: phone,
                valueDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              // University ID – prominent
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: roleBadgeColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: roleBadgeColor.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.credit_card_rounded,
                          color: roleBadgeColor, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'الرقم الجامعي',
                          style: TextStyle(
                            color: NexoraTheme.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uniId,
                          style: TextStyle(
                            color: roleBadgeColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Action Buttons ──
            Row(
              children: <Widget>[
                // Reject Button
                Expanded(
                  flex: 2,
                  child: Material(
                    color: NexoraTheme.errorColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onReject,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: NexoraTheme.errorColor.withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'رفض',
                            style: TextStyle(
                              color: NexoraTheme.errorColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Approve Button
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF00B8E0),
                          Color(0xFF00D2FF),
                          Color(0xFF00E5FF),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onApprove,
                          splashColor: Colors.white.withOpacity(0.15),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.check_rounded,
                                    color: Color(0xFF080C14), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'موافقة',
                                  style: TextStyle(
                                    color: Color(0xFF080C14),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail Row Helper ──
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    TextDirection valueDirection = TextDirection.rtl,
    bool accentValue = false,
    Color? accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: NexoraTheme.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: NexoraTheme.accentColor.withOpacity(0.7), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: NexoraTheme.secondaryTextColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                textDirection: valueDirection,
                style: TextStyle(
                  color: accentValue
                      ? (accentColor ?? NexoraTheme.accentColor)
                      : NexoraTheme.primaryTextColor,
                  fontSize: accentValue ? 15 : 14,
                  fontWeight: accentValue ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: accentValue ? 0.3 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Grid Background
// ─────────────────────────────────────────────────────────────────────────────

class _AdminGridBackground extends StatelessWidget {
  const _AdminGridBackground({required this.glowAnimation});
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
      ..color = const Color(0xFF00D2FF).withOpacity(0.03 + 0.02 * glow)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final Paint dotPaint = Paint()
      ..color = const Color(0xFF00D2FF).withOpacity(0.08 + 0.04 * glow)
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
