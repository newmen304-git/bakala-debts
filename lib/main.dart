import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ═══════════════════════════════════════════
// نقطة البداية
// ═══════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  runApp(const BakalaApp());
}

// ═══════════════════════════════════════════
// التطبيق الرئيسي
// ═══════════════════════════════════════════
class BakalaApp extends StatelessWidget {
  const BakalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر ديون البقالة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

// ═══════════════════════════════════════════
// قاعدة البيانات
// ═══════════════════════════════════════════
class DB {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'bakala_debts.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            credit_limit REAL DEFAULT 1000,
            current_balance REAL DEFAULT 0,
            reliability_score INTEGER DEFAULT 50,
            status TEXT DEFAULT 'active',
            payment_type TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            balance_after REAL NOT NULL,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.insert('settings', {'key': 'next_customer_id', 'value': '101'});
        await db.insert('customers', {
          'id': 101,
          'name': 'أحمد محمد',
          'phone': '770111111',
          'credit_limit': 5000,
          'current_balance': 2000,
          'reliability_score': 95,
          'status': 'active',
          'payment_type': 'يومي',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('customers', {
          'id': 102,
          'name': 'سالم علي',
          'phone': '770222222',
          'credit_limit': 5000,
          'current_balance': 4500,
          'reliability_score': 65,
          'status': 'warning',
          'payment_type': 'أسبوعي',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('customers', {
          'id': 103,
          'name': 'فهد سعيد',
          'phone': '770333333',
          'credit_limit': 5000,
          'current_balance': 5000,
          'reliability_score': 25,
          'status': 'blocked',
          'payment_type': 'يومي',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.update('settings', {'value': '104'},
            where: 'key = ?', whereArgs: ['next_customer_id']);
      },
    );
    return _db!;
  }
}

// ═══════════════════════════════════════════
// النموذج
// ═══════════════════════════════════════════
class Customer {
  final int id;
  final String name;
  final String? phone;
  final double creditLimit;
  final double currentBalance;
  final int reliabilityScore;
  final String status;
  final String? paymentType;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.creditLimit,
    required this.currentBalance,
    required this.reliabilityScore,
    required this.status,
    this.paymentType,
  });

  double get remaining => creditLimit - currentBalance;

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        creditLimit: (m['credit_limit'] as num).toDouble(),
        currentBalance: (m['current_balance'] as num).toDouble(),
        reliabilityScore: m['reliability_score'] as int,
        status: m['status'] as String,
        paymentType: m['payment_type'] as String?,
      );
}

// ═══════════════════════════════════════════
// الشاشة الرئيسية
// ═══════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> _customers = [];
  bool _loading = true;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DB.instance;
    final rows = await db.query('customers', orderBy: 'current_balance DESC');
    final list = rows.map((e) => Customer.fromMap(e)).toList();
    setState(() {
      _customers = list;
      _total = list.fold(0, (s, c) => s + c.currentBalance);
      _loading = false;
    });
  }

  Color _color(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'warning':
        return const Color(0xFFFFC107);
      case 'blocked':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'active':
        return 'ملتزم';
      case 'warning':
        return 'متوسط';
      case 'blocked':
        return 'مماطل';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏪 دفتر ديون البقالة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  // الإجمالي
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('💰 إجمالي الديون',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(
                            '${_total.toStringAsFixed(0)} ريال',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('عدد العملاء: ${_customers.length}',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  // قائمة العملاء
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('👥 العملاء',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                  if (_customers.isEmpty)
                    const Card(
                      margin: EdgeInsets.all(12),
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('لا يوجد عملاء')),
                      ),
                    )
                  else
                    ..._customers.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      final color = _color(c.status);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          onTap: () => _openCustomer(c),
                          leading: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${c.id}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusText(c.status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${c.currentBalance.toStringAsFixed(0)} / ${c.creditLimit.toStringAsFixed(0)}  •  ${c.reliabilityScore}%',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey[400]),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.add),
        label: const Text('عميل جديد'),
      ),
    );
  }

  void _openCustomer(Customer c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerScreen(customer: c, onUpdate: _load),
      ),
    );
  }

  void _addCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(onSaved: _load),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// شاشة العميل
// ═══════════════════════════════════════════
class CustomerScreen extends StatefulWidget {
  final Customer customer;
  final VoidCallback onUpdate;

