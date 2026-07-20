import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:nexora_it/screens/signup_screen.dart' hide WaitingApprovalScreen;
import 'package:nexora_it/screens/home_screen.dart';
import 'package:nexora_it/screens/waiting_approval_screen.dart';
import 'package:nexora_it/services/security_auth_guard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  int _selectedRoleIndex = 0;

  static const List<String> _roles = ['طالب', 'دكتور', 'مندوب', 'مدير النظام'];
  static const List<IconData> _roleIcons = [
    Icons.school_rounded,
    Icons.co_present_rounded,
    Icons.support_agent_rounded,
    Icons.admin_panel_settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedInput = prefs.getString('saved_input') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe) {
      setState(() {
        _phoneController.text = savedInput;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String input = _phoneController.text.trim();
      final String password = _passwordController.text;

      // 1. Silent Firestore Query to find user by phone, universityId, or email
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(Filter.or(
            Filter('phone', isEqualTo: input),
            Filter('universityId', isEqualTo: input),
            Filter('email', isEqualTo: input),
          ))
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        _showSnackBar('لا يوجد حساب مسجل بهذا الرقم/المعرف');
        return;
      }

      final Map<String, dynamic> userData = querySnapshot.docs.first.data();
      final String encryptedEmail = userData['email'] ?? '';

      if (encryptedEmail.isEmpty) {
        setState(() => _isLoading = false);
        _showSnackBar('بيانات الحساب غير مكتملة');
        return;
      }

      // 2. SignIn with Email and Password
      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: encryptedEmail,
        password: password,
      );

      if (!mounted) return;

      // 3. Security Auth Guard & Ban Checks
      final guardResult = await SecurityAuthGuard.verifyUserAccessAndRole();
      
      if (!guardResult.isAllowed) {
        setState(() => _isLoading = false);
        final errorMsg = guardResult.errorMessage ?? 'تم رفض الوصول';
        if (errorMsg.contains('banned')) {
          _showBanCard(errorMsg);
        } else {
          _showSnackBar(errorMsg);
        }
        return;
      }

      // 4. Role Validation, Routing & Admin Bypass
      final String role = (guardResult.userData?['role'] ?? '').toString().trim();
      final String status = (guardResult.userData?['status'] ?? 'pending').toString().trim();
      final String selectedRole = _roles[_selectedRoleIndex];

      if (!SecurityAuthGuard.canManageSystem(role) && role != selectedRole) {
        setState(() => _isLoading = false);
        _showSnackBar('هذا الحساب مسجل بدور آخر، يرجى اختيار التبويب الصحيح');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_input', input);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_input');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      if (role == 'مدير النظام' || role == 'مدير') {
        // Bypass checks, clear stack and push to HomeScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        if (status == 'pending') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-credential':
          message = 'البيانات غير صحيحة، تحقق من المدخلات';
          break;
        default:
          message = 'حدث خطأ: ${e.message}';
      }
      _showSnackBar(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ غير متوقع: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showBanCard(String errorMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel_rounded, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('تم تقييد حسابك', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                const SizedBox(height: 16),
                Text(
                  errorMessage.replaceAll('You are temporarily banned.\\n', '').replaceAll('You are permanently banned.\\n', ''),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, height: 1.5, color: AppTheme.textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor, // Off-White background
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 40),
                _buildLogoSection(),
                const SizedBox(height: 36),
                _buildRoleSwitcher(),
                const SizedBox(height: 32),
                _buildForm(),
                const SizedBox(height: 28),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Image.asset(
          'assets/images/nexora_logo.png',
          height: 110,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.business_rounded,
            size: 110,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'مرحباً بعودتك',
          style: TextStyle(
            color: AppTheme.primaryColor, // Deep Royal Blue primary
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'قم بتسجيل الدخول',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSwitcher() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(_roles.length, (int index) {
          final bool isActive = _selectedRoleIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoleIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
                border: Border.all(
                  color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _roleIcons[index],
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _roles[index],
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          _buildPhoneField(),
          const SizedBox(height: 20),
          _buildPasswordField(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.text,
      textAlign: TextAlign.start,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: 'اكتب ايميلك او رقم هاتفك او رقم البطاقة الجامعيه',
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: const TextStyle(letterSpacing: 4),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  activeColor: AppTheme.primaryColor, // Deep Royal Blue
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Text(
                  'تذكرني',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: const Text(
                'إنشاء حساب',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSupportCircle(icon: Icons.phone_rounded, label: 'اتصل بنا'),
            const SizedBox(width: 24),
            _buildSupportCircle(icon: Icons.language_rounded, label: 'موقعنا'),
            const SizedBox(width: 24),
            _buildSupportCircle(icon: Icons.chat_rounded, label: 'واتساب'),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSupportCircle({required IconData icon, required String label}) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24), // Neon Cyan accents could also be used here if AppTheme provided it, assuming AppTheme.primaryColor is used for icons
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
