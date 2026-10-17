import 'package:flutter/material.dart';
import '../services/api_service.dart';

Map<String, dynamic> _obj(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
    : <Map<String, dynamic>>[];
String _val(dynamic value, [String fallback = '—']) =>
    value == null || value.toString().trim().isEmpty ? fallback : value.toString();
String _when(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  return '$day/$month/$year';
}
String _err(Object error) => error.toString().replaceFirst('Exception: ', '');
String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
String? _range(String? value, int min, int max) {
  final n = int.tryParse(value ?? '');
  return n == null || n < min || n > max ? 'Enter $min–$max' : null;
}
void _toast(BuildContext context, String text, {bool bad = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    behavior: SnackBarBehavior.floating,
    backgroundColor: bad ? const Color(0xFF9A3030) : const Color(0xFF176B58),
  ));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.user, required this.onLogout});
  final ApiService api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  bool get _staff => ['admin', 'warden'].contains(widget.user['role']);
  List<_Nav> get _nav {
    final result = <_Nav>[
      const _Nav('Dashboard', Icons.grid_view_rounded, 'dashboard'),
      const _Nav('Rooms', Icons.meeting_room_outlined, 'rooms'),
    ];
    if (_staff) result.add(const _Nav('Students', Icons.people_outline, 'students'));
    result.add(const _Nav('Maintenance', Icons.handyman_outlined, 'maintenance'));
    result.add(const _Nav('Notices', Icons.campaign_outlined, 'notices'));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _nav;
    if (_selected >= items.length) _selected = 0;
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final name = _val(widget.user['name'], 'Hostel user');
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFE5F4ED), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.apartment_rounded, color: Color(0xFF176B58)),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HostelHub', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('ROOM MANAGEMENT', style: TextStyle(fontSize: 9, letterSpacing: 1.1)),
          ]),
        ]),
        actions: [
          if (wide) Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text(name))),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: PopupMenuButton<String>(
              onSelected: (value) { if (value == 'logout') widget.onLogout(); },
              itemBuilder: (_) => [
                PopupMenuItem<String>(enabled: false, value: 'profile', child: Text(name)),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Sign out')])),
              ],
              child: CircleAvatar(
                backgroundColor: const Color(0xFF176B58),
                foregroundColor: Colors.white,
                child: Text(name.isEmpty ? 'H' : name[0].toUpperCase()),
              ),
            ),
          ),
        ],
      ),
      body: wide
          ? Row(children: [
              Container(
                width: 215,
                color: Colors.white,
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text('WORKSPACE', style: TextStyle(letterSpacing: 1.5, fontSize: 10, color: Color(0xFF7A8982), fontWeight: FontWeight.w800))),
                  ),
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selected = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(color: i == _selected ? const Color(0xFFE5F4ED) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Icon(items[i].icon, color: i == _selected ? const Color(0xFF176B58) : const Color(0xFF68766F)),
                            const SizedBox(width: 11),
                            Expanded(child: Text(items[i].label, style: TextStyle(fontWeight: i == _selected ? FontWeight.w700 : FontWeight.w500))),
                          ]),
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Padding(padding: EdgeInsets.all(16), child: Text('HRMS • Student project', style: TextStyle(fontSize: 11, color: Color(0xFF7A8982)))),
                ]),
              ),
              const VerticalDivider(width: 1, color: Color(0xFFE8EEEB)),
              Expanded(child: _section(items[_selected].key)),
            ])
          : Column(children: [
              Expanded(child: _section(items[_selected].key)),
              NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: (index) => setState(() => _selected = index),
                destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
              ),
            ]),
    );
  }

  Widget _section(String key) => _SectionView(
    key: ValueKey(key),
    api: widget.api,
    user: widget.user,
    isStaff: _staff,
    section: key,
  );
}

class _Nav {
  const _Nav(this.label, this.icon, this.key);
  final String label;
  final IconData icon;
  final String key;
}

class _SectionView extends StatefulWidget {
  const _SectionView({super.key, required this.api, required this.user, required this.isStaff, required this.section});
  final ApiService api;
  final Map<String, dynamic> user;
  final bool isStaff;
  final String section;

  @override
  State<_SectionView> createState() => _SectionViewState();
}

class _SectionViewState extends State<_SectionView> {
  dynamic _data;
  bool _loading = true;
  String? _error;

