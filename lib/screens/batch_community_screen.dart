import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';

String formatChatTime(String rawTime) {
  try {
    final parts = rawTime.split(':');
    if (parts.length >= 2) {
      int hour = int.parse(parts[0].trim());
      int minute = int.parse(parts[1].trim());
      final period = hour >= 12 ? 'مساءً' : 'صباحًا';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$hourStr:$minuteStr $period';
    }
  } catch (_) {
    return rawTime;
  }
  return rawTime;
}

class BatchCommunityScreen extends StatefulWidget {
  const BatchCommunityScreen({super.key});

  @override
  State<BatchCommunityScreen> createState() => _BatchCommunityScreenState();
}

class _BatchCommunityScreenState extends State<BatchCommunityScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _userRole = 'طالب';
  String _userName = 'مستخدم';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          if (mounted) {
            setState(() {
              _userRole = userDoc.data()?['role'] ?? 'طالب';
              _userName = userDoc.data()?['name'] ?? 'مستخدم';
              _isLoading = false;
            });
          }
        } else {
          if (user.email == 'admin@nexora.app' || user.email == '772442154@nexora.app') {
            if (mounted) {
              setState(() {
                _userRole = 'مدير';
                _userName = 'المدير';
                _isLoading = false;
              });
            }
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _msgController.clear();

    await FirebaseFirestore.instance.collection('community_chat').add({
      'text': text,
      'senderId': user.uid,
      'senderName': _userName,
      'senderRole': _userRole,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteMessage(String docId, String senderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Permissions check
    bool canDelete = false;
    if (_userRole == 'طالب') {
      if (senderId == user.uid) canDelete = true;
    } else {
      canDelete = true; // Rep, Doc, Admin can delete anything
    }

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية لحذف هذه الرسالة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor)),
          content: const Text('هل أنت متأكد من حذف هذه الرسالة؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('community_chat').doc(docId).delete();
    }
  }

  void _showBanSheet(String targetUid, String targetName, String targetRole) {
    if (_userRole == 'طالب') return; // Students cannot ban
    if (targetRole == 'مدير') return; // Cannot ban admin

    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 24, left: 24, right: 24
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel_rounded, size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 12),
                const Text('أداة الحظر والتنظيم (Mojo Hammer)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.errorColor)),
                const SizedBox(height: 8),
                Text('المستخدم المستهدف: \$targetName', style: const TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'سبب الحظر (إلزامي)',
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _executeBan(targetUid, reasonCtrl.text, 'مؤقت', ctx),
                        child: const Text('حظر مؤقت', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _executeBan(targetUid, reasonCtrl.text, 'نهائي', ctx),
                        child: const Text('حظر نهائي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _executeBan(String targetUid, String reason, String type, BuildContext ctx) async {
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال سبب الحظر', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }
    
    await FirebaseFirestore.instance.collection('banned_users').doc(targetUid).set({
      'reason': reason,
      'type': type,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _userName,
    });
    
    if (ctx.mounted) Navigator.pop(ctx);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تطبيق الحظر بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return Directionality(
      textDirection: TextDirection.rtl,
      // Outer StreamBuilder checks for active bans on current user
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('banned_users').doc(user.uid).snapshots(),
        builder: (context, banSnapshot) {
          if (banSnapshot.hasData && banSnapshot.data!.exists) {
            final banData = banSnapshot.data!.data() as Map<String, dynamic>;
            final reason = banData['reason'] ?? 'مخالفة الشروط والأحكام';
            final type = banData['type'] ?? 'نهائي';

            return Scaffold(
              backgroundColor: Colors.black87,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block_rounded, color: AppTheme.errorColor, size: 80),
                      const SizedBox(height: 24),
                      Text(
                        'تم حظر حسابك من المشاركة (\$type)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          'السبب: \$reason',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Render Normal Chat if not banned
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('المجتمع والتواصل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              shape: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            body: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.primaryColor,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('community_chat')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(child: Text('ابدأ المحادثة الآن!', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                            ],
                          );
                        }

                        final messages = snapshot.data!.docs;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, // Auto-scrolls to bottom
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index].data() as Map<String, dynamic>;
                            final docId = messages[index].id;
                            final senderId = msg['senderId'] ?? '';
                            final isMe = senderId == user.uid;
                            final text = msg['text'] ?? '';
                            final senderName = msg['senderName'] ?? 'مجهول';
                            final senderRole = msg['senderRole'] ?? 'طالب';
                            final Timestamp? createdAt = msg['createdAt'] as Timestamp?;
                            
                            String timeString = '';
                            if (createdAt != null) {
                              final d = createdAt.toDate();
                              timeString = "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
                            }

                            // Role tag styling
                            Color roleColor = Colors.grey;
                            if (senderRole == 'مندوب') roleColor = Colors.teal;
                            else if (senderRole == 'دكتور') roleColor = Colors.blue;
                            else if (senderRole == 'مدير') roleColor = AppTheme.errorColor;
                            else if (senderRole == 'طالب') roleColor = AppTheme.primaryColor;

                            return GestureDetector(
                              onLongPress: () => _deleteMessage(docId, senderId),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe)
                                      GestureDetector(
                                        onTap: () => _showBanSheet(senderId, senderName, senderRole),
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: roleColor.withOpacity(0.2),
                                          child: Icon(Icons.person, color: roleColor, size: 18),
                                        ),
                                      ),
                                    if (!isMe) const SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isMe ? AppTheme.primaryColor : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: isMe ? Radius.zero : const Radius.circular(16),
                                            bottomRight: isMe ? const Radius.circular(16) : Radius.zero,
                                          ),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
                                          ],
                                          border: isMe ? null : Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: roleColor, fontFamily: 'Cairo')),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: Text(senderRole, style: TextStyle(fontSize: 9, color: roleColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            if (!isMe) const SizedBox(height: 4),
                                            Text(
                                              text,
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isMe ? Colors.white : AppTheme.textColor),
                                            ),
                                            const SizedBox(height: 4),
                                            Align(
                                              alignment: Alignment.bottomLeft,
                                              child: Text(
                                                formatChatTime(timeString),
                                                style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey, fontFamily: 'Cairo'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isMe) const SizedBox(width: 8),
                                    if (isMe)
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                
                // Input Field
                Container(
                  padding: EdgeInsets.only(
                    left: 16, right: 16, top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك...',
                            hintStyle: const TextStyle(fontFamily: 'Cairo'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          style: const TextStyle(fontFamily: 'Cairo'),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
