import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const String kDefaultRemoteFeedUrl = '';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppStateManager appState = AppStateManager(prefs);
  await appState.initialize();
  runApp(HaneenKidsApp(appState: appState));
}


class VideoModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String ageGroup;
  final String repeatPhrase;
  final String activeActivity;
  final String streamUrl;
  final Color bgGradientStart;
  final Color bgGradientEnd;
  final String emoji;
  int likes;
  bool isLiked;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.ageGroup,
    required this.repeatPhrase,
    required this.activeActivity,
    required this.streamUrl,
    this.bgGradientStart = const Color(0xFF1E1B4B),
    this.bgGradientEnd = const Color(0xFF0F172A),
    this.emoji = '🌟',
    this.likes = 120,
    this.isLiked = false,
  });

  static Color _parseHexColor(String? hex, Color fallback) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    String cleaned = hex.trim().replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    final int? val = int.tryParse(cleaned, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static String getCategoryDisplayLabel(String categoryKey) {
    switch (categoryKey) {
      case 'bedtime':
        return '🌙 قصص النوم';
      case 'habits':
        return '🧸 سلوكياتي';
      case 'arabic':
        return '🗣️ فصاحة ونطق';
      case 'science':
        return '🦋 لماذا وكيف؟';
      case 'crafts':
        return '🎨 افعلها بيدك';
      default:
        return categoryKey.isNotEmpty ? categoryKey : '✨ قصة تفاعلية';
    }
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final String rawCategory =
        (json['category'] ?? json['playlistId'] ?? 'bedtime').toString();
    return VideoModel(
      id: (json['id'] ?? 'v_${DateTime.now().millisecondsSinceEpoch}').toString(),
      title: (json['title'] ?? 'قصة جديدة').toString(),
      description: (json['description'] ?? json['subtitle'] ?? '').toString(),
      category: rawCategory,
      ageGroup: (json['ageGroup'] ?? json['ageRange'] ?? '3–6 سنوات').toString(),
      repeatPhrase: (json['repeatPhrase'] ??
              json['interactivePhrase'] ??
              '«أَنَا طِفْلٌ ذَكِيٌّ وَهَادِئٌ»')
          .toString(),
      activeActivity: (json['activeActivity'] ??
              json['offlineActivity'] ??
              'شارك ما تعلمته اليوم مع ماما أو بابا!')
          .toString(),
      streamUrl: (json['streamUrl'] ?? json['hlsStreamUrl'] ?? '').toString(),
      bgGradientStart: _parseHexColor(
          json['bgGradientStart']?.toString(), const Color(0xFF1E1B4B)),
      bgGradientEnd: _parseHexColor(
          json['bgGradientEnd']?.toString(), const Color(0xFF0F172A)),
      emoji: (json['emoji'] ?? '🌟').toString(),
      likes: int.tryParse(json['likes']?.toString() ?? '120') ?? 120,
      isLiked: json['isLiked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'ageGroup': ageGroup,
      'repeatPhrase': repeatPhrase,
      'activeActivity': activeActivity,
      'streamUrl': streamUrl,
      'playlistId': category,
      'categoryLabel': getCategoryDisplayLabel(category),
      'ageRange': ageGroup,
      'subtitle': description,
      'interactivePhrase': repeatPhrase,
      'offlineActivity': activeActivity,
      'bgGradientStart': _colorToHex(bgGradientStart),
      'bgGradientEnd': _colorToHex(bgGradientEnd),
      'emoji': emoji,
      'likes': likes,
      'isLiked': isLiked,
    };
  }
}

class ChildProfile {
  final String id;
  String name;
  String age;
  int dailyTimeLimit;
  int starsEarned;
  String chosenAvatar;
  int usedMinutesToday;
  int watchedVideosToday;
  List<String> completedActivities;
  List<String> likedVideoIds;

  ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.dailyTimeLimit,
    this.starsEarned = 0,
    required this.chosenAvatar,
    this.usedMinutesToday = 0,
    this.watchedVideosToday = 0,
    List<String>? completedActivities,
    List<String>? likedVideoIds,
  })  : completedActivities = completedActivities ?? [],
        likedVideoIds = likedVideoIds ?? [];

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: (json['id'] ?? 'child_${DateTime.now().millisecondsSinceEpoch}').toString(),
      name: (json['name'] ?? 'فارس').toString(),
      age: (json['age'] ?? json['ageGroup'] ?? '3–6 سنوات').toString(),
      dailyTimeLimit: int.tryParse(
              (json['dailyTimeLimit'] ?? json['dailyQuota'] ?? '20').toString()) ??
          20,
      starsEarned: int.tryParse(json['starsEarned']?.toString() ?? '0') ?? 0,
      chosenAvatar:
          (json['chosenAvatar'] ?? json['avatarEmoji'] ?? '🦁').toString(),
      usedMinutesToday:
          int.tryParse(json['usedMinutesToday']?.toString() ?? '0') ?? 0,
      watchedVideosToday: int.tryParse(
              (json['watchedVideosToday'] ?? json['watchedToday'] ?? '0')
                  .toString()) ??
          0,
      completedActivities: (json['completedActivities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      likedVideoIds: (json['likedVideoIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'dailyTimeLimit': dailyTimeLimit,
      'starsEarned': starsEarned,
      'chosenAvatar': chosenAvatar,
      'usedMinutesToday': usedMinutesToday,
      'watchedVideosToday': watchedVideosToday,
      'completedActivities': completedActivities,
      'likedVideoIds': likedVideoIds,
    };
  }
}

class ParentAccount {
  String fullName;
  String emailOrPhone;
  String password;
  String parentalPin;
  bool warmEveningFilter;
  List<ChildProfile> children;
  String activeChildId;

  ParentAccount({
    required this.fullName,
    required this.emailOrPhone,
    required this.password,
    this.parentalPin = '1234',
    this.warmEveningFilter = false,
    required this.children,
    required this.activeChildId,
  });

  ChildProfile get activeChild {
    if (children.isEmpty) {
      final defaultChild = ChildProfile(
        id: 'c_default',
        name: 'فارس',
        age: '3–6 سنوات',
        dailyTimeLimit: 20,
        chosenAvatar: '🦁',
      );
      children.add(defaultChild);
      activeChildId = defaultChild.id;
    }
    return children.firstWhere(
      (c) => c.id == activeChildId,
      orElse: () => children.first,
    );
  }