  String get _endpoint {
    switch (widget.section) {
      case 'rooms': return '/rooms';
      case 'students': return '/students';
      case 'maintenance': return '/maintenance';
      case 'notices': return '/announcements';
      default: return widget.isStaff ? '/dashboard' : '/auth/me';
    }
  }

  String get _title {
    switch (widget.section) {
      case 'rooms': return 'Room management';
      case 'students': return 'Students';
      case 'maintenance': return 'Maintenance requests';
      case 'notices': return 'Hostel notices';
      default:
        final firstName = _val(widget.user['name'], 'there').split(' ').first;
        return 'Welcome, ' + firstName + '!';
    }
  }

  String get _subtitle {
    switch (widget.section) {
      case 'rooms': return 'Review rooms, occupancy, and monthly hostel fees.';
      case 'students': return 'Review student accounts and room assignments.';
      case 'maintenance': return widget.isStaff ? 'Review resident issues and update their progress.' : 'Report issues and follow their status.';
      case 'notices': return 'Official updates, reminders, and announcements.';
      default: return widget.isStaff ? 'Here is what is happening across your hostel.' : 'Your room, requests, and notices in one place.';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.section == 'dashboard' && !widget.isStaff) {
        final results = await Future.wait([
          widget.api.get('/auth/me'),
          widget.api.get('/maintenance'),
          widget.api.get('/announcements'),
        ]);
        _data = {
          'me': _obj(results[0])['user'],
          'requests': _obj(results[1])['requests'],
          'notices': _obj(results[2])['announcements'],
        };
      } else {
        _data = await widget.api.get(_endpoint);
      }
    } catch (error) {
      _error = _err(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    dynamic result;
    String path;
    if (widget.section == 'rooms') {
      result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _RoomForm());
      path = '/rooms';
    } else if (widget.section == 'students') {
      result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _StudentForm());
      path = '/students';
    } else if (widget.section == 'maintenance') {
      result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _RequestForm());
      path = '/maintenance';
    } else if (widget.section == 'notices') {
      result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _NoticeForm());
      path = '/announcements';
    } else {
      return;
    }
    if (result == null) return;
    try {
      await widget.api.post(path, Map<String, dynamic>.from(result as Map));
      await _load();
      if (mounted) {
        _toast(
          context,
          widget.section == 'students'
              ? 'Student account created. Share the temporary password securely.'
              : 'Saved successfully.',
        );
      }
    } catch (error) {
      if (mounted) _toast(context, _err(error), bad: true);
    }
  }

  Future<void> _delete(String path, String message) async {
    try {
      await widget.api.delete(path);
      await _load();
      if (mounted) _toast(context, message);
    } catch (error) {
      if (mounted) _toast(context, _err(error), bad: true);
    }
  }

  Future<void> _status(Map<String, dynamic> request, String status) async {
    try {
      await widget.api.patch('/maintenance/' + request['_id'].toString(), {'status': status});
      await _load();
      if (mounted) _toast(context, 'Request status updated.');
    } catch (error) {
      if (mounted) _toast(context, _err(error), bad: true);
    }
  }

  Future<void> _allocate(Map<String, dynamic> student) async {
    try {
      final data = _obj(await widget.api.get('/rooms'));
      final rooms = _list(data['rooms']);
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Allocate room: ' + _val(student['name'])),
          children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(context, ''), child: const Text('Remove current allocation')),
            for (final room in rooms)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, room['_id'].toString()),
                child: Text(
                  _val(room['roomNumber']) + ' · ' + _val(room['block']) +
                  ' (' + _val(room['occupiedBeds'], '0') + '/' + _val(room['capacity'], '0') + ')',
                ),
              ),
          ],
        ),
      );
      if (chosen == null) return;
      await widget.api.patch('/students/' + student['_id'].toString() + '/room', {'roomId': chosen.isEmpty ? null : chosen});
      await _load();
      if (mounted) _toast(context, 'Room allocation updated.');
    } catch (error) {
      if (mounted) _toast(context, _err(error), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = (widget.section == 'rooms' && widget.isStaff) ||
        (widget.section == 'students' && widget.isStaff) ||
        (widget.section == 'maintenance' && !widget.isStaff) ||
        (widget.section == 'notices' && widget.isStaff);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_subtitle, style: const TextStyle(color: Color(0xFF68766F), height: 1.4)),
            ])),
            if (canAdd) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.section == 'rooms'
                      ? 'Add room'
                      : widget.section == 'students'
                          ? 'Add student'
                          : widget.section == 'notices'
                              ? 'Publish'
                              : 'New request',
                ),
              ),
            ],
            IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(padding: EdgeInsets.all(42), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF9A3030)))),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ]),
            )
          else
            _content(),
        ],
      ),
    );
  }

  Widget _content() {
    if (widget.section == 'rooms') {
      final rooms = _list(_obj(_data)['rooms']);
      if (rooms.isEmpty) return const _Empty(icon: Icons.meeting_room_outlined, title: 'No rooms yet', subtitle: 'Add rooms to start tracking available beds.');
      return Column(children: [
        for (final room in rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.meeting_room_outlined, size: 26, color: Color(0xFF176B58)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_val(room['roomNumber']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(_val(room['block']) + ' • Floor ' + _val(room['floor']), style: const TextStyle(color: Color(0xFF68766F), fontSize: 12)),
                  ])),
                  if (widget.isStaff)
                    IconButton(tooltip: 'Delete empty room', onPressed: () => _delete('/rooms/' + room['_id'].toString(), 'Room deleted.'), icon: const Icon(Icons.delete_outline)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Pill(text: _val(room['type']), color: const Color(0xFFE3EFFD)),
                  _Pill(text: _val(room['occupiedBeds'], '0') + ' / ' + _val(room['capacity'], '0') + ' beds occupied', color: const Color(0xFFE5F4ED)),
                  _Pill(text: '₹' + _val(room['monthlyFee'], '0') + ' / month', color: const Color(0xFFFFF0D9)),
                ]),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  minHeight: 7,
                  value: (int.tryParse(_val(room['capacity'], '0')) ?? 0) == 0 ? 0 :
                      ((int.tryParse(_val(room['occupiedBeds'], '0')) ?? 0) / (int.tryParse(_val(room['capacity'], '1')) ?? 1)).clamp(0, 1).toDouble(),
                  backgroundColor: const Color(0xFFE8EFEB),
                  borderRadius: BorderRadius.circular(9),
                ),
              ]),
            )),
          ),
      ]);
    }

    if (widget.section == 'students') {
      final students = _list(_obj(_data)['students']);
      if (students.isEmpty) return const _Empty(icon: Icons.people_outline, title: 'No students found', subtitle: 'Students can register from the sign-in page.');
      return Column(children: [
        for (final student in students)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(backgroundColor: const Color(0xFFE5F4ED), foregroundColor: const Color(0xFF176B58), child: Text(_val(student['name'], 'S')[0].toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_val(student['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(_val(student['email']), style: const TextStyle(color: Color(0xFF68766F), fontSize: 12)),
                  ])),
                ]),
                const Divider(height: 24),
                Row(children: [
                  const Icon(Icons.bed_outlined, size: 18, color: Color(0xFF68766F)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(student['room'] is Map ? 'Room ' + _val(_obj(student['room'])['roomNumber']) : 'No room allocated')),
                  OutlinedButton.icon(onPressed: () => _allocate(student), icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Allocate')),
                ]),
              ]),
            )),
          ),
      ]);
    }

    if (widget.section == 'maintenance') {
      final requests = _list(_obj(_data)['requests']);
      if (requests.isEmpty) return const _Empty(icon: Icons.handyman_outlined, title: 'No requests yet', subtitle: 'New maintenance requests will appear here.');
      return Column(children: [
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.handyman_outlined, color: Color(0xFF9A6414)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_val(request['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  _StatusPill(status: _val(request['status'], 'open')),
                ]),
                const SizedBox(height: 8),
                Text(_val(request['description'], ''), style: const TextStyle(height: 1.4)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Pill(text: _val(request['category']), color: const Color(0xFFE3EFFD)),
                  _Pill(text: 'Priority: ' + _val(request['priority'], 'normal'), color: const Color(0xFFFFF0D9)),
                  _Pill(text: _when(request['createdAt']), color: const Color(0xFFE5F4ED)),
                ]),
                if (widget.isStaff)
                  Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<String>(
                      value: ['open', 'in_progress', 'resolved'].contains(request['status']) ? request['status'] as String : 'open',
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                      ],
                      onChanged: (value) { if (value != null) _status(request, value); },
                    ),
                  ),
              ]),
            )),
          ),
      ]);
    }

    if (widget.section == 'notices') {
      final notices = _list(_obj(_data)['announcements']);
      if (notices.isEmpty) return const _Empty(icon: Icons.campaign_outlined, title: 'No notices published', subtitle: 'Important updates will appear here.');
      return Column(children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.campaign_outlined, color: Color(0xFF326AA8), size: 26),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_val(notice['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_val(notice['body'], ''), style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 8),
                  Text(_when(notice['createdAt']) + ' • ' + _val(notice['audience'], 'all'), style: const TextStyle(color: Color(0xFF68766F), fontSize: 11)),
                ])),
                if (widget.isStaff) IconButton(tooltip: 'Delete notice', onPressed: () => _delete('/announcements/' + notice['_id'].toString(), 'Notice deleted.'), icon: const Icon(Icons.delete_outline)),
              ]),
            )),
          ),
      ]);
    }

    if (widget.isStaff) {
      final response = _obj(_data);
      final stats = _obj(response['stats']);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Stat(title: 'Students', value: _val(stats['totalStudents'], '0'), icon: Icons.people_outline, width: _cardWidth(context)),
          _Stat(title: 'Rooms', value: _val(stats['totalRooms'], '0'), icon: Icons.meeting_room_outlined, width: _cardWidth(context)),
          _Stat(title: 'Available beds', value: _val(stats['availableBeds'], '0'), icon: Icons.bed_outlined, width: _cardWidth(context)),
          _Stat(title: 'Open requests', value: _val(stats['openMaintenance'], '0'), icon: Icons.handyman_outlined, width: _cardWidth(context)),
        ]),
        const SizedBox(height: 18),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Room occupancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text(_val(stats['occupancyPercent'], '0') + '%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
            ]),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 10,
              value: ((num.tryParse(_val(stats['occupancyPercent'], '0')) ?? 0) / 100).clamp(0, 1).toDouble(),
              backgroundColor: const Color(0xFFE8EFEB),
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 9),
            Text(_val(stats['occupiedBeds'], '0') + ' occupied out of ' + _val(stats['totalBeds'], '0') + ' beds', style: const TextStyle(color: Color(0xFF68766F))),
          ]),
        )),
        const SizedBox(height: 18),
        const Text('Recent maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final item in _list(response['recentRequests']).take(4))
          Card(child: ListTile(leading: const Icon(Icons.handyman_outlined), title: Text(_val(item['title'])), subtitle: Text(_when(item['createdAt']) + ' • ' + _val(item['status'], 'open')))),
      ]);
    }

    final data = _obj(_data);
    final userData = _obj(data['me'] ?? widget.user);
    final room = userData['room'] is Map ? _obj(userData['room']) : null;
    final requests = _list(data['requests']);
    final notices = _list(data['notices']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (room == null)
            const Text('No room has been allocated to your account yet. Contact the hostel warden.', style: TextStyle(color: Color(0xFF68766F), height: 1.4))
          else ...[
            Text(_val(room['roomNumber']), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(_val(room['block']) + ' • Floor ' + _val(room['floor']), style: const TextStyle(color: Color(0xFF68766F))),
            const SizedBox(height: 12),
            _Pill(text: _val(room['occupiedBeds'], '0') + ' / ' + _val(room['capacity'], '0') + ' beds occupied', color: const Color(0xFFE5F4ED)),
          ],
        ]),
      )),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Stat(title: 'My requests', value: requests.length.toString(), icon: Icons.handyman_outlined, width: _cardWidth(context)),
        _Stat(title: 'Notices', value: notices.length.toString(), icon: Icons.campaign_outlined, width: _cardWidth(context)),
      ]),
      const SizedBox(height: 18),
      const Text('Latest notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (notices.isEmpty)
        const _Empty(icon: Icons.campaign_outlined, title: 'No notices', subtitle: 'Check here for hostel updates.')
      else
        Card(child: ListTile(leading: const Icon(Icons.campaign_outlined), title: Text(_val(notices.first['title'])), subtitle: Text(_val(notices.first['body'], '')))),
    ]);
  }
}

