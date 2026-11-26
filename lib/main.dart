import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/run_entry.dart';
import 'services/run_repository.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
bool supabaseReady = false;
String? supabaseConfigError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasUrl = supabaseUrl.trim().isNotEmpty;
  final hasKey = supabasePublishableKey.trim().isNotEmpty;
  if (hasUrl != hasKey) {
    supabaseConfigError = 'กรุณาตั้งค่า SUPABASE_URL และ SUPABASE_PUBLISHABLE_KEY ให้ครบ';
  } else if (hasUrl) {
    if (!supabaseUrl.startsWith('https://') ||
        !isAllowedSupabaseClientKey(supabasePublishableKey)) {
      supabaseConfigError = 'ต้องใช้ Project URL แบบ HTTPS และ publishable/anon key เท่านั้น';
    } else {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabasePublishableKey,
        );
        final auth = Supabase.instance.client.auth;
        if (auth.currentSession == null) {
          await auth.signInAnonymously();
        }
        supabaseReady = true;
      } catch (error) {
        supabaseConfigError = 'เริ่มต้น Supabase ไม่สำเร็จ: $error';
      }
    }
  }
  runApp(const RunTrackerApp());
}

bool isAllowedSupabaseClientKey(String key) {
  if (key.startsWith('sb_publishable_')) {
    return key.length > 'sb_publishable_'.length;
  }
  final parts = key.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    return payload['role'] == 'anon';
  } catch (_) {
    return false;
  }
}

const navy = Color(0xFF101B3D);
const blue = Color(0xFF1877F2);
const paleBlue = Color(0xFFEAF3FF);
const muted = Color(0xFF7D879A);

class RunTrackerApp extends StatelessWidget {
  const RunTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Run Tracker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      fontFamily: 'Roboto',
    ),
    home: supabaseConfigError != null
        ? SupabaseConfigErrorPage(message: supabaseConfigError!)
        : supabaseReady
        ? const SupabaseAuthGate()
        : const TrackerShell(),
  );
}

