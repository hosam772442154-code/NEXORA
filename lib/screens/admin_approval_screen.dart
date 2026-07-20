import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  Future<void> _approveUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'approved',
        'isApproved': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة وتفعيل الحساب بنجاح ✓', textDirection: TextDirection.rtl),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الموافقة: $e', textDirection: TextDirection.rtl)),
        );
      }
    }
  }

  Future<void> _rejectAndDeleteUser(String uid) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الرفض والتنظيف', style: TextStyle(fontFamily: 'Cairo')),
            content: const Text('هل أنت متأكد من رفض هذا الطلب وحذف حساب المستخدم نهائياً لمنع التراكم؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Radical clean: delete document directly
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب وحذف الحساب من قاعدة البيانات بنجاح', textDirection: TextDirection.rtl),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحذف والتنظيف: $e', textDirection: TextDirection.rtl)),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(String uid, String userName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد حذف الحساب', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor)),
            content: Text('هل أنت متأكد من حذف حساب "$userName" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.', style: const TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                child: const Text('حذف الحساب', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الحساب بنجاح', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحذف: $e', textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text(
              'لوحة القبول وإدارة الحسابات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 0,
            bottom: const TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'طلبات الانضمام'),
                Tab(text: 'إدارة الحسابات'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildPendingRequestsTab(),
              _buildAccountManagementTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.successColor, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.successColor,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'لا توجد طلبات معلقة.. جميع الطلبات تمت مراجعتها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final pendingUsers = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingUsers.length,
          itemBuilder: (context, index) {
            final userDoc = pendingUsers[index];
            final data = userDoc.data();
            final String uid = userDoc.id;
            final String role = (data['role'] ?? 'طالب').toString();

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentColor.withOpacity(0.4), // Premium neon-bordered card
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Role Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['name'] ?? 'بدون اسم',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Role-based details
                    if (role == 'طالب') ...[
                      _buildDetailRow('الرقم الجامعي:', data['uniId'] ?? 'غير متوفر'),
                    ] else if (role == 'دكتور') ...[
                      _buildDetailRow('الاسم الرباعي:', data['name'] ?? 'غير متوفر'),
                      _buildDetailRow('رقم الهاتف:', data['phone'] ?? 'غير متوفر'),
                      _buildDetailRow('المادة / المساق الدراسي:', data['subject'] ?? 'غير متوفر'),
                    ] else ...[
                      _buildDetailRow('رقم الهاتف:', data['phone'] ?? 'غير متوفر'),
                      if (data['uniId'] != null)
                        _buildDetailRow('الرقم الجامعي:', data['uniId']),
                    ],

                    const SizedBox(height: 20),
                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveUser(uid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'موافقة',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectAndDeleteUser(uid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'رفض وتنظيف',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
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
          },
        );
      },
    );
  }

  Widget _buildAccountManagementTab() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد حسابات مسجلة', style: TextStyle(fontFamily: 'Cairo')));
        }

        final allUsers = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allUsers.length,
          itemBuilder: (context, index) {
            final userDoc = allUsers[index];
            final data = userDoc.data();
            final String uid = userDoc.id;
            
            final bool isCurrentUser = (uid == currentUserUid);

            final String role = (data['role'] ?? 'طالب').toString();
            final String name = (data['name'] ?? 'بدون اسم').toString();
            final String phoneOrEmail = (data['phone'] ?? data['email'] ?? 'غير متوفر').toString();
            final String status = (data['status'] ?? 'pending').toString();
            
            String statusText = 'معلق';
            Color statusColor = Colors.orange;
            if (status == 'approved') {
              statusText = 'مفعل';
              statusColor = AppTheme.successColor;
            } else if (status == 'rejected') {
              statusText = 'مرفوض';
              statusColor = AppTheme.errorColor;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
                    ),
                    if (isCurrentUser)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('(أنت)', style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('الدور: $role', style: const TextStyle(fontFamily: 'Cairo')),
                    Text('التواصل: $phoneOrEmail', style: const TextStyle(fontFamily: 'Cairo', textBaseline: TextBaseline.alphabetic)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('الحالة: ', style: TextStyle(fontFamily: 'Cairo')),
                        Text(
                          statusText,
                          style: TextStyle(fontFamily: 'Cairo', color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: isCurrentUser
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
                        onPressed: () => _confirmDeleteAccount(uid, name),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
