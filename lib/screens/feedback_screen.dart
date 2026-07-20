import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _lessonController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  
  final TextEditingController _complaintTitleController = TextEditingController();
  final TextEditingController _complaintBodyController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _submitFeedback(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String title = '';
    String body = '';

    if (type == 'lesson_help') {
      title = _lessonController.text.trim();
      body = _detailsController.text.trim();
    } else {
      title = _complaintTitleController.text.trim();
      body = _complaintBodyController.text.trim();
    }

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تعبئة جميع الحقول', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الإرسال', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من إرسال هذا النموذج؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'مجهول';

      await FirebaseFirestore.instance.collection('feedback').add({
        'type': type,
        'title': title,
        'body': body,
        'senderId': user.uid,
        'senderName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'new', // For admins to track
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الإرسال بنجاح، شكراً لتواصلك!', style: TextStyle(fontFamily: 'Cairo'))),
        );
        if (type == 'lesson_help') {
          _lessonController.clear();
          _detailsController.clear();
        } else {
          _complaintTitleController.clear();
          _complaintBodyController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الإرسال', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
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
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('قنوات التواصل والدعم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            bottom: const TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'لم أفهم هذا الدرس'),
                Tab(text: 'الشكاوى والمقترحات'),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.primaryColor,
            child: TabBarView(
              children: [
                _buildLessonHelpTab(),
                _buildComplaintTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonHelpTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('استفسار عن درس', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
          const SizedBox(height: 8),
          const Text('سيتم توجيه هذا الاستفسار مباشرة إلى دكتور المادة ليتم مراجعته.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: _lessonController,
            decoration: InputDecoration(
              labelText: 'عنوان الدرس / المادة',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.menu_book),
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'ما هي النقطة التي لم تفهمها بالتحديد؟',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitFeedback('lesson_help'),
              icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white),
              label: const Text('إرسال الاستفسار', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقديم شكوى أو مقترح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.accentColor)),
          const SizedBox(height: 8),
          const Text('سيتم رفع هذا الطلب إلى المندوب وإدارة القسم لاتخاذ الإجراء المناسب بسرية تامة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: _complaintTitleController,
            decoration: InputDecoration(
              labelText: 'عنوان الشكوى / المقترح',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.title),
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _complaintBodyController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'التفاصيل',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitFeedback('complaint'),
              icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.security_rounded, color: Colors.white),
              label: const Text('رفع الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