class SupabaseConfigErrorPage extends StatelessWidget {
  const SupabaseConfigErrorPage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

class SupabaseAuthGate extends StatelessWidget {
  const SupabaseAuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) =>
        Supabase.instance.client.auth.currentSession == null
        ? const AuthPage()
        : const TrackerShell(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text);
        if (mounted && auth.currentSession == null) {
          setState(
            () => error = 'สมัครสมาชิกแล้ว กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 88,
                width: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: paleBlue,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: blue,
                  size: 48,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Run Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                register
                    ? 'สร้างบัญชีเพื่อเริ่มบันทึกการวิ่ง'
                    : 'เข้าสู่ระบบเพื่อดูประวัติการวิ่ง',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  busy
                      ? 'กำลังดำเนินการ...'
                      : register
                      ? 'สมัครสมาชิก'
                      : 'เข้าสู่ระบบ',
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        register = !register;
                        error = null;
                      }),
                child: Text(
                  register
                      ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                      : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TrackerShell extends StatefulWidget {
  const TrackerShell({super.key});
  @override
  State<TrackerShell> createState() => _TrackerShellState();
}

class _TrackerShellState extends State<TrackerShell> {
  int tab = 0;
  final runs = <RunEntry>[
    RunEntry(
      place: 'สวนลุมพินี',
      distance: 5.2,
      minutes: 32,
      date: DateTime(2026, 10, 25),
    ),
    RunEntry(
      place: 'สวนรถไฟ',
      distance: 3.0,
      minutes: 21,
      date: DateTime(2026, 10, 22),
    ),
    RunEntry(
      place: 'สนามกีฬาแห่งชาติ',
      distance: 10.5,
      minutes: 65,
      date: DateTime(2026, 10, 18),
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (supabaseReady) _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(runs.clear);
    try {
      final loaded = await RunRepository(Supabase.instance.client).getRuns();
      if (mounted) {
        setState(() {
          runs
            ..clear()
            ..addAll(loaded);
        });
      }
    } catch (error) {
      if (mounted) _showMessage('โหลดประวัติไม่สำเร็จ: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> addRun() async {
    final entry = await Navigator.of(
      context,
    ).push<RunEntry>(MaterialPageRoute(builder: (_) => const AddRunPage()));
    if (entry == null || !mounted) return;
    if (supabaseReady) {
      try {
        final saved = await RunRepository(
          Supabase.instance.client,
        ).addRun(entry);
        if (mounted) setState(() => runs.insert(0, saved));
      } catch (error) {
        _showMessage('บันทึกไม่สำเร็จ: $error');
        return;
      }
      return;
    }
    if (mounted) setState(() => runs.insert(0, entry));
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'สวัสดี, นักวิ่ง 👋',
      'ประวัติการวิ่ง',
      'สถิติของฉัน',
      'โปรไฟล์',
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[tab],
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (tab == 0)
              const Text(
                'พร้อมออกไปวิ่งวันนี้หรือยัง?',
                style: TextStyle(color: muted, fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: navy),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          HomePage(
            runs: runs,
            onAdd: addRun,
            onHistory: () => setState(() => tab = 1),
          ),
          HistoryPage(runs: runs),
          StatsPage(runs: runs),
          const ProfilePage(),
        ],
      ),
      floatingActionButton: tab == 0 || tab == 1
          ? FloatingActionButton.extended(
              onPressed: addRun,
              backgroundColor: blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'บันทึกการวิ่ง',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        backgroundColor: Colors.white,
        indicatorColor: paleBlue,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'ประวัติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'สถิติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.runs,
    required this.onAdd,
    required this.onHistory,
  });
  final List<RunEntry> runs;
  final VoidCallback onAdd;
  final VoidCallback onHistory;
  double get total => runs.fold(0, (sum, run) => sum + run.distance);

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
    children: [
      _hero(onAdd),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _metric(
              'ระยะทางรวม',
              total.toStringAsFixed(1),
              'กม.',
              Icons.route_rounded,
              blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              'จำนวนครั้ง',
              '${runs.length}',
              'ครั้ง',
              Icons.directions_run_rounded,
              const Color(0xFF06A975),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'การวิ่งล่าสุด',
            style: TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextButton(onPressed: onHistory, child: const Text('ดูทั้งหมด')),
        ],
      ),
      ...runs.take(3).map((run) => RunCard(run: run)),
    ],
  );
}

Widget _hero(VoidCallback onAdd) => Container(
  padding: const EdgeInsets.all(22),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF1478F8), Color(0xFF3EA7FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(26),
    boxShadow: [
      BoxShadow(
        color: blue.withValues(alpha: .2),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'เป้าหมายประจำสัปดาห์',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '12.4',
            style: TextStyle(
              color: Colors.white,
              fontSize: 39,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 7),
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '/ 20 กม.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const LinearProgressIndicator(
          value: .62,
          minHeight: 7,
          backgroundColor: Color(0x55FFFFFF),
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 17),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'อีกนิดเดียวก็ถึงเป้าหมายแล้ว!',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('เริ่มวิ่ง'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: blue,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    ],
  ),
);

Widget _metric(
  String title,
  String value,
  String unit,
  IconData icon,
  Color color,
) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFEFF2F7)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
          Icon(icon, color: color, size: 19),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 25,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              unit,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ],
  ),
);

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.runs});
  final List<RunEntry> runs;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: blue),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'เดือนนี้',
                style: TextStyle(color: navy, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${runs.length} รายการ',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ...runs.map((run) => RunCard(run: run)),
    ],
  );
}

class RunCard extends StatelessWidget {
  const RunCard({super.key, required this.run});
  final RunEntry run;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFEFF2F7)),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: run.imageUrl != null
              ? Image.network(
                  run.imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _runIcon(),
                )
              : run.imageBytes != null
              ? Image.memory(
                  run.imageBytes!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                )
              : _runIcon(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                run.place,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${run.date.day}/${run.date.month}/${run.date.year}  •  ${run.minutes} นาที',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${run.distance.toStringAsFixed(1)} กม.',
              style: const TextStyle(
                color: blue,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'เพซ ${run.pace}/กม.',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _runIcon() => Container(
  width: 44,
  height: 44,
  color: paleBlue,
  child: const Icon(Icons.directions_run_rounded, color: blue),
);

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.runs});
  final List<RunEntry> runs;
  @override
  Widget build(BuildContext context) {
    final km = runs.fold<double>(0, (sum, run) => sum + run.distance);
    final minutes = runs.fold<int>(0, (sum, run) => sum + run.minutes);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ภาพรวมการวิ่ง',
          style: TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _statCard(
          Icons.route,
          'ระยะทางทั้งหมด',
          '${km.toStringAsFixed(1)} กม.',
          blue,
        ),
        _statCard(
          Icons.timer_outlined,
          'เวลารวม',
          '$minutes นาที',
          const Color(0xFF06A975),
        ),
        _statCard(
          Icons.flag_outlined,
          'จำนวนกิจกรรม',
          '${runs.length} ครั้ง',
          const Color(0xFFFF9E25),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ความสม่ำเสมอ',
                style: TextStyle(color: navy, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('จ', style: TextStyle(color: muted)),
                  Text('อ', style: TextStyle(color: muted)),
                  Text('พ', style: TextStyle(color: muted)),
                  Text('พฤ', style: TextStyle(color: muted)),
                  Text('ศ', style: TextStyle(color: muted)),
                  Text('ส', style: TextStyle(color: muted)),
                  Text('อา', style: TextStyle(color: muted)),
                ],
              ),
              SizedBox(height: 9),
              LinearProgressIndicator(
                value: .57,
                minHeight: 8,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(label, style: const TextStyle(color: muted)),
            ),
            Text(
              value,
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: paleBlue,
              child: Icon(Icons.person_rounded, size: 42, color: blue),
            ),
            SizedBox(height: 12),
            Text(
              'นักวิ่งมือใหม่',
              style: TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'เริ่มบันทึกการวิ่งของคุณได้เลย',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final item in [
        'ข้อมูลส่วนตัว',
        'เป้าหมายการวิ่ง',
        'การแจ้งเตือน',
        'ตั้งค่า',
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            title: Text(
              item,
              style: const TextStyle(color: navy, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: muted),
          ),
        ),
    ],
  );
}

