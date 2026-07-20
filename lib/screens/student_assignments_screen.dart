import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/constants/app_theme.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  String? _selectedCourseId;
  String? _selectedDoctorName;

  String _getOrdinal(int index) {
    const ordinals = [
      'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
      'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'
    ];
    if (index < ordinals.length) return ordinals[index];
    return 'الرقم \${index + 1}';
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
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
          title: const Text('متتبع التكاليف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.primaryColor,
          child: Column(
            children: [
              _buildCourseSelector(),
              if (_selectedDoctorName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Text('أستاذ المادة: $_selectedDoctorName', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                    ],
                  ),
                ),
              Expanded(
                child: _selectedCourseId == null
                    ? const Center(child: Text('الرجاء اختيار مادة لعرض التكاليف', style: TextStyle(fontFamily: 'Cairo')))
                    : _buildAssignmentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('courses').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);
        
        final courses = snapshot.data!.docs;
        if (courses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('لا توجد مواد مسجلة حالياً', style: TextStyle(fontFamily: 'Cairo')),
          );
        }

        // Auto-select first course if none selected
        if (_selectedCourseId == null && courses.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedCourseId = courses.first.id;
              _selectedDoctorName = (courses.first.data() as Map<String, dynamic>)['doctorName'];
            });
          });
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCourseId,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
              style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  final course = courses.firstWhere((c) => c.id == newValue);
                  setState(() {
                    _selectedCourseId = newValue;
                    _selectedDoctorName = (course.data() as Map<String, dynamic>)['doctorName'];
                  });
                }
              },
              items: courses.map<DropdownMenuItem<String>>((DocumentSnapshot document) {
                final data = document.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: document.id,
                  child: Text(data['subjectName'] ?? 'مادة غير معروفة'),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .collection('assignments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد تكاليف لهذه المادة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
        }

        final assignments = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            final assignmentData = assignment.data() as Map<String, dynamic>;
            final assignmentId = assignment.id;
            
            final structuralLabel = 'التكليف ${_getOrdinal(index)}';
            final title = assignmentData['title'] ?? '';
            final desc = assignmentData['description'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: _getSubmissionStatus(assignmentId),
              builder: (context, subSnapshot) {
                String status = 'unsubmitted';
                String? rejectionReason;

                if (subSnapshot.hasData && subSnapshot.data!.exists) {
                  final subData = subSnapshot.data!.data() as Map<String, dynamic>;
                  status = subData['status'] ?? 'pending';
                  rejectionReason = subData['rejectionReason'];
                }

                return _buildAssignmentCard(
                  structuralLabel: structuralLabel,
                  title: title,
                  description: desc,
                  status: status,
                  rejectionReason: rejectionReason,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<DocumentSnapshot> _getSubmissionStatus(String assignmentId) async {
    final user = FirebaseAuth.instance.currentUser;
    // Query submissions sub-collection to get user's status for this assignment
    final docRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(_selectedCourseId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .doc(user?.uid ?? 'unknown');
    return await docRef.get();
  }

  Widget _buildAssignmentCard({
    required String structuralLabel,
    required String title,
    required String description,
    required String status,
    String? rejectionReason,
  }) {
    // Determine Neon Badges
    Color badgeColor;
    String badgeText;
    
    switch (status) {
      case 'approved':
        badgeColor = AppTheme.successColor;
        badgeText = '✅ تم قبول التكليف';
        break;
      case 'rejected':
        badgeColor = AppTheme.errorColor;
        badgeText = '❌ يحتاج تعديل';
        break;
      case 'pending':
        badgeColor = Colors.orangeAccent;
        badgeText = '🟡 قيد المراجعة';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'لم يتم التسليم';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: badgeColor.withOpacity(0.5), width: 1.5),
      ),
      elevation: 2,
      shadowColor: badgeColor.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    structuralLabel,
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
            ),
            if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سبب الرفض / ملاحظة الدكتور:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(rejectionReason, style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor, fontSize: 13)),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
