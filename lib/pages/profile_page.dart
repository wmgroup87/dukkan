import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'orders_page.dart';
import 'seller_dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'settings_page.dart';
import '../services/strings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUpdating = false;

  Future<void> _openMaps(LatLng ll) async {
    try {
      final Uri uri = Platform.isIOS
          ? Uri.parse('http://maps.apple.com/?q=${ll.latitude},${ll.longitude}')
          : Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': '${ll.latitude},${ll.longitude}',
            });
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      final String fallback = Platform.isIOS
          ? 'http://maps.apple.com/?q=${ll.latitude},${ll.longitude}'
          : 'https://www.google.com/maps/search/?api=1&query=${ll.latitude},${ll.longitude}';
      await Clipboard.setData(ClipboardData(text: fallback));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ رابط الموقع؛ الصقه في المتصفح')),
        );
      }
    }
  }

  Future<void> _editProfile(
    BuildContext context, {
    required String currentName,
    required String currentBusinessBio,
    required String currentGender,
    required String currentCountry,
    DateTime? currentBirthDate,
    LatLng? currentLocation,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final bioController = TextEditingController(text: currentBusinessBio);
    DateTime? birthDate = currentBirthDate;
    String gender = currentGender;
    String country = currentCountry;
    LatLng? location = currentLocation;
    final mapController = MapController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInner) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تعديل الملف الشخصي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'نبذة عن نشاطك',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final initial =
                            birthDate ??
                            DateTime(now.year - 18, now.month, now.day);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(1900, 1, 1),
                          lastDate: now,
                        );
                        if (picked != null) setInner(() => birthDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: Strings.t('birth_date'),
                        ),
                        child: Text(
                          birthDate != null
                              ? '${birthDate!.year}-${birthDate!.month}-${birthDate!.day}'
                              : Strings.t('pick_date'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender.isEmpty ? null : gender,
                      items: [
                        DropdownMenuItem(
                          value: 'ذكر',
                          child: Text(Strings.gender('ذكر')),
                        ),
                        DropdownMenuItem(
                          value: 'أنثى',
                          child: Text(Strings.gender('أنثى')),
                        ),
                      ],
                      decoration: InputDecoration(labelText: Strings.t('gender')),
                      onChanged: (v) => setInner(() => gender = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: country.isEmpty ? null : country,
                      items: [
                        DropdownMenuItem(
                          value: 'السعودية',
                          child: Text(Strings.country('السعودية')),
                        ),
                        DropdownMenuItem(
                          value: 'الإمارات',
                          child: Text(Strings.country('الإمارات')),
                        ),
                        DropdownMenuItem(
                          value: 'قطر',
                          child: Text(Strings.country('قطر')),
                        ),
                        DropdownMenuItem(
                          value: 'الكويت',
                          child: Text(Strings.country('الكويت')),
                        ),
                        DropdownMenuItem(
                          value: 'البحرين',
                          child: Text(Strings.country('البحرين')),
                        ),
                        DropdownMenuItem(
                          value: 'عمان',
                          child: Text(Strings.country('عمان')),
                        ),
                        DropdownMenuItem(
                          value: 'اليمن',
                          child: Text(Strings.country('اليمن')),
                        ),
                        DropdownMenuItem(
                          value: 'مصر',
                          child: Text(Strings.country('مصر')),
                        ),
                        DropdownMenuItem(
                          value: 'الأردن',
                          child: Text(Strings.country('الأردن')),
                        ),
                        DropdownMenuItem(
                          value: 'سوريا',
                          child: Text(Strings.country('سوريا')),
                        ),
                        DropdownMenuItem(
                          value: 'لبنان',
                          child: Text(Strings.country('لبنان')),
                        ),
                        DropdownMenuItem(
                          value: 'العراق',
                          child: Text(Strings.country('العراق')),
                        ),
                        DropdownMenuItem(
                          value: 'المغرب',
                          child: Text(Strings.country('المغرب')),
                        ),
                        DropdownMenuItem(
                          value: 'الجزائر',
                          child: Text(Strings.country('الجزائر')),
                        ),
                        DropdownMenuItem(
                          value: 'تونس',
                          child: Text(Strings.country('تونس')),
                        ),
                        DropdownMenuItem(
                          value: 'السودان',
                          child: Text(Strings.country('السودان')),
                        ),
                      ],
                      decoration: InputDecoration(labelText: Strings.t('country')),
                      onChanged: (v) => setInner(() => country = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: Card(
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter:
                                    location ?? const LatLng(24.7136, 46.6753),
                                initialZoom: 10,
                                onTap: (tapPos, latLng) =>
                                    setInner(() => location = latLng),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                if (location != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: location!,
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
                              bottom: 8,
                              right: 8,
                              child: FloatingActionButton.small(
                                onPressed: () async {
                                  LocationPermission p =
                                      await Geolocator.checkPermission();
                                  if (p == LocationPermission.denied) {
                                    p = await Geolocator.requestPermission();
                                  }
                                  final pos =
                                      await Geolocator.getCurrentPosition(
                                        desiredAccuracy: LocationAccuracy.high,
                                      );
                                  final ll = LatLng(
                                    pos.latitude,
                                    pos.longitude,
                                  );
                                  setInner(() => location = ll);
                                  mapController.move(ll, 15);
                                },
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blueAccent,
                                child: const Icon(Icons.my_location),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'يجب تسجيل الدخول لتعديل الملف الشخصي',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _isUpdating = true);
                        try {
                          final Map<String, dynamic> data = {
                            'displayName': nameController.text.trim(),
                            'businessBio': bioController.text.trim(),
                            'gender': gender,
                            'country': country,
                          };
                          if (birthDate != null) {
                            data['birthDate'] = Timestamp.fromDate(birthDate!);
                          }
                          if (location != null) {
                            data['location'] = {
                              'lat': location!.latitude,
                              'lng': location!.longitude,
                            };
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set(data, SetOptions(merge: true));
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تعذر حفظ البيانات: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                      child: const Text('حفظ'),
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

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لتعديل الصورة')),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() {
        _isUpdating = true;
      });

      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('avatar.jpg');

      try {
        String contentTypeFromPath(String path) {
          final ext = path.split('.').last.toLowerCase();
          if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
          if (ext == 'png') return 'image/png';
          if (ext == 'gif') return 'image/gif';
          return 'application/octet-stream';
        }

        // Log file info to help debugging (size, path)
        // ignore: avoid_print
        print(
          'Uploading file via putFile: path=${file.path} size=${file.lengthSync()}',
        );

        final metadata = SettableMetadata(
          contentType: contentTypeFromPath(file.path),
        );

        try {
          final UploadTask uploadTask = ref.putFile(file, metadata);
          final TaskSnapshot snapshot = await uploadTask;
          final photoUrl = await snapshot.ref.getDownloadURL();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'photoUrl': photoUrl}, SetOptions(merge: true));
          return;
        } on FirebaseException catch (e, s) {
          // log the failure of putFile and attempt a putData fallback
          // ignore: avoid_print
          print('putFile failed: code=${e.code} message=${e.message}');
          // ignore: avoid_print
          print(s);

          // Try fallback: read bytes and upload with putData
          try {
            final bytes = await file.readAsBytes();
            // ignore: avoid_print
            print('Attempting fallback putData: bytes=${bytes.length}');
            final UploadTask fallback = ref.putData(bytes, metadata);
            final TaskSnapshot snap2 = await fallback;
            final photoUrl = await snap2.ref.getDownloadURL();
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'photoUrl': photoUrl}, SetOptions(merge: true));
            return;
          } on FirebaseException catch (e2, s2) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Storage error (${e2.code}): ${e2.message}'),
                ),
              );
            }
            // ignore: avoid_print
            print(
              'Fallback putData failed: code=${e2.code} message=${e2.message}',
            );
            // ignore: avoid_print
            print(s2);
            return;
          }
        }
      } catch (e, s) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تعذر تحديث الصورة: $e')));
        }
        // ignore: avoid_print
        print('Unexpected error during upload: $e');
        // ignore: avoid_print
        print(s);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الصورة: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Stack(
          children: [
            Center(child: Text(Strings.t('login_to_view_profile'))),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FloatingTopBar(title: 'البروفايل'),
            ),
          ],
        ),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userDocStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('حدث خطأ في تحميل البيانات: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() ?? <String, dynamic>{};
              final displayName =
                  (data['displayName'] as String?) ??
                  user.displayName ??
                  user.phoneNumber ??
                  user.email ??
                  'مستخدم';
              final businessBio =
                  (data['businessBio'] as String?) ??
                  (data['bio'] as String?) ??
                  '';
              final gender = (data['gender'] as String?) ?? '';
              final country = (data['country'] as String?) ?? '';
              DateTime? birthDate;
              final ts = data['birthDate'];
              if (ts is Timestamp) birthDate = ts.toDate();
              LatLng? location;
              final loc = data['location'];
              if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
                location = LatLng(
                  (loc['lat'] as num).toDouble(),
                  (loc['lng'] as num).toDouble(),
                );
              }
              final photoUrl = (data['photoUrl'] as String?) ?? user.photoURL;
              final postsCount = (data['postsCount'] as num?)?.toInt() ?? 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  displayName.characters.first,
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _isUpdating ? null : _changePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      businessBio.isEmpty
                          ? 'أضف نبذة عنك من زر تعديل الملف الشخصي'
                          : businessBio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 16,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                gender.isNotEmpty ? gender : 'غير محدد',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.public,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                country.isNotEmpty ? country : 'غير محدد',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cake_outlined,
                                size: 16,
                                color: Colors.pinkAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                birthDate != null
                                    ? '${birthDate.year}-${birthDate.month}-${birthDate.day}'
                                    : 'غير محدد',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          if (location != null)
                            TextButton.icon(
                              onPressed: () => _openMaps(location!),
                              icon: const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              label: Text(
                                '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 0),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('followersCount')
                          .snapshots(),
                      builder: (context, followersSnap) {
                        final followersCount = followersSnap.hasData
                            ? followersSnap.data!.docs.length
                            : (data['followersCount'] as num?)?.toInt() ?? 0;

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('followingCount')
                              .snapshots(),
                          builder: (context, followingSnap) {
                            final followingCount = followingSnap.hasData
                                ? followingSnap.data!.docs.length
                                : (data['followingCount'] as num?)?.toInt() ??
                                      0;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ProfileStat(
                                  label: Strings.t('posts'),
                                  value: postsCount,
                                ),
                                _ProfileStat(
                                  label: Strings.t('followers'),
                                  value: followersCount,
                                ),
                                _ProfileStat(
                                  label: Strings.t('following'),
                                  value: followingCount,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OrdersPage(),
                              ),
                            );
                          },
                          child: Text(Strings.t('my_orders')),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SellerDashboardPage(),
                              ),
                            );
                          },
                          child: Text(Strings.t('seller_dashboard')),
                        ),
                        if ((data['isAdmin'] as bool?) == true)
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AdminDashboardPage(),
                                ),
                              );
                            },
                            child: Text(Strings.t('admin_dashboard')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _editProfile(
                              context,
                              currentName: displayName,
                              currentBusinessBio: businessBio,
                              currentGender: gender,
                              currentCountry: country,
                              currentBirthDate: birthDate,
                              currentLocation: location,
                            ),
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined),
                      label: Text(Strings.t('edit_profile')),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isUpdating
                          ? null
                          : () async {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            },
                      icon: const Icon(Icons.logout),
                      label: Text(Strings.t('logout')),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(
              showNotifications: false,
              showProfile: false,
              showSettings: true,
              onSettingsPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final int value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
