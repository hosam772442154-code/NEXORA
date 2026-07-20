import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexora_it/core/nexora_theme.dart';
import 'package:nexora_it/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Country Data Model
// ─────────────────────────────────────────────────────────────────────────────

class _CountryData {
  final String code;
  final String name;
  final String flag;
  final int maxDigits;

  const _CountryData({
    required this.code,
    required this.name,
    required this.flag,
    this.maxDigits = 9,
  });
}

const List<_CountryData> _kCountries = <_CountryData>[
  _CountryData(code: '+967', name: 'اليمن', flag: '🇾🇪', maxDigits: 9),
  _CountryData(code: '+966', name: 'السعودية', flag: '🇸🇦', maxDigits: 9),
  _CountryData(code: '+971', name: 'الإمارات', flag: '🇦🇪', maxDigits: 9),
  _CountryData(code: '+968', name: 'عُمان', flag: '🇴🇲', maxDigits: 9),
  _CountryData(code: '+20', name: 'مصر', flag: '🇪🇬', maxDigits: 9),
  _CountryData(code: '+962', name: 'الأردن', flag: '🇯🇴', maxDigits: 9),
  _CountryData(code: '+964', name: 'العراق', flag: '🇮🇶', maxDigits: 9),
];

// ─────────────────────────────────────────────────────────────────────────────
// Signup Screen – Dark Tech Theme (Text-driven, No Image/Storage)
// ─────────────────────────────────────────────────────────────────────────────

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  // ── Form ──
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _uniIdController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _uniIdFocus = FocusNode();
  final FocusNode _subjectFocus = FocusNode();

  // ── State ──
  String? _selectedRole;
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> _roles = const <String>['طالب', 'دكتور', 'مندوب'];

  // ── Animations ──
  late final AnimationController _glowController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ── Phone widget key for external access ──
  final GlobalKey<_PhoneInputWidgetState> _phoneKey =
      GlobalKey<_PhoneInputWidgetState>();

  // ── Lifecycle ──
  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _uniIdController.dispose();
    _subjectController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _emailFocus.dispose();
    _uniIdFocus.dispose();
    _subjectFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──
  bool get _isDoctor => _selectedRole == 'دكتور';

  // ── Firestore Submit ──
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      _showSnackBar('الرجاء اختيار نوع الحساب');
      return;
    }
    if (_selectedGender == null) {
      _showSnackBar('الرجاء اختيار الجنس');
      return;
    }

    // Validate phone length
    final String phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      _showSnackBar('الرجاء إدخال رقم الهاتف');
      return;
    }
    if (phoneText.length > 9) {
      _showSnackBar('رقم الهاتف يجب أن لا يتجاوز 9 أرقام');
      return;
    }

    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = phoneText;
    final String password = _passwordController.text.trim();
    final String role = _selectedRole!;
    final String gender = _selectedGender!;

    try {
      // 1. Create user in Firebase Auth using the email field
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final String uid = userCredential.user!.uid;

      // 2. Build user data map – all text, no images
      final Map<String, dynamic> userData = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'gender': gender,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isDoctor) {
        userData['subject'] = _subjectController.text.trim();
      } else {
        userData['uniId'] = _uniIdController.text.trim();
      }

      // 3. Save to Firestore under users/$uid
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateToWaiting();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
            content: const Text(
              'لديك حساب بالفعل من سابق! يرجى الانتقال إلى صفحة تسجيل الدخول.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        _showSnackBar('فشل التسجيل: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('فشل التسجيل: $e');
    }
  }

  void _navigateToWaiting() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation) {
          return FadeTransition(
              opacity: animation, child: const WaitingApprovalScreen());
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.info_outline_rounded,
                color: NexoraTheme.accentColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: NexoraTheme.primaryTextColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: NexoraTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: NexoraTheme.accentColor.withOpacity(0.3),
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C14),
        body: Stack(
          children: <Widget>[
            // Grid background
            _SignupGridBackground(glowAnimation: _glowAnimation),
            // Top-left glow orb
            _buildTopGlow(),
            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 20),
                        _buildTopBar(),
                        const SizedBox(height: 32),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildRoleDropdownSection(),
                        const SizedBox(height: 24),
                        _buildGenderSelector(),
                        const SizedBox(height: 28),
                        _buildFormFields(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top glow orb ──
  Widget _buildTopGlow() {
    return AnimatedBuilder(
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
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Row(
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
          'حساب جديد',
          style: TextStyle(
            color: NexoraTheme.primaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Header with glowing icon ──
  Widget _buildHeader() {
    return Column(
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
                Icons.person_add_rounded,
                color: NexoraTheme.accentColor,
                size: 28,
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            color: NexoraTheme.primaryTextColor,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'أكمل البيانات التالية لتقديم طلب التسجيل',
          style: TextStyle(
            color: NexoraTheme.secondaryTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Role Dropdown ──
  Widget _buildRoleDropdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 10, right: 4),
          child: Text(
            'نوع الحساب',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          dropdownColor: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: NexoraTheme.secondaryTextColor),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          decoration: _buildInputDecoration(
            hint: 'اختر نوع الحساب',
            prefix: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: NexoraTheme.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: NexoraTheme.accentColor.withOpacity(0.25),
                ),
              ),
              child: const Icon(Icons.group_outlined,
                  color: NexoraTheme.accentColor, size: 16),
            ),
          ),
          items: _roles.map((String role) {
            IconData roleIcon;
            switch (role) {
              case 'طالب':
                roleIcon = Icons.school_rounded;
                break;
              case 'دكتور':
                roleIcon = Icons.workspace_premium_rounded;
                break;
              case 'مندوب':
                roleIcon = Icons.support_agent_rounded;
                break;
              default:
                roleIcon = Icons.person_rounded;
            }
            return DropdownMenuItem<String>(
              value: role,
              child: Row(
                children: <Widget>[
                  Icon(roleIcon, color: NexoraTheme.accentColor, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? v) {
            setState(() {
              _selectedRole = v;
              _uniIdController.clear();
              _subjectController.clear();
            });
          },
        ),
      ],
    );
  }

  // ── Gender selector ──
  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 10, right: 4),
          child: Text(
            'الجنس',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildGenderCard(
                icon: Icons.male_rounded,
                label: 'ذكر',
                selected: _selectedGender == 'ذكر',
                onTap: () => setState(() => _selectedGender = 'ذكر'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildGenderCard(
                icon: Icons.female_rounded,
                label: 'أنثى',
                selected: _selectedGender == 'أنثى',
                onTap: () => setState(() => _selectedGender = 'أنثى'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? NexoraTheme.accentColor : NexoraTheme.dividerColor,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: NexoraTheme.accentColor.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              color: selected
                  ? NexoraTheme.accentColor
                  : NexoraTheme.secondaryTextColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? NexoraTheme.accentColor
                    : NexoraTheme.secondaryTextColor,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form Fields (dynamic based on role) ──
  Widget _buildFormFields() {
    return Form(
      key: _formKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> anim) {
          return FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          );
        },
        child: _selectedRole == null
            ? const SizedBox.shrink(key: ValueKey<String>('empty'))
            : _isDoctor
                ? _buildDoctorFields()
                : _buildStudentRepFields(),
      ),
    );
  }

  /// Doctor fields: الاسم الرباعي, Phone, اسم المادة, Email, Password
  Widget _buildDoctorFields() {
    return Column(
      key: const ValueKey<String>('doctor_fields'),
      children: <Widget>[
        _buildTextField(
          label: 'الاسم الرباعي',
          controller: _nameController,
          focusNode: _nameFocus,
          nextFocus: _phoneFocus,
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          validator: _requiredValidator('الرجاء إدخال الاسم الرباعي'),
        ),
        const SizedBox(height: 20),
        _PhoneInputWidget(
          key: _phoneKey,
          controller: _phoneController,
          focusNode: _phoneFocus,
          nextFocus: _subjectFocus,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'اسم المادة',
          controller: _subjectController,
          focusNode: _subjectFocus,
          nextFocus: _emailFocus,
          icon: Icons.menu_book_rounded,
          keyboardType: TextInputType.text,
          validator: _requiredValidator('الرجاء إدخال اسم المادة'),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'البريد الإلكتروني',
          controller: _emailController,
          focusNode: _emailFocus,
          nextFocus: _passwordFocus,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) {
              return 'الرجاء إدخال البريد الإلكتروني';
            }
            if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildPasswordTextField(
          label: 'كلمة المرور',
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscure: _obscurePassword,
          onToggle: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            if (v.trim().length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Student / Representative fields: الاسم الكامل, الرقم الجامعي, Phone, Email, Password
  Widget _buildStudentRepFields() {
    return Column(
      key: const ValueKey<String>('student_rep_fields'),
      children: <Widget>[
        _buildTextField(
          label: 'الاسم الكامل',
          controller: _nameController,
          focusNode: _nameFocus,
          nextFocus: _uniIdFocus,
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          validator: _requiredValidator('الرجاء إدخال الاسم الكامل'),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'الرقم الجامعي',
          controller: _uniIdController,
          focusNode: _uniIdFocus,
          nextFocus: _phoneFocus,
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          validator: _requiredValidator('الرجاء إدخال الرقم الجامعي'),
        ),
        const SizedBox(height: 20),
        _PhoneInputWidget(
          key: _phoneKey,
          controller: _phoneController,
          focusNode: _phoneFocus,
          nextFocus: _emailFocus,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'البريد الإلكتروني',
          controller: _emailController,
          focusNode: _emailFocus,
          nextFocus: _passwordFocus,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) {
              return 'الرجاء إدخال البريد الإلكتروني';
            }
            if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildPasswordTextField(
          label: 'كلمة المرور',
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscure: _obscurePassword,
          onToggle: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            if (v.trim().length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Reusable text field ──
  Widget _buildTextField({
    Key? key,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required IconData icon,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: _buildInputDecoration(
            hint: label,
            prefix: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NexoraTheme.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: NexoraTheme.accentColor.withOpacity(0.25),
                  ),
                ),
                child: Icon(icon, color: NexoraTheme.accentColor, size: 16),
              ),
            ),
          ),
          validator: validator,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
        ),
      ],
    );
  }

  // ── Password field ──
  Widget _buildPasswordTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
          decoration: _buildInputDecoration(
            hint: '••••••',
            prefix: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: NexoraTheme.secondaryTextColor,
                  size: 20,
                ),
              ),
            ),
          ),
          validator: validator,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
        ),
      ],
    );
  }

  // ── Submit button ──
  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF00B8E0),
                Color(0xFF00D2FF),
                Color(0xFF00E5FF),
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: NexoraTheme.accentColor
                    .withOpacity(0.35 * _glowAnimation.value),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: NexoraTheme.accentColor
                    .withOpacity(0.15 * _glowAnimation.value),
                blurRadius: 60,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _handleSubmit,
                splashColor: Colors.white.withOpacity(0.15),
                highlightColor: Colors.white.withOpacity(0.08),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              NexoraTheme.backgroundColor,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.send_rounded,
                                color: NexoraTheme.backgroundColor, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'إرسال طلب التسجيل',
                              style: TextStyle(
                                color: NexoraTheme.backgroundColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Input Decoration ──
  InputDecoration _buildInputDecoration({
    required String hint,
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: NexoraTheme.secondaryTextColor.withOpacity(0.5),
        fontSize: 14,
        letterSpacing: 1,
      ),
      prefixIcon: prefix != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: prefix,
            )
          : null,
      prefixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: const Color(0xFF1B263B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: NexoraTheme.dividerColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: NexoraTheme.dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: NexoraTheme.accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: NexoraTheme.errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: NexoraTheme.errorColor, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: NexoraTheme.errorColor,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ── Validators ──
  String? Function(String?) _requiredValidator(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Phone Input Widget with Shake Animation & Country Picker
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneInputWidget extends StatefulWidget {
  const _PhoneInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.nextFocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;

  @override
  State<_PhoneInputWidget> createState() => _PhoneInputWidgetState();
}

class _PhoneInputWidgetState extends State<_PhoneInputWidget>
    with SingleTickerProviderStateMixin {
  // ── Shake Animation ──
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // ── Country State ──
  _CountryData _selectedCountry = _kCountries[0]; // Yemen default

  // ── Validation State ──
  bool _hasPhoneError = false;
  String _phoneErrorText = '';

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0, end: -12), weight: 1),
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: -12, end: 12), weight: 2),
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: 12, end: -8), weight: 2),
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: -8, end: 8), weight: 2),
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: 8, end: -4), weight: 1),
      TweenSequenceItem<double>(
          tween: Tween<double>(begin: -4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPhoneChanged);
    _shakeController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final String text = widget.controller.text;
    if (text.length > 9) {
      if (!_hasPhoneError) {
        setState(() {
          _hasPhoneError = true;
          _phoneErrorText = 'رقم الهاتف يجب أن لا يتجاوز 9 أرقام';
        });
        _shakeController.forward(from: 0.0);
      }
    } else {
      if (_hasPhoneError) {
        setState(() {
          _hasPhoneError = false;
          _phoneErrorText = '';
        });
      }
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1B263B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NexoraTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'اختر الدولة',
                  style: TextStyle(
                    color: NexoraTheme.primaryTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ..._kCountries.map((_CountryData country) {
                  final bool isSelected =
                      country.code == _selectedCountry.code;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCountry = country);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? NexoraTheme.accentColor.withOpacity(0.1)
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(
                                  color: NexoraTheme.accentColor
                                      .withOpacity(0.3))
                              : null,
                        ),
                        child: Row(
                          children: <Widget>[
                            Text(country.flag,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                country.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? NexoraTheme.accentColor
                                      : NexoraTheme.primaryTextColor,
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              country.code,
                              style: TextStyle(
                                color: isSelected
                                    ? NexoraTheme.accentColor
                                    : NexoraTheme.secondaryTextColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                            if (isSelected) ...<Widget>[
                              const SizedBox(width: 10),
                              const Icon(Icons.check_circle_rounded,
                                  color: NexoraTheme.accentColor, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Label
        const Padding(
          padding: EdgeInsets.only(bottom: 10, right: 4),
          child: Text(
            'رقم الهاتف',
            style: TextStyle(
              color: NexoraTheme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        // Shake-wrapped row
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (BuildContext context, Widget? child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Country Code Square ──
              GestureDetector(
                onTap: _showCountryPicker,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 68,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasPhoneError
                              ? NexoraTheme.errorColor
                              : NexoraTheme.dividerColor,
                          width: _hasPhoneError ? 1.5 : 1,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> anim) {
                          return FadeTransition(
                              opacity: anim, child: child);
                        },
                        child: Text(
                          _selectedCountry.code,
                          key: ValueKey<String>(
                              'code_${_selectedCountry.code}'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Flag & Country Name beneath ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder:
                          (Widget child, Animation<double> anim) {
                        return FadeTransition(
                            opacity: anim, child: child);
                      },
                      child: SizedBox(
                        key: ValueKey<String>(
                            'flag_${_selectedCountry.code}'),
                        width: 68,
                        child: Column(
                          children: <Widget>[
                            Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedCountry.name,
                              style: TextStyle(
                                color: NexoraTheme.secondaryTextColor
                                    .withOpacity(0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Phone Number Field ──
              Expanded(
                child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasPhoneError
                          ? NexoraTheme.errorColor
                          : NexoraTheme.dividerColor,
                      width: _hasPhoneError ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '--- --- ---',
                        hintStyle: TextStyle(
                          color: NexoraTheme.secondaryTextColor
                              .withOpacity(0.35),
                          fontSize: 18,
                          letterSpacing: 3,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) {
                        if (widget.nextFocus != null) {
                          FocusScope.of(context)
                              .requestFocus(widget.nextFocus);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Error Message (animated from bottom) ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: _hasPhoneError ? 28 : 0,
          child: AnimatedOpacity(
            opacity: _hasPhoneError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 4),
                child: Text(
                  _phoneErrorText,
                  style: const TextStyle(
                    color: NexoraTheme.errorColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circuit-grid background (matching login screen)
// ─────────────────────────────────────────────────────────────────────────────

class _SignupGridBackground extends StatelessWidget {
  const _SignupGridBackground({required this.glowAnimation});

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
      ..color =
          const Color(0xFF00D2FF).withOpacity(0.03 + 0.02 * glow)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final Paint dotPaint = Paint()
      ..color =
          const Color(0xFF00D2FF).withOpacity(0.08 + 0.04 * glow)
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

// ─────────────────────────────────────────────────────────────────────────────
// Waiting Approval Screen – Beautiful Dark Theme
// ─────────────────────────────────────────────────────────────────────────────

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C14),
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: _SignupGridBackground(
                glowAnimation: AlwaysStoppedAnimation<double>(1.0),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color:
                                  NexoraTheme.successColor.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                color: NexoraTheme.accentColor,
                                strokeWidth: 3,
                              ),
                            ),
                            Icon(
                              Icons.check_rounded,
                              color: NexoraTheme.successColor,
                              size: 50,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'تم إرسال طلب التسجيل بنجاح!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NexoraTheme.primaryTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تم إرسال طلبك بنجاح، يرجى انتظار موافقة الإدارة لتفعيل حسابك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NexoraTheme.secondaryTextColor,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                PageRouteBuilder<void>(
                                  pageBuilder: (BuildContext context,
                                      Animation<double> animation,
                                      Animation<double>
                                          secondaryAnimation) {
                                    return FadeTransition(
                                        opacity: animation,
                                        child: const LoginScreen());
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 500),
                                ),
                                (_) => false,
                              );
                            }
                          },
                          icon:
                              const Icon(Icons.logout_rounded, size: 20),
                          label: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexoraTheme.errorColor,
                            side: BorderSide(
                              color:
                                  NexoraTheme.errorColor.withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