double _cardWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 240;
  if (width >= 1000) return 215;
  if (width >= 650) return (width - 90) / 2;
  return width - 54;
}

class _RoomForm extends StatefulWidget {
  const _RoomForm();
  @override
  State<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends State<_RoomForm> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _block = TextEditingController(text: 'A Block');
  final _floor = TextEditingController(text: '1');
  final _capacity = TextEditingController(text: '2');
  final _fee = TextEditingController(text: '3000');
  String _type = 'Double';

  @override
  void dispose() {
    _number.dispose(); _block.dispose(); _floor.dispose(); _capacity.dispose(); _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add room'),
    content: SizedBox(width: 410, child: Form(
      key: _form,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Room number'), validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _block, decoration: const InputDecoration(labelText: 'Block'), validator: _required),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _floor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Floor'), validator: (v) => _range(v, 0, 100))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity'), validator: (v) => _range(v, 1, 20))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Room type'),
          items: const [
            DropdownMenuItem(value: 'Single', child: Text('Single')),
            DropdownMenuItem(value: 'Double', child: Text('Double')),
            DropdownMenuItem(value: 'Triple', child: Text('Triple')),
            DropdownMenuItem(value: 'Dormitory', child: Text('Dormitory')),
          ],
          onChanged: (v) => setState(() => _type = v ?? 'Double'),
        ),
        const SizedBox(height: 10),
        TextFormField(controller: _fee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly fee (₹)'), validator: (v) {
          final fee = num.tryParse(v ?? '');
          return fee == null || fee < 0 ? 'Enter a valid fee.' : null;
        }),
      ])),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'roomNumber': _number.text.trim(), 'block': _block.text.trim(),
          'floor': int.parse(_floor.text), 'capacity': int.parse(_capacity.text),
          'type': _type, 'monthlyFee': num.parse(_fee.text),
        });
      }, child: const Text('Create room')),
    ],
  );
}