  factory ParentAccount.fromJson(Map<String, dynamic> json) {
    final childrenList = (json['children'] as List<dynamic>?)
            ?.map((c) =>
                ChildProfile.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList() ??
        [
          ChildProfile(
            id: 'c1',
            name: 'فارس',
            age: '3–6 سنوات',
            dailyTimeLimit: 20,
            chosenAvatar: '🦁',
          ),
        ];
    return ParentAccount(
      fullName: (json['fullName'] ?? 'ولي الأمر').toString(),
      emailOrPhone: (json['emailOrPhone'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      parentalPin: (json['parentalPin'] ?? '1234').toString(),
      warmEveningFilter:
          json['warmEveningFilter'] == true || json['bedtimeDimming'] == true,
      children: childrenList,
      activeChildId:
          (json['activeChildId'] ?? childrenList.first.id).toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'emailOrPhone': emailOrPhone,
      'password': password,
      'parentalPin': parentalPin,
      'warmEveningFilter': warmEveningFilter,
      'children': children.map((c) => c.toJson()).toList(),
      'activeChildId': activeChildId,
    };
  }
}

const List<Map<String, String>> kVideoCategories = [
  {'id': 'all', 'title': 'كل القصص', 'icon': '✨'},
  {'id': 'bedtime', 'title': 'قصص النوم', 'icon': '🌙'},
  {'id': 'habits', 'title': 'سلوكياتي', 'icon': '🧸'},
  {'id': 'arabic', 'title': 'فصاحة ونطق', 'icon': '🗣️'},
  {'id': 'science', 'title': 'لماذا وكيف؟', 'icon': '🦋'},
  {'id': 'crafts', 'title': 'افعلها بيدك', 'icon': '🎨'},
];

List<VideoModel> getDefaultVideos() {
  return [
    VideoModel(
      id: 'v1',
      title: 'فارس ونور يراقبان الهلال المبتسم',
      description:
          '«في المساء الهادئ، جلس فارس وأخته نور قرب النافذة يتأملان الهلال المبتسم في السماء الصافية...»',
      category: 'bedtime',
      ageGroup: '3–6 سنوات',
      repeatPhrase: '«تُصْبِحُونَ عَلَى خَيْرٍ يَا أَصْدِقَائِي»',
      activeActivity:
          'انظر من النافذة مع ماما أو بابا قبل النوم، وابحث عن القمر، ثم خذ 3 أنفاس عميقة وهادئة.',
      streamUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      bgGradientStart: const Color(0xFF1E1B4B),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: '🌙',
      likes: 142,
    ),
    VideoModel(
      id: 'v2',
      title: 'سلة الألعاب السعيدة مع أرنوب',
      description:
          '«ابتسم فارس وقال لنور: هيا نلعب لعبة الترتيب الهادئ! أنا أضع السيارات في السلة، وأنتِ تضعين المكعبات.»',
      category: 'habits',
      ageGroup: '3–7 سنوات',
      repeatPhrase: '«أَنَا أُرَتِّبُ أَلْعَابِي بِنَفْسِي»',
      activeActivity:
          'اذهب الآن واجمع 3 ألعاب من غرفتك وضعها في مكانها الصحيح مثل فارس ونور لتحصل على نجمة البطل!',
      streamUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      bgGradientStart: const Color(0xFF134E4A),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: '🧸',
      likes: 198,
    ),
    VideoModel(
      id: 'v3',
      title: 'سر أجنحة الفراشة الملونة في الحديقة',
      description:
          '«في البستان الأخضر الهادئ، أمسك فارس عدسته المكبرة واقترب بهدوء شديد ليرى فراشة تقف على زهرة وردية...»',
      category: 'science',
      ageGroup: '4–8 سنوات',
      repeatPhrase: '«سُبْحَانَ اللَّهِ، مَا أَجْمَلَ الْفَرَاشَةَ!»',
      activeActivity:
          'حرك يديك ببطء شديد مثل أجنحة الفراشة الهادئة 5 مرات، واذكر لونين رأيتهما على جناح الفراشة.',
      streamUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      bgGradientStart: const Color(0xFF064E3B),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: '🦋',
      likes: 215,
    ),
    VideoModel(
      id: 'v4',
      title: 'كلمات الصباح والمساء باللغة العربية الفصحى',
      description:
          '«عندما تشرق الشمس الدافئة في الصباح، نبتسم ونقول بصوت واضح وجميل: صَبَاحُ الْخَيْرِ!»',
      category: 'arabic',
      ageGroup: '2–6 سنوات',
      repeatPhrase: '«صَبَاحُ الْخَيْرِ يَا أُمِّي، مَسَاءُ النُّورِ يَا أَبِي»',
      activeActivity:
          'اذهب الآن إلى ماما أو بابا وقل بصوت عربي واضح وجميل: «شكراً لك، أنا أحبك كثيراً!»',
      streamUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      bgGradientStart: const Color(0xFF312E81),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: '🗣️',
      likes: 176,
    ),
    VideoModel(
      id: 'v5',
      title: 'بناء برج التوازن الخشبي وتمرين التنفس',
      description:
          '«نأخذ شهيقاً عميقاً من الأنف مثل شم زهرة جميلة.. ثم نخرج الهواء ببطء، ونضع المكعب الثاني فوق الأول.»',
      category: 'crafts',
      ageGroup: '4–8 سنوات',
      repeatPhrase: '«يَدِي ثَابِتَةٌ وَعَقْلِي هَادِئٌ»',
      activeActivity:
          'أغلق الشاشة الآن، وحاول وضع 5 مكعبات أو كتب فوق بعضها بهدوء تام دون أن تسقط!',
      streamUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      bgGradientStart: const Color(0xFF78350F),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: '🎨',
      likes: 164,
    ),
  ];
}

class AppStateManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  bool isInitialized = false;
  bool onboardingCompleted = false;
  bool hasSelectedChildInSession = false;

  final Map<String, ParentAccount> _accounts = {};
  ParentAccount? currentAccount;

  List<VideoModel> videos = [];
  String remoteFeedUrl = kDefaultRemoteFeedUrl;
  String authApiUrl = '';
  bool isSyncingVideos = false;
  String? lastSyncMessage;

  Timer? _screenTimeTimer;
  int _activeSessionSeconds = 0;

  AppStateManager(this._prefs);

  Future<void> initialize() async {
    onboardingCompleted = _prefs.getBool('onboarding_completed') ?? false;
    remoteFeedUrl = _prefs.getString('remote_feed_url') ?? kDefaultRemoteFeedUrl;
    authApiUrl = _prefs.getString('auth_api_url') ?? '';

    final String? accountsJson = _prefs.getString('registered_accounts_v2');
    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(accountsJson);
        decoded.forEach((key, value) {
          _accounts[key] =
              ParentAccount.fromJson(Map<String, dynamic>.from(value as Map));
        });
      } catch (_) {}
    }

    if (!_accounts.containsKey('parent@haneenkids.com')) {
      _accounts['parent@haneenkids.com'] = ParentAccount(
        fullName: 'أبو فارس (حساب تجريبي)',
        emailOrPhone: 'parent@haneenkids.com',
        password: '123456',
        parentalPin: '1234',
        warmEveningFilter: false,
        children: [
          ChildProfile(
            id: 'child_faris',
            name: 'فارس',
            age: '3–6 سنوات',
            dailyTimeLimit: 20,
            starsEarned: 4,
            chosenAvatar: '🦁',
            usedMinutesToday: 0,
            watchedVideosToday: 0,
          ),
          ChildProfile(
            id: 'child_noor',
            name: 'نور',
            age: '4–8 سنوات',
            dailyTimeLimit: 25,
            starsEarned: 6,
            chosenAvatar: '🦋',
            usedMinutesToday: 0,
            watchedVideosToday: 0,
          ),
        ],
        activeChildId: 'child_faris',
      );
      await _saveAccounts();
    }

    final String? loggedInUser = _prefs.getString('current_user_key');
    if (loggedInUser != null && _accounts.containsKey(loggedInUser)) {
      currentAccount = _accounts[loggedInUser];
      hasSelectedChildInSession =
          _prefs.getBool('has_selected_child_in_session') ?? true;
    }

    final String? savedVideosJson = _prefs.getString('saved_videos_v2');
    if (savedVideosJson != null && savedVideosJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(savedVideosJson);
        videos = list
            .map((item) =>
                VideoModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        videos = getDefaultVideos();
      }
    } else {
      videos = getDefaultVideos();
    }

    _syncLikedStateForActiveChild();
    _startScreenTimeTracker();
    isInitialized = true;
    notifyListeners();

    if (remoteFeedUrl.trim().isNotEmpty) {
      syncVideosFromRemoteUrl(remoteFeedUrl);
    }
  }

