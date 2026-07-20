import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'time_service.dart';

class AuthGuardResult {
  final bool isAllowed;
  final String? role;
  final Map<String, dynamic>? userData;
  final String? errorMessage;

  AuthGuardResult({
    required this.isAllowed,
    this.role,
    this.userData,
    this.errorMessage,
  });
}

class SecurityAuthGuard {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool canManageSystem(String? role) {
    return role == 'Admin' || role == 'مدير النظام' || role == 'مدير';
  }

  static bool canManageAcademics(String? role) {
    if (canManageSystem(role)) return true;
    return role == 'Doctor' || role == 'دكتور' || role == 'Mandoub' || role == 'مندوب';
  }

  static bool isReadOnly(String? role) {
    return role == 'Student' || role == 'طالب';
  }

  static Future<AuthGuardResult> verifyUserAccessAndRole() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return AuthGuardResult(
          isAllowed: false,
          errorMessage: 'No user is currently logged in.',
        );
      }

      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        return AuthGuardResult(
          isAllowed: false,
          errorMessage: 'User document does not exist.',
        );
      }

      final Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      final String status = userData['status'] ?? 'pending';
      final String? role = userData['role'];

      if (status == 'banned') {
        final String? banType = userData['banType'];
        final String? banReason = userData['banReason'];
        final String? banExpiry = userData['banExpiry'];

        if (banType == 'temporary' && banExpiry != null) {
          if (TimeService.hasBanExpired(banExpiry)) {
            // Ban expired, unban the user automatically
            await _firestore.collection('users').doc(currentUser.uid).update({
              'status': 'approved',
              'banType': FieldValue.delete(),
              'banReason': FieldValue.delete(),
              'banExpiry': FieldValue.delete(),
            });

            userData['status'] = 'approved';
            userData.remove('banType');
            userData.remove('banReason');
            userData.remove('banExpiry');
            
            return AuthGuardResult(
              isAllowed: true,
              role: role,
              userData: userData,
            );
          } else {
            // Ban is still active, format the expiry
            String formattedExpiry = banExpiry;
            try {
               final dt = DateTime.parse(banExpiry);
               formattedExpiry = DateFormat('yyyy-MM-dd hh:mm a').format(dt);
            } catch (_) {}

            return AuthGuardResult(
              isAllowed: false,
              errorMessage: 'You are temporarily banned.\nReason: ${banReason ?? 'No reason provided'}\nExpires: $formattedExpiry',
            );
          }
        } else {
          // Permanent ban or missing expiry
          return AuthGuardResult(
            isAllowed: false,
            errorMessage: 'You are permanently banned.\nReason: ${banReason ?? 'No reason provided'}',
          );
        }
      }

      if (status != 'approved') {
        return AuthGuardResult(
          isAllowed: false,
          errorMessage: 'Account status is $status. Access blocked.',
        );
      }

      return AuthGuardResult(
        isAllowed: true,
        role: role,
        userData: userData,
      );
    } catch (e) {
      return AuthGuardResult(
        isAllowed: false,
        errorMessage: 'An error occurred during verification: $e',
      );
    }
  }
}