class _RequestForm extends StatefulWidget {
  const _RequestForm();
  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Other';
  String _priority = 'normal';

  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New maintenance request'),
    content: SizedBox(width: 410, child: Form(
      key: _form,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Short title'), validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Describe the issue'), validator: _required),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
            DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
            DropdownMenuItem(value: 'Cleanliness', child: Text('Cleanliness')),
            DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'Other'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'normal'),
        ),
      ])),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'title': _title.text.trim(), 'description': _description.text.trim(),
          'category': _category, 'priority': _priority,
        });
      }, child: const Text('Submit')),
    ],
  );
}

class _StudentForm extends StatefulWidget {
  const _StudentForm();

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create student account'),
    content: SizedBox(width: 410, child: Form(
      key: _form,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full name'),
          textCapitalization: TextCapitalization.words,
          validator: _required,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
          validator: (value) => value != null && value.contains('@') && value.contains('.')
              ? null
              : 'Enter a valid email address.',
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone (optional)'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Temporary password (8+ characters)'),
          validator: (value) => value != null && value.length >= 8
              ? null
              : 'Use at least 8 characters.',
        ),
      ])),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
        });
      }, child: const Text('Create account')),
    ],
  );
}

class _NoticeForm extends StatefulWidget {
  const _NoticeForm();
  @override
  State<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends State<_NoticeForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';

