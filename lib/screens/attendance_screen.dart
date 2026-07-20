import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexora_it/constants/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Map<String, String> _attendanceMap = {};
  bool _isLoading = true;
  List<DocumentSnapshot> _students = [];

  String get _todayStr {
    final now = DateTime.now();
    return '\${now.year}-\${now.month.toString().padLeft(2, '0')}-\${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchStudentsAndAttendance();
  }

  Future<void> _fetchStudentsAndAttendance() async {
    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'طالب')
          .get();

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: _todayStr)
          .get();

      final Map<String, String> existingMap = {};
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final sId = data['studentId'];
        final status = data['status'];
        if (sId != null && status != null) {
          existingMap[sId] = status;
        }
      }

      if (mounted) {
        setState(() {
          _students = studentsQuery.docs;
          for (var doc in _students) {
            _attendanceMap[doc.id] = existingMap[doc.id] ?? 'حضور'; // default to present if unchecked
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: \$e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAllPresent() {
    setState(() {
      for (var doc in _students) {
        _attendanceMap[doc.id] = 'حضور';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديد الجميع حضور', style: TextStyle(fontFamily: 'Cairo'))),
    );
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (var entry in _attendanceMap.entries) {
        final studentId = entry.key;
        final status = entry.value;
        final docId = '\${studentId}_\$_todayStr';
        
        final docRef = FirebaseFirestore.instance.collection('attendance').doc(docId);
        batch.set(docRef, {
          'studentId': studentId,
          'status': status,
          'date': _todayStr,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التحضير بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
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
          title: const Text('نظام التحضير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, color: AppTheme.primaryColor),
              label: const Text('تحديد الجميع حضور', style: TextStyle(color: AppTheme.primaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: _markAllPresent,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    width: double.infinity,
                    color: AppTheme.primaryLight.withOpacity(0.5),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text('تاريخ اليوم: \$_todayStr', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _students.isEmpty
                        ? const Center(child: Text('لا يوجد طلاب مسجلين', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _students.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (ctx, i) {
                              final data = _students[i].data() as Map<String, dynamic>;
                              final sId = _students[i].id;
                              final name = data['name'] ?? 'طالب مجهول';
                              final univId = data['universityId'] ?? '';

                              final currentStatus = _attendanceMap[sId] ?? 'حضور';

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppTheme.primaryLight,
                                            child: Icon(Icons.person, size: 20, color: AppTheme.primaryColor),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                                                if (univId.isNotEmpty)
                                                  Text(univId, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildSegment(sId, 'حضور', currentStatus, AppTheme.successColor, '✅ حضور'),
                                          _buildSegment(sId, 'تأخر', currentStatus, Colors.orange, '🟡 تأخر'),
                                          _buildSegment(sId, 'غياب', currentStatus, AppTheme.errorColor, '❌ غياب'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: _isLoading ? null : FloatingActionButton.extended(
          onPressed: _saveAttendance,
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text('حفظ التحضير', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSegment(String sId, String value, String currentValue, Color color, String label) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceMap[sId] = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
