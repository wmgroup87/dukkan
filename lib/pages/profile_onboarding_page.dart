import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:dukkan/widgets/floating_top_bar.dart';

class ProfileOnboardingPage extends StatefulWidget {
  const ProfileOnboardingPage({super.key});

  @override
  State<ProfileOnboardingPage> createState() => _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends State<ProfileOnboardingPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  DateTime? _birthDate;
  String _gender = '';
  String _country = '';
  LatLng? _location;
  bool _saving = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      _name.text = u.displayName ?? '';
    }
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _name.text = (data['displayName'] as String?) ?? _name.text;
        _bio.text = (data['businessBio'] as String?) ?? '';
        final ts = data['birthDate'];
        if (ts is Timestamp) _birthDate = ts.toDate();
        _gender = (data['gender'] as String?) ?? '';
        _country = (data['country'] as String?) ?? '';
        final loc = data['location'];
        if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
          _location = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _saving = true);
    try {
      final data = {
        'displayName': _name.text.trim(),
        'businessBio': _bio.text.trim(),
        'gender': _gender,
        'country': _country,
        'profileCompleted': true,
      };
      if (_birthDate != null) {
        data['birthDate'] = Timestamp.fromDate(_birthDate!);
      }
      if (_location != null) {
        data['location'] = {
          'lat': _location!.latitude,
          'lng': _location!.longitude,
        };
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .set(data, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ المعلومات: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _locateMe() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع')),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم رفض إذن الموقع')));
        }
        await openAppSettings();
        return;
      }
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تعذر الحصول على الموقع، تحقق من تفعيل GPS'),
              ),
            );
          }
          return;
        }
        pos = last;
      }
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _location = latLng);
        _mapController.move(latLng, 15);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحصول على الموقع: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إكمال معلومات الحساب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: Colors.black54),
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: 'الاسم',
                      labelStyle: TextStyle(color: Colors.black87),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickBirthDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ الميلاد',
                        labelStyle: TextStyle(color: Colors.black87),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _birthDate != null
                            ? '${_birthDate!.year}-${_birthDate!.month}-${_birthDate!.day}'
                            : 'اختر التاريخ',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    style: TextStyle(color: Colors.black54),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(20),

                    value: _gender.isEmpty ? null : _gender,
                    items: const [
                      DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                      DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'الجنس',
                      labelStyle: TextStyle(color: Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onChanged: (v) => setState(() => _gender = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    style: TextStyle(color: Colors.black54),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    value: _country.isEmpty ? null : _country,
                    items: const [
                      DropdownMenuItem(
                        value: 'السعودية',
                        child: Text('السعودية'),
                      ),
                      DropdownMenuItem(
                        value: 'الإمارات',
                        child: Text('الإمارات'),
                      ),
                      DropdownMenuItem(value: 'قطر', child: Text('قطر')),
                      DropdownMenuItem(value: 'الكويت', child: Text('الكويت')),
                      DropdownMenuItem(
                        value: 'البحرين',
                        child: Text('البحرين'),
                      ),
                      DropdownMenuItem(value: 'عمان', child: Text('عمان')),
                      DropdownMenuItem(value: 'اليمن', child: Text('اليمن')),
                      DropdownMenuItem(value: 'مصر', child: Text('مصر')),
                      DropdownMenuItem(value: 'الأردن', child: Text('الأردن')),
                      DropdownMenuItem(value: 'سوريا', child: Text('سوريا')),
                      DropdownMenuItem(value: 'لبنان', child: Text('لبنان')),
                      DropdownMenuItem(value: 'العراق', child: Text('العراق')),
                      DropdownMenuItem(value: 'المغرب', child: Text('المغرب')),
                      DropdownMenuItem(
                        value: 'الجزائر',
                        child: Text('الجزائر'),
                      ),
                      DropdownMenuItem(value: 'تونس', child: Text('تونس')),
                      DropdownMenuItem(
                        value: 'السودان',
                        child: Text('السودان'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'البلد',
                      labelStyle: TextStyle(color: Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onChanged: (v) => setState(() => _country = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: TextStyle(color: Colors.black54),

                    controller: _bio,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'نبذة عن نشاطك',
                      labelStyle: TextStyle(color: Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: Card(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter:
                                  _location ?? const LatLng(24.7136, 46.6753),
                              initialZoom: 10,
                              onTap: (tapPos, latLng) =>
                                  setState(() => _location = latLng),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              ),
                              if (_location != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _location!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.redAccent,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: FloatingActionButton.small(
                              onPressed: _locateMe,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              child: const Icon(Icons.my_location),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(showNotifications: false, showProfile: false),
          ),
        ],
      ),
    );
  }
}