  @override
  void dispose() { _title.dispose(); _body.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Publish notice'),
    content: SizedBox(width: 410, child: Form(
      key: _form,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _body, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Message'), validator: _required),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _audience,
          decoration: const InputDecoration(labelText: 'Visible to'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Everyone')),
            DropdownMenuItem(value: 'students', child: Text('Students')),
            DropdownMenuItem(value: 'staff', child: Text('Staff')),
          ],
          onChanged: (v) => setState(() => _audience = v ?? 'all'),
        ),
      ])),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'title': _title.text.trim(), 'body': _body.text.trim(), 'audience': _audience,
        });
      }, child: const Text('Publish')),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value, required this.icon, required this.width});
  final String title;
  final String value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF68766F), fontWeight: FontWeight.w600))),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE5F4ED), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF176B58), size: 20)),
      ]),
      const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
    ]),
  )));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final resolved = status == 'resolved';
    final progress = status == 'in_progress';
    final label = resolved ? 'Resolved' : progress ? 'In progress' : 'Open';
    final foreground = resolved ? const Color(0xFF176B58) : progress ? const Color(0xFF94630C) : const Color(0xFF9A3030);
    final background = resolved ? const Color(0xFFE5F4ED) : progress ? const Color(0xFFFFF0D9) : const Color(0xFFFCE8E6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(36),
    child: Column(children: [
      Icon(icon, size: 38, color: const Color(0xFF7B8C83)),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF68766F), height: 1.4)),
    ]),
  ));
}
