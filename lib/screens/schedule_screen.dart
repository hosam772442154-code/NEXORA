import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:nexora_it/services/time_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _userRole = 'طالب';
  bool _isLoading = true;
  String _selectedDay = 'الأحد';

  final List<String> _academicDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  
  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _determineSmartFocusDay();
  }

  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DocumentSnapshot<Map<String, dynamic>> userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (mounted) {
          if (userDoc.exists && userDoc.data() != null) {
            setState(() {
              _userRole = userDoc.data()!['role'] ?? 'طالب';
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _determineSmartFocusDay() {
    final now = TimeService.getAdenTime();
    int weekday = now.weekday; // 1 = Monday, 7 = Sunday
    
    // Map dart weekday to Arabic day
    String todayStr;
    switch (weekday) {
      case 7: todayStr = 'الأحد'; break;
      case 1: todayStr = 'الإثنين'; break;
      case 2: todayStr = 'الثلاثاء'; break;
      case 3: todayStr = 'الأربعاء'; break;
      case 4: todayStr = 'الخميس'; break;
      case 5: todayStr = 'الجمعة'; break;
      case 6: todayStr = 'السبت'; break;
      default: todayStr = 'الأحد';
    }

    if (todayStr == 'الجمعة' || todayStr == 'السبت') {
      _selectedDay = 'الأحد'; // Smart focus to next active day
    } else {
      if (now.hour >= 17) {
        int nextIndex = _academicDays.indexOf(todayStr) + 1;
        if (nextIndex >= _academicDays.length) {
           _selectedDay = 'الأحد';
        } else {
           _selectedDay = _academicDays[nextIndex];
        }
      } else {
        _selectedDay = todayStr;
      }
    }
    setState(() {});
  }

  bool _hasPrivilege() {
    return _userRole == 'مدير' || _userRole == 'مدير النظام' || _userRole == 'دكتور' || _userRole == 'مندوب';
  }

  Future<void> _showLectureModal({String? docId, Map<String, dynamic>? initialData}) async {
     final TextEditingController subjectCtrl = TextEditingController(text: initialData?['subjectName']);
     final TextEditingController profCtrl = TextEditingController(text: initialData?['professorName']);
     final TextEditingController roomCtrl = TextEditingController(text: initialData?['roomNumber']);
     final TextEditingController notesCtrl = TextEditingController(text: initialData?['notes']);
     
     String day = initialData?['dayOfWeek'] ?? _selectedDay;
     TimeOfDay startTime = TimeOfDay.now();
     TimeOfDay endTime = TimeOfDay.now();
     
     if (initialData != null) {
       if (initialData['startTime'] != null) {
          final parts = initialData['startTime'].split(':');
          if (parts.length == 2) startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
       }
       if (initialData['endTime'] != null) {
          final parts = initialData['endTime'].split(':');
          if (parts.length == 2) endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
       }
     }

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
                       Text(docId == null ? 'إضافة محاضرة جديدة' : 'تعديل المحاضرة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                       const SizedBox(height: 16),
                       DropdownButtonFormField<String>(
                         value: day,
                         items: _academicDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                         onChanged: (v) => setModalState(() => day = v!),
                         decoration: const InputDecoration(labelText: 'اليوم'),
                       ),
                       const SizedBox(height: 10),
                       TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'اسم المادة')),
                       const SizedBox(height: 10),
                       TextField(controller: profCtrl, decoration: const InputDecoration(labelText: 'اسم الدكتور')),
                       const SizedBox(height: 10),
                       TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'القاعة / المبنى')),
                       const SizedBox(height: 10),
                       Row(
                         children: [
                           Expanded(child: TextButton.icon(
                             icon: const Icon(Icons.access_time),
                             label: Text('البداية: ${startTime.format(context)}'),
                             onPressed: () async {
                               final t = await showTimePicker(context: context, initialTime: startTime);
                               if (t != null) setModalState(() => startTime = t);
                             },
                           )),
                           Expanded(child: TextButton.icon(
                             icon: const Icon(Icons.access_time_filled),
                             label: Text('النهاية: ${endTime.format(context)}'),
                             onPressed: () async {
                               final t = await showTimePicker(context: context, initialTime: endTime);
                               if (t != null) setModalState(() => endTime = t);
                             },
                           )),
                         ],
                       ),
                       const SizedBox(height: 10),
                       TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات إضافية')),
                       const SizedBox(height: 20),
                       ElevatedButton(
                         onPressed: () async {
                           final data = {
                             'dayOfWeek': day,
                             'subjectName': subjectCtrl.text.trim(),
                             'professorName': profCtrl.text.trim(),
                             'roomNumber': roomCtrl.text.trim(),
                             'startTime': '${startTime.hour.toString().padLeft(2,'0')}:${startTime.minute.toString().padLeft(2,'0')}',
                             'endTime': '${endTime.hour.toString().padLeft(2,'0')}:${endTime.minute.toString().padLeft(2,'0')}',
                             'notes': notesCtrl.text.trim(),
                             'timestamp': FieldValue.serverTimestamp(),
                           };
                           if (docId == null) {
                             await FirebaseFirestore.instance.collection('semester_schedule').add(data);
                           } else {
                             await FirebaseFirestore.instance.collection('semester_schedule').doc(docId).update(data);
                           }
                           if (context.mounted) Navigator.pop(ctx);
                         },
                         style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                         child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
                       ),
                       const SizedBox(height: 24),
                     ],
                   ),
                 ),
               ),
             );
           }
         );
       }
     );
  }

  Future<void> _deleteLecture(String docId) async {
    await FirebaseFirestore.instance.collection('semester_schedule').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجدول الأكاديمي'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_hasPrivilege())
               IconButton(icon: const Icon(Icons.copy_all_rounded), onPressed: () {}),
          ],
        ),
        floatingActionButton: _hasPrivilege() ? FloatingActionButton.extended(
          onPressed: () => _showLectureModal(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة محاضرة', style: TextStyle(fontFamily: 'Cairo')),
        ) : null,
        body: Column(
          children: [
            _buildDaysTabs(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                   setState(() {});
                },
                child: _buildScheduleList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysTabs() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _academicDays.length,
        itemBuilder: (ctx, index) {
          final day = _academicDays[index];
          final isSelected = day == _selectedDay;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.successColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.successColor : AppTheme.dividerColor),
              ),
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('semester_schedule')
          .where('dayOfWeek', isEqualTo: _selectedDay)
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
           return ListView(
             children: const [
                SizedBox(height: 100),
                Center(child: Text('لا توجد محاضرات في هذا اليوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey))),
             ],
           );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool isCanceled = data['status'] == 'canceled';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppTheme.cardDecoration.copyWith(
                 border: isCanceled ? Border.all(color: AppTheme.errorColor, width: 1.5) : null,
                 color: isCanceled ? AppTheme.errorColor.withValues(alpha: 0.05) : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Expanded(child: Text(data['subjectName'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', decoration: isCanceled ? TextDecoration.lineThrough : null, color: isCanceled ? Colors.grey : null))),
                    if (isCanceled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(8)),
                        child: const Text('تم الإلغاء', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('الدكتور: ${data['professorName'] ?? ''}', style: TextStyle(fontFamily: 'Cairo', decoration: isCanceled ? TextDecoration.lineThrough : null)),
                    Text('الوقت: ${data['startTime']} - ${data['endTime']}', style: TextStyle(fontFamily: 'Cairo', decoration: isCanceled ? TextDecoration.lineThrough : null)),
                    Text('القاعة: ${data['roomNumber'] ?? ''}', style: TextStyle(fontFamily: 'Cairo', decoration: isCanceled ? TextDecoration.lineThrough : null)),
                    if (isCanceled) ...[
                       const SizedBox(height: 12),
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: AppTheme.errorColor.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             if (data['apologyReason'] != null && data['apologyReason'].toString().isNotEmpty)
                                Text('السبب: ${data['apologyReason']}', style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.bold)),
                             if (data['customMessage'] != null && data['customMessage'].toString().isNotEmpty)
                                Text('رسالة الدكتور: ${data['customMessage']}', style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor, fontSize: 12)),
                             if (data['makeupInfo'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('الموعد التعويضي: ${data['makeupInfo']}', style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                           ],
                         ),
                       )
                    ]
                  ],
                ),
                trailing: _hasPrivilege() ? PopupMenuButton(
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('تعديل', style: TextStyle(fontFamily: 'Cairo'))),
                    const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(fontFamily: 'Cairo'))),
                  ],
                  onSelected: (val) {
                    if (val == 'edit') {
                       _showLectureModal(docId: doc.id, initialData: data);
                    } else if (val == 'delete') {
                       _deleteLecture(doc.id);
                    }
                  },
                ) : null,
              ),
            );
          },
        );
      },
    );
  }
}