  const CustomerScreen({
    super.key,
    required this.customer,
    required this.onUpdate,
  });

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Customer _c;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _c = widget.customer;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DB.instance;
    final rows = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [_c.id],
      orderBy: 'id DESC',
    );
    final fresh = await db.query('customers',
        where: 'id = ?', whereArgs: [_c.id], limit: 1);
    setState(() {
      _transactions = rows;
      if (fresh.isNotEmpty) _c = Customer.fromMap(fresh.first);
      _loading = false;
    });
  }

  Future<void> _addDebt() async {
    final amount = await _askAmount('إضافة دين', 'المبلغ');
    if (amount == null || amount <= 0) return;
    final newBalance = _c.currentBalance + amount;
    if (newBalance > _c.creditLimit) {
      _showError('تجاوز السقف! المتبقي: ${_c.remaining.toStringAsFixed(0)}');
      return;
    }
    await _saveTransaction('debt', amount, newBalance);
  }

  Future<void> _addPayment() async {
    final amount = await _askAmount('تسجيل سداد', 'المبلغ المسدد');
    if (amount == null || amount <= 0) return;
    if (amount > _c.currentBalance) {
      _showError('المبلغ أكبر من الرصيد');
      return;
    }
    final newBalance = _c.currentBalance - amount;
    await _saveTransaction('payment', amount, newBalance);
    if (newBalance == 0 && mounted) {
      _showSuccess('🎉 تم سداد الدين بالكامل!');
    }
  }

  Future<void> _saveTransaction(String type, double amount, double newBalance) async {
    final db = await DB.instance;
    final now = DateTime.now();
    await db.insert('transactions', {
      'customer_id': _c.id,
      'type': type,
      'amount': amount,
      'balance_after': newBalance,
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    });

    String status = _c.status;
    if (newBalance >= _c.creditLimit) {
      status = 'blocked';
    } else if (newBalance >= _c.creditLimit * 0.8) {
      status = 'warning';
    } else if (newBalance == 0) {
      status = 'active';
    }

    await db.update(
      'customers',
      {
        'current_balance': newBalance,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [_c.id],
    );

    widget.onUpdate();
    await _load();
  }

  Future<double?> _askAmount(String title, String label) async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            suffixText: 'ريال',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(ctx, v);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('👤 ${_c.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // معلومات العميل
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_c.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('رقم: ${_c.id}',
                            style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoCol('الرصيد',
                                _c.currentBalance.toStringAsFixed(0)),
                            _infoCol('السقف',
                                _c.creditLimit.toStringAsFixed(0)),
                            _infoCol('المتبقي',
                                _c.remaining.toStringAsFixed(0)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_c.currentBalance / _c.creditLimit)
                              .clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                ),

                // الأزرار
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _c.currentBalance >= _c.creditLimit
                              ? null
                              : _addDebt,
                          icon: const Icon(Icons.add),
                          label: const Text('دين'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _c.currentBalance > 0
                              ? _addPayment
                              : null,
                          icon: const Icon(Icons.payments),
                          label: const Text('سداد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03A9F4),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('📜 الحركات',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                if (_transactions.isEmpty)
                  const Card(
                    margin: EdgeInsets.all(12),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('لا توجد حركات')),
                    ),
                  )
                else
                  ..._transactions.map((t) {
                    final isDebt = t['type'] == 'debt';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          isDebt ? Icons.add_circle : Icons.check_circle,
                          color: isDebt
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF03A9F4),
                        ),
                        title: Text(isDebt ? 'دين' : 'سداد'),
                        subtitle: Text('${t['date']} - ${t['time']}'),
                        trailing: Text(
                          '${isDebt ? "+" : "-"}${(t['amount'] as num).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDebt
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF03A9F4),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// إضافة عميل جديد
// ═══════════════════════════════════════════
class AddCustomerScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const AddCustomerScreen({super.key, required this.onSaved});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _limitController = TextEditingController(text: '1000');
  final _openingController = TextEditingController(text: '0');
  bool _saving = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم مطلوب')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = await DB.instance;
    final settings = await db.query('settings',
        where: 'key = ?', whereArgs: ['next_customer_id']);
    final nextId = int.parse(settings.first['value'] as String);
    final opening = double.tryParse(_openingController.text) ?? 0;

    await db.insert('customers', {
      'id': nextId,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'credit_limit': double.tryParse(_limitController.text) ?? 1000,
      'current_balance': opening,
      'reliability_score': 50,
      'status': opening == 0 ? 'active' : 'warning',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (opening > 0) {
      final now = DateTime.now();
      await db.insert('transactions', {
        'customer_id': nextId,
        'type': 'opening',
        'amount': opening,
        'balance_after': opening,
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'note': 'رصيد افتتاحي',
      });
    }

    await db.update('settings', {'value': (nextId + 1).toString()},
        where: 'key = ?', whereArgs: ['next_customer_id']);

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('➕ إضافة عميل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'الاسم *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'الجوال (اختياري)',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'السقف',
              prefixIcon: Icon(Icons.money),
              suffixText: 'ريال',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الرصيد الافتتاحي (من الدفتر)',
              prefixIcon: Icon(Icons.book),
              suffixText: 'ريال',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(55),
            ),
          ),
        ],
      ),
    );
  }
}
