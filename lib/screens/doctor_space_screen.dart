import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorSpaceScreen extends StatefulWidget {
  const DoctorSpaceScreen({super.key});

  @override
  State<DoctorSpaceScreen> createState() => _DoctorSpaceScreenState();
}

class _DoctorSpaceScreenState extends State<DoctorSpaceScreen> {
  String? _subjectName;
  String? _courseId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _provisionCourse();
  }

  Future<void> _provisionCourse() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        _subjectName = data['subject'] ?? 'المادة غير محددة';
      }

      // Find or create course
      final courseQuery = await FirebaseFirestore.instance
          .collection('courses')
          .where('doctorId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (courseQuery.docs.isNotEmpty) {
        _courseId = courseQuery.docs.first.id;
      } else {
        // Provision
        final newCourse = await FirebaseFirestore.instance.collection('courses').add({
          'doctorId': user.uid,
          'subjectName': _subjectName,
          'doctorName': userDoc.data()?['name'] ?? 'دكتور',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _courseId = newCourse.id;
      }
    } catch (e) {
      debugPrint('Error provisioning course: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addContent(String collectionName, String titleLabel) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('إضافة $titleLabel', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'العنوان', hintStyle: TextStyle(fontFamily: 'Cairo')),
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'الوصف / التعليمات', hintStyle: TextStyle(fontFamily: 'Cairo')),
                    style: const TextStyle(fontFamily: 'Cairo'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(labelText: 'رابط خارجي (Drive/Mega)', hintStyle: TextStyle(fontFamily: 'Cairo')),
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isNotEmpty && _courseId != null) {
                    await FirebaseFirestore.instance
                        .collection('courses')
                        .doc(_courseId)
                        .collection(collectionName)
                        .add({
                      'title': titleCtrl.text,
                      'description': descCtrl.text,
                      'link': linkCtrl.text,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('نشر', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContent(String collectionName, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor)),
          content: const Text('هل أنت متأكد من حذف هذا العنصر نهائياً؟', style: TextStyle(fontFamily: 'Cairo')),
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

    if (confirm == true && _courseId != null) {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_courseId)
          .collection(collectionName)
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<void> _showApologyModal() async {
    final specificLecturesSnap = await FirebaseFirestore.instance
        .collection('semester_schedule')
        .where('subjectName', isEqualTo: _subjectName)
        .where('status', isNotEqualTo: 'canceled')
        .get();

    final lectures = specificLecturesSnap.docs;

    if (lectures.isEmpty) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد محاضرات مجدولة (أو غير ملغية) لهذه المادة.')));
       return;
    }

    String? selectedLectureId = lectures.first.id;
    final reasonCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool hasMakeup = false;
    DateTime? makeupDate;
    TimeOfDay? makeupTime;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
         return StatefulBuilder(
           builder: (ctx, setModalState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('الاعتذار عن محاضرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppTheme.errorColor)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedLectureId,
                          items: lectures.map((doc) {
                            final data = doc.data();
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text('${data['dayOfWeek']} - ${data['startTime']}'),
                            );
                          }).toList(),
                          onChanged: (v) => setModalState(() => selectedLectureId = v),
                          decoration: const InputDecoration(labelText: 'اختر المحاضرة'),
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'سبب الاعتذار (اختياري)')),
                        const SizedBox(height: 10),
                        TextField(controller: messageCtrl, decoration: const InputDecoration(labelText: 'رسالة للطلاب (اختياري)'), maxLines: 2),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('تحديد موعد تعويضي', style: TextStyle(fontFamily: 'Cairo')),
                          value: hasMakeup,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (v) => setModalState(() => hasMakeup = v),
                        ),
                        if (hasMakeup) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(makeupDate == null ? 'اختر التاريخ' : '${makeupDate!.year}-${makeupDate!.month}-${makeupDate!.day}'),
                                  onPressed: () async {
                                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                                    if (d != null) setModalState(() => makeupDate = d);
                                  },
                                )
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.access_time),
                                  label: Text(makeupTime == null ? 'اختر الوقت' : makeupTime!.format(context)),
                                  onPressed: () async {
                                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                    if (t != null) setModalState(() => makeupTime = t);
                                  },
                                )
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                             if (selectedLectureId == null) return;
                             if (hasMakeup && (makeupDate == null || makeupTime == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد التاريخ والوقت التعويضي.')));
                                return;
                             }
                             Navigator.pop(ctx);
                             await _processApology(
                                lectureId: selectedLectureId!,
                                reason: reasonCtrl.text.trim(),
                                message: messageCtrl.text.trim(),
                                hasMakeup: hasMakeup,
                                makeupDate: makeupDate,
                                makeupTime: makeupTime,
                             );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                          child: const Text('تأكيد الاعتذار', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    )
                  )
                )
              );
           }
         );
      }
    );
  }

  Future<void> _processApology({
    required String lectureId,
    required String reason,
    required String message,
    required bool hasMakeup,
    DateTime? makeupDate,
    TimeOfDay? makeupTime,
  }) async {
     showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

     try {
        final docRef = FirebaseFirestore.instance.collection('semester_schedule').doc(lectureId);
        final docSnap = await docRef.get();
        if (!docSnap.exists) throw Exception('Lecture not found');
        
        final data = docSnap.data()!;
        final day = data['dayOfWeek'];
        final subj = data['subjectName'];

        String makeupStr = '';
        if (hasMakeup && makeupDate != null && makeupTime != null) {
           makeupStr = '${makeupDate.year}-${makeupDate.month}-${makeupDate.day} الساعة ${makeupTime.format(context)}';
        }

        await FirebaseFirestore.instance.runTransaction((transaction) async {
           transaction.update(docRef, {
              'status': 'canceled',
              'apologyReason': reason,
              'customMessage': message,
              'makeupInfo': makeupStr.isNotEmpty ? makeupStr : null,
           });

           final annRef = FirebaseFirestore.instance.collection('announcements').doc();
           String annBody = 'تم إلغاء محاضرة $subj ليوم $day.';
           if (reason.isNotEmpty) annBody += '\nالسبب: $reason';
           if (message.isNotEmpty) annBody += '\nرسالة الدكتور: $message';
           if (makeupStr.isNotEmpty) annBody += '\nالموعد التعويضي: $makeupStr';

           transaction.set(annRef, {
              'title': 'إلغاء محاضرة: $subj',
              'content': annBody,
              'authorName': 'نظام الجدولة',
              'authorRole': 'إشعار تلقائي',
              'timestamp': FieldValue.serverTimestamp(),
              'category': 'هام',
           });
        });

        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=PLACEHOLDER_SERVER_KEY',
          },
          body: jsonEncode({
            'to': '/topics/announcements',
            'notification': {
              'title': 'إلغاء محاضرة: $subj',
              'body': 'تم إلغاء محاضرة $subj ليوم $day. اضغط للتفاصيل.',
            },
          }),
        );

        if (mounted) {
           Navigator.pop(context); // close loading
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاعتذار وتحديث الجدول وإرسال الإشعارات.', style: TextStyle(fontFamily: 'Cairo'))));
        }

     } catch (e) {
        if (mounted) {
           Navigator.pop(context); // close loading
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

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
            title: Text(
              'مساحة الدكتور: $_subjectName',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.event_busy_rounded, color: AppTheme.errorColor),
                tooltip: 'الاعتذار عن محاضرة',
                onPressed: _showApologyModal,
              ),
            ],
            bottom: const TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'المحاضرات والمراجع'),
                Tab(text: 'التكاليف'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildContentList('lectures', 'محاضرة/مرجع'),
              _buildContentList('assignments', 'تكليف'),
            ],
          ),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton(
              onPressed: () {
                final tabIndex = DefaultTabController.of(ctx).index;
                if (tabIndex == 0) {
                  _addContent('lectures', 'محاضرة/مرجع جديد');
                } else {
                  _addContent('assignments', 'تكليف جديد');
                }
              },
              backgroundColor: AppTheme.accentColor,
              child: const Icon(Icons.add, color: AppTheme.textColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentList(String collectionName, String emptyLabel) {
    if (_courseId == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primaryColor,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(_courseId)
            .collection(collectionName)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 200),
                Center(
                  child: Text(
                    'لا يوجد $emptyLabel مضافة بعد',
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                  ),
                ),
              ],
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final id = docs[index].id;
              final title = data['title'] ?? '';
              final desc = data['description'] ?? '';
              final link = data['link'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                            onPressed: () => _deleteContent(collectionName, id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(desc, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                      if (link.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            launchUrl(Uri.parse(link));
                          },
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('رابط سحابي', style: TextStyle(fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryLight,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