class AddRunPage extends StatefulWidget {
  const AddRunPage({super.key});
  @override
  State<AddRunPage> createState() => _AddRunPageState();
}

class _AddRunPageState extends State<AddRunPage> {
  final formKey = GlobalKey<FormState>();
  final place = TextEditingController();
  final distance = TextEditingController();
  final minutes = TextEditingController();
  final note = TextEditingController();
  final imagePicker = ImagePicker();
  Uint8List? imageBytes;
  String? imageExtension;
  bool pickingImage = false;
  DateTime date = DateTime.now();
  @override
  void dispose() {
    place.dispose();
    distance.dispose();
    minutes.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> chooseImage() async {
    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image == null) return;
      final suffix = image.name.split('.').last.toLowerCase();
      final supported = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
      if (!supported.contains(suffix)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('รองรับรูป JPG, PNG, WebP หรือ HEIC')),
          );
        }
        return;
      }
      setState(() {
        imageBytes = null;
        pickingImage = true;
      });
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        imageBytes = bytes;
        imageExtension = suffix;
        pickingImage = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => pickingImage = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เลือกรูปไม่สำเร็จ: $error')));
    }
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RunEntry(
        place: place.text.trim(),
        distance: double.parse(distance.text),
        minutes: int.parse(minutes.text),
        date: date,
        note: note.text.trim(),
        imageBytes: imageBytes,
        imageExtension: imageExtension,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'บันทึกการวิ่ง',
        style: TextStyle(color: navy, fontWeight: FontWeight.w800),
      ),
      backgroundColor: const Color(0xFFF7F9FC),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: InkWell(
              onTap: pickingImage ? null : chooseImage,
              borderRadius: BorderRadius.circular(22),
              child: imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pickingImage
                              ? Icons.hourglass_top_rounded
                              : Icons.add_a_photo_outlined,
                          color: blue,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pickingImage
                              ? 'กำลังโหลดรูป...'
                              : 'เลือกรูปจากอัลบั้ม',
                          style: const TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'เพิ่มรูปภาพประกอบการวิ่ง (ไม่บังคับ)',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(imageBytes!, fit: BoxFit.cover),
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit_outlined, color: blue),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          _label('สถานที่วิ่ง'),
          _input(place, 'เช่น สวนลุมพินี', Icons.location_on_outlined),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ระยะทาง (กม.)'),
                    _input(distance, '5.0', Icons.route_rounded, numeric: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('เวลา (นาที)'),
                    _input(
                      minutes,
                      '30',
                      Icons.timer_outlined,
                      numeric: true,
                      integer: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('วันที่วิ่ง'),
          InkWell(
            onTap: chooseDate,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE4E9F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: blue,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(color: navy),
                  ),
                  const Spacer(),
                  const Icon(Icons.expand_more, color: muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('บันทึกเพิ่มเติม'),
          _input(
            note,
            'วันนี้รู้สึกอย่างไรบ้าง?',
            Icons.notes_rounded,
            required: false,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'บันทึกการวิ่ง',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: navy,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool numeric = false,
    bool integer = false,
    bool required = true,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: blue, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE4E9F0)),
      ),
    ),
    validator: (value) {
      if (!required && (value == null || value.isEmpty)) return null;
      if (value == null || value.trim().isEmpty) return 'กรุณากรอกข้อมูล';
      if (numeric) {
        final number = integer ? int.tryParse(value) : double.tryParse(value);
        if (number == null || number <= 0) return 'กรุณากรอกตัวเลขที่มากกว่า 0';
      }
      return null;
    },
  );
}