  void _startScreenTimeTracker() {
    _screenTimeTimer?.cancel();
    _screenTimeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (currentAccount != null && hasSelectedChildInSession) {
        final child = currentAccount!.activeChild;
        if (child.usedMinutesToday < child.dailyTimeLimit) {
          child.usedMinutesToday++;
          _activeSessionSeconds += 60;
          _saveAccounts();
          notifyListeners();
        }
      }
    });
  }

  int get activeSessionMinutes => (_activeSessionSeconds / 60).floor();

  bool get isDailyLimitReached {
    final child = currentAccount?.activeChild;
    if (child == null) return false;
    return child.usedMinutesToday >= child.dailyTimeLimit;
  }

  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    await _prefs.setBool('onboarding_completed', true);
    notifyListeners();
  }

  Future<void> _saveAccounts() async {
    final Map<String, dynamic> data = {};
    _accounts.forEach((key, acc) {
      data[key] = acc.toJson();
    });
    await _prefs.setString('registered_accounts_v2', jsonEncode(data));
  }

  Future<void> _saveVideos() async {
    final List<Map<String, dynamic>> data =
        videos.map((v) => v.toJson()).toList();
    await _prefs.setString('saved_videos_v2', jsonEncode(data));
  }

  void _syncLikedStateForActiveChild() {
    final child = currentAccount?.activeChild;
    if (child == null) return;
    for (final video in videos) {
      video.isLiked = child.likedVideoIds.contains(video.id);
    }
  }

  Future<String?> login(String emailOrPhone, String password) async {
    final key = emailOrPhone.trim().toLowerCase();
    if (key.isEmpty || password.isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني أو رقم الهاتف وكلمة المرور';
    }

    if (authApiUrl.trim().isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('${authApiUrl.trim()}/login'),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode({'emailOrPhone': key, 'password': password}),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is Map<String, dynamic> && json['account'] is Map) {
            final account = ParentAccount.fromJson(
                Map<String, dynamic>.from(json['account'] as Map));
            _accounts[key] = account;
            currentAccount = account;
            hasSelectedChildInSession = true;
            await _saveAccounts();
            await _prefs.setString('current_user_key', key);
            await _prefs.setBool('has_selected_child_in_session', true);
            _syncLikedStateForActiveChild();
            notifyListeners();
            return null;
          }
        }
      } catch (_) {}
    }

    final account = _accounts[key];
    if (account == null) {
      return 'لا يوجد حساب مسجل بهذا البريد أو الهاتف. أنشئ حساباً جديداً أولاً.';
    }
    if (account.password != password) {
      return 'كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى.';
    }

    currentAccount = account;
    hasSelectedChildInSession = true;
    await _prefs.setString('current_user_key', key);
    await _prefs.setBool('has_selected_child_in_session', true);
    _syncLikedStateForActiveChild();
    notifyListeners();
    return null;
  }

  Future<void> quickDemoLogin() async {
    onboardingCompleted = true;
    await _prefs.setBool('onboarding_completed', true);
    await login('parent@haneenkids.com', '123456');
  }

  Future<String?> registerParentAccount({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required String parentalPin,
    required String childName,
    required String childAgeGroup,
    required String childAvatar,
    required int dailyTimeLimit,
  }) async {
    final key = emailOrPhone.trim().toLowerCase();
    if (fullName.trim().isEmpty || key.isEmpty || password.length < 4) {
      return 'يرجى ملء كافة الحقول والتأكد أن كلمة المرور 4 أحرف أو أرقام على الأقل.';
    }
    if (parentalPin.trim().length != 4) {
      return 'يرجى إدخال رمز حماية أبوي (PIN) مكون من 4 أرقام.';
    }
    if (_accounts.containsKey(key)) {
      return 'هذا الحساب مسجل بالفعل، يمكنك تسجيل الدخول مباشرة.';
    }

    final firstChild = ChildProfile(
      id: 'child_${DateTime.now().millisecondsSinceEpoch}',
      name: childName.trim().isEmpty ? 'بطل حنين' : childName.trim(),
      age: childAgeGroup,
      dailyTimeLimit: dailyTimeLimit,
      chosenAvatar: childAvatar,
    );

    final newAccount = ParentAccount(
      fullName: fullName.trim(),
      emailOrPhone: key,
      password: password,
      parentalPin: parentalPin.trim(),
      warmEveningFilter: false,
      children: [firstChild],
      activeChildId: firstChild.id,
    );

    _accounts[key] = newAccount;
    currentAccount = newAccount;
    hasSelectedChildInSession = true;
    await _saveAccounts();
    await _prefs.setString('current_user_key', key);
    await _prefs.setBool('has_selected_child_in_session', true);
    _syncLikedStateForActiveChild();
    notifyListeners();
    return null;
  }

  Future<String?> resetPassword({
    required String emailOrPhone,
    required String parentalPin,
    required String newPassword,
  }) async {
    final key = emailOrPhone.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null) {
      return 'لم يتم العثور على حساب مرتبط بهذا البريد أو رقم الهاتف.';
    }
    if (account.parentalPin != parentalPin.trim()) {
      return 'رمز الحماية الأبوي (PIN) غير مطابق لهذا الحساب.';
    }
    if (newPassword.length < 4) {
      return 'كلمة المرور الجديدة يجب أن تكون 4 أحرف أو أرقام على الأقل.';
    }
    account.password = newPassword;
    await _saveAccounts();
    notifyListeners();
    return null;
  }

  Future<void> updateParentalPin(String newPin) async {
    if (currentAccount == null || newPin.trim().length != 4) return;
    currentAccount!.parentalPin = newPin.trim();
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> logout() async {
    currentAccount = null;
    hasSelectedChildInSession = false;
    await _prefs.remove('current_user_key');
    await _prefs.setBool('has_selected_child_in_session', false);
    notifyListeners();
  }

  Future<void> openChildProfilesScreen() async {
    hasSelectedChildInSession = false;
    await _prefs.setBool('has_selected_child_in_session', false);
    notifyListeners();
  }

  Future<void> selectChildAndEnterFeed(String childId) async {
    if (currentAccount == null) return;
    currentAccount!.activeChildId = childId;
    hasSelectedChildInSession = true;
    _syncLikedStateForActiveChild();
    await _saveAccounts();
    await _prefs.setBool('has_selected_child_in_session', true);
    notifyListeners();
  }

  Future<void> switchActiveChild(String childId) async {
    if (currentAccount == null) return;
    currentAccount!.activeChildId = childId;
    _syncLikedStateForActiveChild();
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> addChildProfile({
    required String name,
    required String age,
    required String chosenAvatar,
    required int dailyTimeLimit,
  }) async {
    if (currentAccount == null) return;
    final child = ChildProfile(
      id: 'child_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      age: age,
      chosenAvatar: chosenAvatar,
      dailyTimeLimit: dailyTimeLimit,
    );
    currentAccount!.children.add(child);
    currentAccount!.activeChildId = child.id;
    _syncLikedStateForActiveChild();
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> updateChildProfile({
    required String childId,
    required String name,
    required String age,
    required String chosenAvatar,
    required int dailyTimeLimit,
  }) async {
    if (currentAccount == null) return;
    final index = currentAccount!.children.indexWhere((c) => c.id == childId);
    if (index == -1) return;
    final child = currentAccount!.children[index];
    child.name = name.trim().isEmpty ? child.name : name.trim();
    child.age = age;
    child.chosenAvatar = chosenAvatar;
    child.dailyTimeLimit = dailyTimeLimit;
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> removeChildProfile(String childId) async {
    if (currentAccount == null || currentAccount!.children.length <= 1) return;
    currentAccount!.children.removeWhere((c) => c.id == childId);
    currentAccount!.activeChildId = currentAccount!.children.first.id;
    _syncLikedStateForActiveChild();
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> recordVideoTransitionWatched() async {
    if (currentAccount == null) return;
    final child = currentAccount!.activeChild;
    child.watchedVideosToday++;
    if (child.usedMinutesToday < child.dailyTimeLimit) {
      child.usedMinutesToday =
          min(child.dailyTimeLimit, child.usedMinutesToday + 2);
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> resetDailyScreenTimeForActiveChild() async {
    if (currentAccount == null) return;
    final child = currentAccount!.activeChild;
    child.usedMinutesToday = 0;
    child.watchedVideosToday = 0;
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> updateDailyTimeLimit(int newMinutesLimit) async {
    if (currentAccount == null) return;
    currentAccount!.activeChild.dailyTimeLimit = newMinutesLimit;
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> toggleWarmEveningFilter([bool? newValue]) async {
    if (currentAccount == null) return;
    currentAccount!.warmEveningFilter =
        newValue ?? !currentAccount!.warmEveningFilter;
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> awardStarAndRecordActivity(String activityKey) async {
    if (currentAccount == null) return;
    final child = currentAccount!.activeChild;
    child.starsEarned++;
    if (!child.completedActivities.contains(activityKey)) {
      child.completedActivities.add(activityKey);
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> toggleLikeVideo(VideoModel video) async {
    if (currentAccount == null) return;
    final child = currentAccount!.activeChild;
    if (video.isLiked) {
      video.isLiked = false;
      video.likes = max(0, video.likes - 1);
      child.likedVideoIds.remove(video.id);
    } else {
      video.isLiked = true;
      video.likes++;
      if (!child.likedVideoIds.contains(video.id)) {
        child.likedVideoIds.add(video.id);
      }
    }
    await _saveAccounts();
    await _saveVideos();
    notifyListeners();
  }

  Future<void> addCustomVideo(VideoModel newVideo) async {
    videos.insert(0, newVideo);
    _syncLikedStateForActiveChild();
    await _saveVideos();
    notifyListeners();
  }

  Future<void> deleteVideo(String videoId) async {
    if (videos.length <= 1) return;
    videos.removeWhere((v) => v.id == videoId);
    await _saveVideos();
    notifyListeners();
  }

  Future<void> restoreDefaultVideos() async {
    videos = getDefaultVideos();
    _syncLikedStateForActiveChild();
    await _saveVideos();
    notifyListeners();
  }

  Future<void> updateAuthApiUrl(String url) async {
    authApiUrl = url.trim();
    await _prefs.setString('auth_api_url', authApiUrl);
    notifyListeners();
  }

  Future<bool> syncVideosFromRemoteUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      lastSyncMessage = 'يرجى إدخال رابط ملف JSON سحابي صالح.';
      notifyListeners();
      return false;
    }

    isSyncingVideos = true;
    lastSyncMessage = 'جاري الاتصال بالسحابة وسحب تغذية الفيديوهات...';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final String body = utf8.decode(response.bodyBytes);
        final dynamic decoded = jsonDecode(body);

        List<dynamic>? rawList;
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['videos'] is List) {
          rawList = decoded['videos'] as List<dynamic>;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          rawList = decoded['data'] as List<dynamic>;
        }

        if (rawList != null && rawList.isNotEmpty) {
          final fetched = rawList
              .map((item) =>
                  VideoModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .where((v) => v.streamUrl.trim().isNotEmpty)
              .toList();

          if (fetched.isNotEmpty) {
            videos = fetched;
            remoteFeedUrl = cleanUrl;
            await _prefs.setString('remote_feed_url', remoteFeedUrl);
            _syncLikedStateForActiveChild();
            await _saveVideos();
            isSyncingVideos = false;
            lastSyncMessage =
                'تم بنجاح مزامنة واستقبال ${fetched.length} فيديو من الرابط السحابي!';
            notifyListeners();
            return true;
          }
        }
        isSyncingVideos = false;
        lastSyncMessage =
            'تم الاتصال ولكن لم يتم العثور على قائمة فيديوهات صالحة داخل ملف JSON.';
        notifyListeners();
        return false;
      } else {
        isSyncingVideos = false;
        lastSyncMessage =
            'تعذر الجلب من الرابط السحابي (كود الاستجابة: ${response.statusCode}).';
        notifyListeners();
        return false;
      }
    } catch (_) {
      isSyncingVideos = false;
      lastSyncMessage =
          'تعذر الاتصال بالرابط: تأكد من اتصال الإنترنت وصحة رابط ملف JSON.';
      notifyListeners();
      return false;
    }
  }

  String exportVideosAsJson() {
    final map = {
      'app': 'Haneen Kids v2.0',
      'version': 2,
      'updatedAt': DateTime.now().toIso8601String(),
      'videos': videos.map((v) => v.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  @override
  void dispose() {
    _screenTimeTimer?.cancel();
    super.dispose();
  }
}


class HaneenKidsApp extends StatelessWidget {
  final AppStateManager appState;
  const HaneenKidsApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'حنين كيدز (Haneen Kids v2.0)',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF14B8A6),
              secondary: Color(0xFFF59E0B),
              surface: Color(0xFF1E293B),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF14B8A6), width: 2),
              ),
            ),
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: SplashRouterScreen(appState: appState),
        );
      },
    );
  }
}


class SplashRouterScreen extends StatefulWidget {
  final AppStateManager appState;
  const SplashRouterScreen({super.key, required this.appState});

  @override
  State<SplashRouterScreen> createState() => _SplashRouterScreenState();
}

class _SplashRouterScreenState extends State<SplashRouterScreen> {
  bool _splashTimerDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _splashTimerDone = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.appState.isInitialized || !_splashTimerDone) {
      return const SplashScreen();
    }
    if (!widget.appState.onboardingCompleted) {
      return OnboardingScreen(appState: widget.appState);
    }
    if (widget.appState.currentAccount == null) {
      return AuthScreen(appState: widget.appState);
    }
    if (!widget.appState.hasSelectedChildInSession) {
      return MultiChildProfilesScreen(appState: widget.appState);
    }
    return VerticalVideoFeedPlayerScreen(appState: widget.appState);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF14B8A6).withOpacity(0.5),
                      width: 2),
                ),
                child: const Text('🌙✨', style: TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 20),
              const Text(
                'حنين كيدز (Haneen Kids v2.0)',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'مشاهدة هادئة • فطام ذكي • أنشطة واقعية',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Color(0xFF14B8A6)),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final AppStateManager appState;
  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _steps = [
    {
      'emoji': '🌿📺',
      'title': '١. المشاهدة الهادئة (Low-Stimulation)',
      'subtitle':
          'قصص مرئية مصممة خصيصاً للأطفال بإيقاع بصري وصوتي هادئ يحمي التركيز ويغذي الخيال واللغة العربية الفصحى بعيداً عن التشتت.',
    },
    {
      'emoji': '⏳🌙',
      'title': '٢. الفطام الذكي عن الشاشة',
      'subtitle':
          'يحدد الوالدان دقائق المشاهدة اليومية لكل طفل، ومع اقتراب المساء يعمل فلتر الإضاءة الدافئة ثم تنسدل «ستارة النوم الهادئة» بلطف.',
    },
    {
      'emoji': '🎯🏆',
      'title': '٣. الأنشطة الواقعية وتحدي الفصاحة',
      'subtitle':
          'كل قصة تنتهي بنافذة «ردد معي» لنطق جملة عربية فصيحة و«نشاط البطل الواقعي» لتنفيذ مهمة حركية وتربوية خارج الشاشة وكسب النجوم.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'حنين كيدز v2.0',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.appState.completeOnboarding,
                      child: const Text(
                        'تخطي إلى تسجيل الدخول',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final item = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              item['emoji']!,
                              style: const TextStyle(fontSize: 64),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            item['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item['subtitle']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? const Color(0xFF14B8A6)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (_currentPage < _steps.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.appState.completeOnboarding();
                          }
                        },
                        child: Text(
                          _currentPage < _steps.length - 1
                              ? 'الخطوة التالية'
                              : 'ابدأ الآن (إنشاء حساب أو دخول)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.appState.quickDemoLogin,
                        icon: const Icon(Icons.flash_on),
                        label: const Text(
                          'دخول سريع بحساب تجريبي (parent@haneenkids.com / 123456)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final AppStateManager appState;
  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController(text: '1234');
  final TextEditingController _childNameCtrl = TextEditingController();

  String _selectedAgeGroup = '3–6 سنوات';
  String _selectedAvatar = '🦁';
  int _initialDailyMinutes = 20;

  final List<String> _ageGroups = [
    '2–4 سنوات',
    '3–6 سنوات',
    '4–8 سنوات',
    '6–10 سنوات'
  ];
  final List<String> _avatars = ['🦁', '🦋', '🐰', '🐼', '🚀', '🌸', '🐬', '🦊'];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    _childNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    String? error;
    if (_isLogin) {
      error = await widget.appState.login(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
    } else {
      error = await widget.appState.registerParentAccount(
        fullName: _fullNameCtrl.text,
        emailOrPhone: _emailCtrl.text,
        password: _passwordCtrl.text,
        parentalPin: _pinCtrl.text,
        childName: _childNameCtrl.text,
        childAgeGroup: _selectedAgeGroup,
        childAvatar: _selectedAvatar,
        dailyTimeLimit: _initialDailyMinutes,
      );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
    }
  }

  void _quickDemoLogin() {
    _emailCtrl.text = 'parent@haneenkids.com';
    _passwordCtrl.text = '123456';
    setState(() => _isLogin = true);
    _submit();
  }

  void _showForgotPasswordModal() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text);
    final resetPinCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    String? modalError;
    String? modalSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                right: 24,
                left: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔑 استعادة وتغيير كلمة المرور',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أدخل بريدك الإلكتروني مع رمز الحماية الأبوي المكون من 4 أرقام (PIN) لتعيين كلمة مرور جديدة.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني أو رقم الهاتف',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resetPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'رمز الحماية الأبوي (PIN - الافتراضي 1234)',
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_clock_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: 10),
                    Text(modalError!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  if (modalSuccess != null) ...[
                    const SizedBox(height: 10),
                    Text(modalSuccess!,
                        style: const TextStyle(color: Color(0xFF14B8A6))),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final err = await widget.appState.resetPassword(
                          emailOrPhone: resetEmailCtrl.text,
                          parentalPin: resetPinCtrl.text,
                          newPassword: newPassCtrl.text,
                        );
                        setModalState(() {
                          modalError = err;
                          modalSuccess = err == null
                              ? 'تم تحديث كلمة المرور بنجاح! يمكنك تسجيل الدخول الآن.'
                              : null;
                        });
                      },
                      child: const Text('تحديث كلمة المرور'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF14B8A6).withOpacity(0.5),
                        ),
                      ),
                      child:
                          const Text('🌙✨', style: TextStyle(fontSize: 42)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'حنين كيدز — بوابة الوالدين',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'سجّل دخولك لمتابعة قصص أطفالك وإدارة وقت الشاشة'
                          : 'أنشئ حساباً جديداً للوالدين واحفظ رمز الـ PIN الأبوي',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isLogin = true;
                                _errorMessage = null;
                              }),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isLogin
                                      ? const Color(0xFF14B8A6)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'تسجيل الدخول (Sign In)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isLogin = false;
                                _errorMessage = null;
                              }),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isLogin
                                      ? const Color(0xFF14B8A6)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'حساب جديد (Sign Up)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_isLogin) ...[
                      TextField(
                        controller: _fullNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          hintText: 'مثال: أحمد محمد',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني أو رقم الهاتف',
                        hintText: 'parent@haneenkids.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'رمز الحماية الأبوي (PIN من 4 أرقام)',
                          counterText: '',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '👶 إعداد ملف الطفل الأول',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _childNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم الطفل',
                                hintText: 'مثال: فارس أو نور',
                                prefixIcon: Icon(Icons.child_care),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedAgeGroup,
                              decoration: const InputDecoration(
                                labelText: 'الفئة العمرية للطفل',
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              items: _ageGroups
                                  .map((age) => DropdownMenuItem(
                                        value: age,
                                        child: Text(age),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedAgeGroup = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'اختر الرمز التعبيري (Avatar) للطفل:',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _avatars.map((emoji) {
                                final isSelected = _selectedAvatar == emoji;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedAvatar = emoji),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF14B8A6)
                                              .withOpacity(0.3)
                                          : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF14B8A6)
                                            : Colors.white12,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(emoji,
                                        style: const TextStyle(fontSize: 22)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'دقائق المشاهدة اليومية:',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.white70),
                                ),
                                Text(
                                  '$_initialDailyMinutes دقيقة يومياً',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF14B8A6),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _initialDailyMinutes.toDouble(),
                              min: 5,
                              max: 60,
                              divisions: 11,
                              activeColor: const Color(0xFF14B8A6),
                              onChanged: (v) => setState(
                                  () => _initialDailyMinutes = v.round()),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLogin
                                    ? 'دخول إلى التطبيق'
                                    : 'إنشاء الحساب وحفظ PIN',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (_isLogin) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _showForgotPasswordModal,
                            child: const Text(
                              'نسيت كلمة المرور؟',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _quickDemoLogin,
                            icon: const Icon(Icons.flash_on,
                                size: 18, color: Color(0xFFF59E0B)),
                            label: const Text(
                              'دخول سريع بحساب تجريبي',
                              style: TextStyle(color: Color(0xFFF59E0B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class MultiChildProfilesScreen extends StatefulWidget {
  final AppStateManager appState;
  const MultiChildProfilesScreen({super.key, required this.appState});

  @override
  State<MultiChildProfilesScreen> createState() =>
      _MultiChildProfilesScreenState();
}

class _MultiChildProfilesScreenState extends State<MultiChildProfilesScreen> {
  final List<String> _ageGroups = [
    '2–4 سنوات',
    '3–6 سنوات',
    '4–8 سنوات',
    '6–10 سنوات'
  ];
  final List<String> _avatars = [
    '🦁',
    '🦋',
    '🐰',
    '🐼',
    '🚀',
    '🌸',
    '🐬',
    '🦊',
    '🐯',
    '🦄'
  ];

  void _showAddChildDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    String selectedAge = '3–6 سنوات';
    String selectedAvatar = '🦁';
    int selectedMinutes = 20;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                right: 24,
                left: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '➕ إضافة ملف طفل جديد',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطفل',
                        hintText: 'مثال: سارة أو عمر',
                        prefixIcon: Icon(Icons.child_care),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedAge,
                      decoration: const InputDecoration(
                        labelText: 'الفئة العمرية',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      items: _ageGroups
                          .map((age) => DropdownMenuItem(
                                value: age,
                                child: Text(age),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedAge = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اختر الرمز التعبيري (Avatar):',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _avatars.map((emoji) {
                        final isSelected = selectedAvatar == emoji;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedAvatar = emoji),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF14B8A6).withOpacity(0.3)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF14B8A6)
                                    : Colors.white12,
                                width: 2,
                              ),
                            ),
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'دقائق المشاهدة اليومية:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          '$selectedMinutes دقيقة / يومياً',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: selectedMinutes.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      activeColor: const Color(0xFF14B8A6),
                      onChanged: (val) =>
                          setModalState(() => selectedMinutes = val.round()),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          widget.appState.addChildProfile(
                            name: nameCtrl.text,
                            age: selectedAge,
                            chosenAvatar: selectedAvatar,
                            dailyTimeLimit: selectedMinutes,
                          );
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'حفظ ملف الطفل',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final account = widget.appState.currentAccount;
    if (account == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'من سيشاهد قصص حنين اليوم؟',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                widget.appState.selectChildAndEnterFeed(account.activeChildId),
            icon: const Icon(Icons.play_circle_fill, color: Color(0xFF14B8A6)),
            label: const Text(
              'المشغل',
              style: TextStyle(
                  color: Color(0xFF14B8A6), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك يا ${account.fullName} 👋 اختر ملف الطفل للبدء أو أضف طفلاً جديداً:',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: account.children.length + 1,
                    itemBuilder: (context, index) {
                      if (index == account.children.length) {
                        return GestureDetector(
                          onTap: _showAddChildDialog,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF14B8A6).withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Color(0xFF14B8A6),
                                  child: Icon(Icons.add,
                                      size: 34, color: Colors.white),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'إضافة طفل جديد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'تخصيص العمر والوقت',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final child = account.children[index];
                      final isSelected = child.id == account.activeChildId;
                      return GestureDetector(
                        onTap: () =>
                            widget.appState.selectChildAndEnterFeed(child.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF14B8A6).withOpacity(0.18)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF14B8A6)
                                  : Colors.white12,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                child.chosenAvatar,
                                style: const TextStyle(fontSize: 50),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                child.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                child.age,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '⏱️ ${child.usedMinutesToday}/${child.dailyTimeLimit} د • ⭐ ${child.starsEarned}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}


class VerticalVideoFeedPlayerScreen extends StatefulWidget {
  final AppStateManager appState;
  const VerticalVideoFeedPlayerScreen({super.key, required this.appState});

  @override
  State<VerticalVideoFeedPlayerScreen> createState() =>
      _VerticalVideoFeedPlayerScreenState();
}

class _VerticalVideoFeedPlayerScreenState
    extends State<VerticalVideoFeedPlayerScreen> {
  final PageController _pageController = PageController();
  String _selectedCategory = 'all';
  int _currentVideoIndex = 0;

  List<VideoModel> get _filteredVideos {
    final all = widget.appState.videos;
    if (_selectedCategory == 'all') return all;
    return all.where((v) => v.category == _selectedCategory).toList();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
    });
    widget.appState.recordVideoTransitionWatched();
  }

  void _openRepeatWithMeModal(VideoModel item) {
    bool isRecording = false;
    bool hasRecorded = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (isRecording) return;
                      setModalState(() {
                        isRecording = true;
                      });
                      await Future.delayed(const Duration(seconds: 2));
                      if (ctx.mounted) {
                        setModalState(() {
                          isRecording = false;
                          hasRecorded = true;
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isRecording
                            ? Colors.redAccent.withOpacity(0.25)
                            : const Color(0xFFF59E0B).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecording
                              ? Colors.redAccent
                              : const Color(0xFFF59E0B),
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        isRecording ? Icons.mic : Icons.mic_none_rounded,
                        size: 46,
                        color: isRecording
                            ? Colors.redAccent
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRecording
                        ? '🎙️ جاري الاستماع لصوتك الجميل...'
                        : 'نافذة «ردد معي» للفصاحة والنطق',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اضغط على زر الميكروفون وردد هذه الجملة العربية الفصيحة بصوت واضح:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF14B8A6)),
                    ),
                    child: Text(
                      item.repeatPhrase,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.appState
                            .awardStarAndRecordActivity('phrase_${item.id}');
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '🎉 أحسنت المحاكاة والنطق يا بطل! ربحت نجمة الفصاحة ⭐'),
                            backgroundColor: Color(0xFF14B8A6),
                          ),
                        );
                      },
                      icon: Icon(hasRecorded ? Icons.verified : Icons.star),
                      label: Text(
                        hasRecorded
                            ? 'تمت المحاكاة بنجاح! استلم نجمتك ⭐'
                            : 'رددتها بصوت فصيح! (احصل على نجمة ⭐)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openRealWorldHeroActivityModal(VideoModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              const Text(
                'نافذة «نشاط البطل الواقعي»',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14B8A6),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'مهمة حركية وتربوية ممتعة لتقوم بها خارج الشاشة الآن:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text(
                  item.activeActivity,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    widget.appState
                        .awardStarAndRecordActivity('activity_${item.id}');
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '🌟 بطل حقيقي! أضفنا نجمة جديدة إلى رصيدك بعد إنجاز النشاط!'),
                        backgroundColor: Color(0xFFF59E0B),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events),
                  label: const Text(
                    'أنجزت النشاط الواقعي! (+1 نجمة ⭐)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openParentalGateDialog() {
    final random = Random();
    final int a = random.nextInt(6) + 4;
    final int b = random.nextInt(5) + 3;
    final int expected = a * b;
    final TextEditingController answerCtrl = TextEditingController();
    String? gateError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بوابة الوالدين المحمية',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'للدخول إلى استوديو الفيديوهات وضوابط الوقت، حل المعادلة الحسابية أو أدخل الرمز السري (PIN):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'كم ناتج:  $a × $b = ؟',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: answerCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'أدخل ناتج المعادلة أو رمز PIN',
                    ),
                  ),
                  if (gateError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      gateError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final input = answerCtrl.text.trim();
                    final pin =
                        widget.appState.currentAccount?.parentalPin ?? '1234';
                    if (input == expected.toString() || input == pin) {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentalStudioScreen(
                            appState: widget.appState,
                          ),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        gateError = 'الإجابة أو رمز PIN غير صحيح.';
                      });
                    }
                  },
                  child: const Text('دخول استوديو الوالدين'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.appState.currentAccount!;
    final activeChild = account.activeChild;
    final videos = _filteredVideos;
    final bool sleepCurtainActive = widget.appState.isDailyLimitReached;

    return Scaffold(
      body: Stack(
        children: [
          if (videos.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📭', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  const Text(
                    'لا توجد قصص في هذا القسم حالياً',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedCategory = 'all'),
                    child: const Text('عرض كل القصص'),
                  ),
                ],
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = videos[index];
                final isCurrentPage =
                    index == _currentVideoIndex && !sleepCurtainActive;
                return VerticalVideoFeedItemWidget(
                  key: ValueKey('${item.id}_$index'),
                  video: item,
                  isActive: isCurrentPage,
                  onLikeTap: () => widget.appState.toggleLikeVideo(item),
                  onRepeatPhraseTap: () => _openRepeatWithMeModal(item),
                  onHeroActivityTap: () =>
                      _openRealWorldHeroActivityModal(item),
                );
              },
            ),

          if (account.warmEveningFilter)
            IgnorePointer(
              child: Container(
                color: const Color(0xFFFF8F00).withOpacity(0.20),
              ),
            ),

          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.appState.openChildProfilesScreen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(activeChild.chosenAvatar,
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                activeChild.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.swap_horiz, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Text(
                          '⭐ ${activeChild.starsEarned}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '⏱️ ${activeChild.usedMinutesToday}/${activeChild.dailyTimeLimit}د',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => widget.appState.toggleWarmEveningFilter(),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: account.warmEveningFilter
                                ? const Color(0xFFF59E0B)
                                : Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            Icons.wb_twilight_rounded,
                            size: 18,
                            color: account.warmEveningFilter
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _openParentalGateDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'الوالدين',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: kVideoCategories.length,
                    itemBuilder: (ctx, i) {
                      final cat = kVideoCategories[i];
                      final isSelected = _selectedCategory == cat['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat['id']!;
                            _currentVideoIndex = 0;
                          });
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF14B8A6)
                                : Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF14B8A6)
                                  : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${cat['icon']} ${cat['title']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (sleepCurtainActive)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌙💤✨', style: TextStyle(fontSize: 68)),
                      const SizedBox(height: 20),
                      Text(
                        'ستارة النوم الهادئة — تصبح على خير يا ${activeChild.name}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'انتهت حصتك اليومية (${activeChild.dailyTimeLimit} دقيقة) بهدوء، وجمعت ⭐ ${activeChild.starsEarned} نجوم رائعة! حان الآن وقت إراحة العينين والاستعداد للنوم الجميل.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _openParentalGateDialog,
                        icon: const Icon(Icons.lock_open),
                        label: const Text(
                          'بوابة الوالدين (لتمديد الوقت أو تغيير الطفل)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VerticalVideoFeedItemWidget extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final VoidCallback onLikeTap;
  final VoidCallback onRepeatPhraseTap;
  final VoidCallback onHeroActivityTap;

  const VerticalVideoFeedItemWidget({
    super.key,
    required this.video,
    required this.isActive,
    required this.onLikeTap,
    required this.onRepeatPhraseTap,
    required this.onHeroActivityTap,
  });

  @override
  State<VerticalVideoFeedItemWidget> createState() =>
      _VerticalVideoFeedItemWidgetState();
}

class _VerticalVideoFeedItemWidgetState
    extends State<VerticalVideoFeedItemWidget> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  @override
  void didUpdateWidget(covariant VerticalVideoFeedItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.streamUrl != widget.video.streamUrl) {
      _disposeController();
      _initVideoPlayer();
    } else if (oldWidget.isActive != widget.isActive && _isInitialized) {
      if (widget.isActive) {
        _videoController?.play();
      } else {
        _videoController?.pause();
      }
    }
  }

  Future<void> _initVideoPlayer() async {
    final url = widget.video.streamUrl.trim();
    if (url.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      final VideoFormat? formatHint =
          url.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null;
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        formatHint: formatHint,
      );
      _videoController = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      if (widget.isActive) {
        await ctrl.play();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _disposeController() {
    _videoController?.dispose();
    _videoController = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlayPause() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      } else {
        ctrl.play();
      }
    });
  }

  void _toggleMute() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      ctrl.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.video;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [item.bgGradientStart, item.bgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitialized && _videoController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 76)),
                      const SizedBox(height: 16),
                      if (!_hasError) ...[
                        const CircularProgressIndicator(
                            color: Color(0xFF14B8A6)),
                        const SizedBox(height: 12),
                        const Text(
                          'جاري تحضير البث المرئي الهادئ...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ] else ...[
                        const Text(
                          'وضع القصة المصورة الهادئة',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _initVideoPlayer,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('إعادة تحميل بث الفيديو'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                      Colors.black.withOpacity(0.82),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            if (_isInitialized &&
                _videoController != null &&
                !_videoController!.value.isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
            Positioned(
              left: 16,
              bottom: 110,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SideActionButton(
                    icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
                    iconColor: item.isLiked ? Colors.redAccent : Colors.white,
                    label: '${item.likes}',
                    onTap: widget.onLikeTap,
                  ),
                  const SizedBox(height: 16),
                  _SideActionButton(
                    icon: Icons.mic_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'ردد معي',
                    onTap: widget.onRepeatPhraseTap,
                  ),
                  const SizedBox(height: 16),
                  _SideActionButton(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFF14B8A6),
                    label: 'نشاط البطل',
                    onTap: widget.onHeroActivityTap,
                  ),
                  const SizedBox(height: 16),
                  _SideActionButton(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    iconColor: Colors.white,
                    label: _isMuted ? 'صامت' : 'الصوت',
                    onTap: _toggleMute,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              left: 88,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF14B8A6).withOpacity(0.6)),
                        ),
                        child: Text(
                          VideoModel.getCategoryDisplayLabel(item.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🎂 ${item.ageGroup}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: widget.onRepeatPhraseTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic,
                              size: 16, color: Color(0xFFFDE68A)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.repeatPhrase,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isInitialized && _videoController != null)
              Positioned(
                right: 0,
                left: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF14B8A6),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SideActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}


class ParentalStudioScreen extends StatefulWidget {
  final AppStateManager appState;
  const ParentalStudioScreen({super.key, required this.appState});

  @override
  State<ParentalStudioScreen> createState() => _ParentalStudioScreenState();
}

class _ParentalStudioScreenState extends State<ParentalStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FormState> _manualVideoFormKey = GlobalKey<FormState>();

  late TextEditingController _remoteUrlCtrl;
  final TextEditingController _vTitleCtrl = TextEditingController();
  final TextEditingController _vDescCtrl = TextEditingController();
  final TextEditingController _vUrlCtrl = TextEditingController();
  final TextEditingController _vPhraseCtrl = TextEditingController();
  final TextEditingController _vActivityCtrl = TextEditingController();
  final TextEditingController _vEmojiCtrl = TextEditingController(text: '🌟');
  String _vCategory = 'bedtime';
  String _vAgeGroup = '3–6 سنوات';

  final TextEditingController _newChildNameCtrl = TextEditingController();
  String _newChildAge = '3–6 سنوات';
  String _newChildAvatar = '🐰';
  int _newChildDailyLimit = 20;

  late TextEditingController _authApiCtrl;
  late TextEditingController _pinUpdateCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _remoteUrlCtrl =
        TextEditingController(text: widget.appState.remoteFeedUrl);
    _authApiCtrl = TextEditingController(text: widget.appState.authApiUrl);
    _pinUpdateCtrl = TextEditingController(
        text: widget.appState.currentAccount?.parentalPin ?? '1234');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _remoteUrlCtrl.dispose();
    _vTitleCtrl.dispose();
    _vDescCtrl.dispose();
    _vUrlCtrl.dispose();
    _vPhraseCtrl.dispose();
    _vActivityCtrl.dispose();
    _vEmojiCtrl.dispose();
    _newChildNameCtrl.dispose();
    _authApiCtrl.dispose();
    _pinUpdateCtrl.dispose();
    super.dispose();
  }

  void _submitManualVideoForm() {
    if (!_manualVideoFormKey.currentState!.validate()) return;

    final newVideo = VideoModel(
      id: 'v_${DateTime.now().millisecondsSinceEpoch}',
      title: _vTitleCtrl.text.trim(),
      description: _vDescCtrl.text.trim().isEmpty
          ? 'قصة هادئة وممتعة لأطفالنا الأبطال.'
          : _vDescCtrl.text.trim(),
      category: _vCategory,
      ageGroup: _vAgeGroup,
      repeatPhrase: _vPhraseCtrl.text.trim().isEmpty
          ? '«أَنَا أَتَعَلَّمُ كُلَّ يَوْمٍ شَيْئاً جَدِيداً»'
          : _vPhraseCtrl.text.trim(),
      activeActivity: _vActivityCtrl.text.trim().isEmpty
          ? 'احكِ لماما أو بابا ماذا أعجبك في هذه القصة!'
          : _vActivityCtrl.text.trim(),
      streamUrl: _vUrlCtrl.text.trim(),
      bgGradientStart: const Color(0xFF1E1B4B),
      bgGradientEnd: const Color(0xFF0F172A),
      emoji: _vEmojiCtrl.text.trim().isEmpty ? '🌟' : _vEmojiCtrl.text.trim(),
      likes: 100,
    );

    widget.appState.addCustomVideo(newVideo);
    _vTitleCtrl.clear();
    _vDescCtrl.clear();
    _vUrlCtrl.clear();
    _vPhraseCtrl.clear();
    _vActivityCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تمت إضافة الفيديو بنجاح إلى المكتبة المحلية!'),
        backgroundColor: Color(0xFF14B8A6),
      ),
    );
  }

  void _copyExportedJson() {
    final jsonStr = widget.appState.exportVideosAsJson();
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 تم نسخ كود JSON لجميع الفيديوهات إلى الحافظة!'),
        backgroundColor: Color(0xFF14B8A6),
      ),
    );
  }

  void _showEditChildModal(ChildProfile child) {
    final editNameCtrl = TextEditingController(text: child.name);
    String editAge = child.age;
    String editAvatar = child.chosenAvatar;
    int editLimit = child.dailyTimeLimit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                right: 24,
                left: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✏️ تعديل ملف الطفل',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الطفل',
                      prefixIcon: Icon(Icons.child_care),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: editAge,
                          decoration:
                              const InputDecoration(labelText: 'الفئة العمرية'),
                          items: const [
                            DropdownMenuItem(
                                value: '2–4 سنوات', child: Text('2–4 سنوات')),
                            DropdownMenuItem(
                                value: '3–6 سنوات', child: Text('3–6 سنوات')),
                            DropdownMenuItem(
                                value: '4–8 سنوات', child: Text('4–8 سنوات')),
                            DropdownMenuItem(
                                value: '6–10 سنوات', child: Text('6–10 سنوات')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModalState(() => editAge = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: editAvatar,
                        items: ['🦁', '🦋', '🐰', '🐼', '🚀', '🌸', '🐬', '🦊']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 24)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => editAvatar = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('الحد اليومي: $editLimit دقيقة'),
                  Slider(
                    value: editLimit.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: const Color(0xFF14B8A6),
                    onChanged: (v) =>
                        setModalState(() => editLimit = v.round()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        widget.appState.updateChildProfile(
                          childId: child.id,
                          name: editNameCtrl.text,
                          age: editAge,
                          chosenAvatar: editAvatar,
                          dailyTimeLimit: editLimit,
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('حفظ التعديلات'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final account = widget.appState.currentAccount;
        if (account == null) {
          return const SizedBox.shrink();
        }
        final activeChild = account.activeChild;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'بوابة الوالدين واستوديو الفيديوهات',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF14B8A6),
              labelColor: const Color(0xFF14B8A6),
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(
                    icon: Icon(Icons.cloud_download_outlined),
                    text: 'استقبال الفيديوهات'),
                Tab(
                    icon: Icon(Icons.timer_outlined),
                    text: 'وقت الشاشة والتقارير'),
                Tab(icon: Icon(Icons.child_care), text: 'ملفات الأطفال'),
                Tab(
                    icon: Icon(Icons.manage_accounts_outlined),
                    text: 'إعدادات الحساب'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF14B8A6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_sync, color: Color(0xFF14B8A6)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'الربط السحابي (JSON Feed URL)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أدخل رابط ملف JSON المباشر لجلب الفيديوهات سحابياً عبر حزمة http وتحديث المكتبة بضغطة زر.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _remoteUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رابط ملف JSON المباشر',
                            hintText:
                                'https://example.com/sample_videos_feed.json',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        if (widget.appState.lastSyncMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.appState.lastSyncMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: widget.appState.isSyncingVideos
                                    ? null
                                    : () => widget.appState
                                        .syncVideosFromRemoteUrl(
                                            _remoteUrlCtrl.text),
                                icon: const Icon(Icons.sync),
                                label: Text(
                                  widget.appState.isSyncingVideos
                                      ? 'جاري المزامنة...'
                                      : 'مزامنة الآن',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _copyExportedJson,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('تصدير JSON'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Form(
                      key: _manualVideoFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '➕ نموذج (Form) إضافة فيديو يدوي للمكتبة المحلية',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _vTitleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'عنوان الفيديو / القصة',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty)
                                    ? 'يرجى إدخال عنوان القصة'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _vUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'رابط البث المباشر (MP4 أو HLS .m3u8)',
                              hintText: 'https://.../video.mp4',
                              prefixIcon: Icon(Icons.video_library_outlined),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty)
                                    ? 'يرجى إدخال رابط البث'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _vCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'القسم',
                                  ),
                                  items: kVideoCategories
                                      .where((p) => p['id'] != 'all')
                                      .map((p) => DropdownMenuItem(
                                            value: p['id'],
                                            child: Text(
                                                '${p['icon']} ${p['title']}'),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _vCategory = v);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _vAgeGroup,
                                  decoration: const InputDecoration(
                                    labelText: 'الفئة العمرية',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '2–4 سنوات',
                                        child: Text('2–4 سنوات')),
                                    DropdownMenuItem(
                                        value: '3–6 سنوات',
                                        child: Text('3–6 سنوات')),
                                    DropdownMenuItem(
                                        value: '4–8 سنوات',
                                        child: Text('4–8 سنوات')),
                                    DropdownMenuItem(
                                        value: '6–10 سنوات',
                                        child: Text('6–10 سنوات')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _vAgeGroup = v);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _vDescCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'وصف القصة (description)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _vPhraseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'جملة «ردد معي» الفصيحة (repeatPhrase)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _vActivityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'نشاط البطل الواقعي (activeActivity)',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black87,
                              ),
                              onPressed: _submitManualVideoForm,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text(
                                'حفظ وإضافة الفيديو للمكتبة المحلية',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📚 مكتبة الفيديوهات (${widget.appState.videos.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.appState.restoreDefaultVideos,
                        child: const Text('استعادة الافتراضي'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.appState.videos.map((v) {
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading:
                            Text(v.emoji, style: const TextStyle(fontSize: 28)),
                        title: Text(
                          v.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${VideoModel.getCategoryDisplayLabel(v.category)} • ${v.ageGroup}\n${v.streamUrl}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white60),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => widget.appState.deleteVideo(v.id),
                        ),
                      ),
                    );
                  }),
                ],
              ),

              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏱️ التحكم في وقت الشاشة اليومي (${activeChild.name})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'استهلك اليوم: ${activeChild.usedMinutesToday} دقيقة من أصل ${activeChild.dailyTimeLimit} دقيقة • شاهد ${activeChild.watchedVideosToday} قصص',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Slider(
                          value: activeChild.dailyTimeLimit
                              .toDouble()
                              .clamp(5.0, 60.0),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          activeColor: const Color(0xFF14B8A6),
                          label: '${activeChild.dailyTimeLimit} دقيقة',
                          onChanged: (val) => widget.appState
                              .updateDailyTimeLimit(val.round()),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget
                                .appState.resetDailyScreenTimeForActiveChild,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text(
                                'تصفير وقت المشاهدة اليومي وإلغاء ستارة النوم'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SwitchListTile(
                      value: account.warmEveningFilter,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (val) =>
                          widget.appState.toggleWarmEveningFilter(val),
                      title: const Text(
                        '🌙 فلتر المساء الدافئ (تقليل الإضاءة الزرقاء)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'يضيف طبقة كهرمانية دافئة مريحة للعينين قبل النوم.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📊 تقارير أداء وتفاعل الأطفال',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...account.children.map((c) {
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(c.chosenAvatar,
                                    style: const TextStyle(fontSize: 30)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${c.name} (${c.age})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '⭐ ${c.starsEarned} نجوم',
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '• وقت المشاهدة اليوم: ${c.usedMinutesToday} / ${c.dailyTimeLimit} دقيقة\n'
                              '• الأنشطة والجمل الفصيحة المنجزة: ${c.completedActivities.length} مهمة\n'
                              '• القصص المفضلة: ${c.likedVideoIds.length} قصة',
                              style: const TextStyle(
                                  color: Colors.white70, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),

              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    '👨‍👩‍👧‍👦 إدارة وتعديل ملفات الأطفال',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...account.children.map((child) {
                    final isCurrent = child.id == account.activeChildId;
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isCurrent
                              ? const Color(0xFF14B8A6)
                              : Colors.white12,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => widget.appState.switchActiveChild(child.id),
                        leading: Text(child.chosenAvatar,
                            style: const TextStyle(fontSize: 32)),
                        title: Text(
                          '${child.name} (${child.age})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الحصة اليومية: ${child.dailyTimeLimit} دقيقة • ⭐ ${child.starsEarned}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Color(0xFF14B8A6)),
                              onPressed: () => _showEditChildModal(child),
                            ),
                            if (account.children.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () => widget.appState
                                    .removeChildProfile(child.id),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '➕ إضافة ملف طفل جديد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newChildNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الطفل',
                            prefixIcon: Icon(Icons.child_care),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _newChildAge,
                                decoration: const InputDecoration(
                                  labelText: 'الفئة العمرية',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: '2–4 سنوات',
                                      child: Text('2–4 سنوات')),
                                  DropdownMenuItem(
                                      value: '3–6 سنوات',
                                      child: Text('3–6 سنوات')),
                                  DropdownMenuItem(
                                      value: '4–8 سنوات',
                                      child: Text('4–8 سنوات')),
                                  DropdownMenuItem(
                                      value: '6–10 سنوات',
                                      child: Text('6–10 سنوات')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _newChildAge = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            DropdownButton<String>(
                              value: _newChildAvatar,
                              items: ['🦁', '🦋', '🐰', '🐼', '🚀', '🌸']
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e,
                                            style:
                                                const TextStyle(fontSize: 24)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _newChildAvatar = v);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                            'دقائق المشاهدة اليومية: $_newChildDailyLimit دقيقة'),
                        Slider(
                          value: _newChildDailyLimit.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          activeColor: const Color(0xFF14B8A6),
                          onChanged: (v) =>
                              setState(() => _newChildDailyLimit = v.round()),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14B8A6),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (_newChildNameCtrl.text.trim().isEmpty) return;
                              widget.appState.addChildProfile(
                                name: _newChildNameCtrl.text,
                                age: _newChildAge,
                                chosenAvatar: _newChildAvatar,
                                dailyTimeLimit: _newChildDailyLimit,
                              );
                              _newChildNameCtrl.clear();
                            },
                            child: const Text('حفظ ملف الطفل'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF14B8A6),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            account.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            'البريد / الهاتف: ${account.emailOrPhone}\nالرمز الأبوي الحالي (PIN): ${account.parentalPin}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 28),
                        const Text(
                          '🔐 تحديث الرمز السري الأبوي (PIN من 4 أرقام)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pinUpdateCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  labelText: 'رمز PIN الجديد',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (_pinUpdateCtrl.text.trim().length == 4) {
                                  widget.appState
                                      .updateParentalPin(_pinUpdateCtrl.text);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تحديث رمز PIN الأبوي'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('حفظ PIN'),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 28),
                        const Text(
                          '🌐 رابط سيرفر المصادقة الخارجي (اختياري)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _authApiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Auth REST API Base URL',
                            hintText: 'https://api.yourdomain.com/auth',
                            prefixIcon: Icon(Icons.api),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () {
                              widget.appState
                                  .updateAuthApiUrl(_authApiCtrl.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم حفظ رابط سيرفر المصادقة'),
                                ),
                              );
                            },
                            child: const Text('حفظ إعداد السيرفر'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        await widget.appState.logout();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'تسجيل الخروج من الحساب',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
