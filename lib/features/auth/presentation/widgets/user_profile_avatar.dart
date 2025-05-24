import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/user_data_provider.dart';

class UserProfileAvatar extends ConsumerWidget {
  final String? imageUrl;
  final double radius;


  static const String _defaultManPhoto = 'assets/images/defaultmanphoto.png';
  static const String _defaultWomanPhoto =
      'assets/images/defaultwomenphoto.png';


  const UserProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 25.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final String? gender = userDataAsync.value?.gender;

    final bool hasValidUrl = imageUrl?.isNotEmpty ?? false;

    String selectedDefaultImageAsset;
    if (gender?.toLowerCase() == 'female') {
      selectedDefaultImageAsset = _defaultWomanPhoto;
    } else {
      selectedDefaultImageAsset = _defaultManPhoto;
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: hasValidUrl
          ? NetworkImage(imageUrl!)
          : AssetImage(selectedDefaultImageAsset) as ImageProvider,
      backgroundColor: Colors.grey[800],
    );
  }
}
