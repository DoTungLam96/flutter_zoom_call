import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/flutter_zoom_view.dart' as zoom_view;
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_user.dart';

class ZoomVideoView extends StatelessWidget {
  final ZoomVideoSdkUser? user;
  final String videoAspect;
  final bool fullScreen;
  final BorderRadius? borderRadius;
  final Color backgroundColor;

  const ZoomVideoView({
    super.key,
    required this.user,
    this.videoAspect = VideoAspect.FullFilled,
    this.fullScreen = false,
    this.borderRadius,
    this.backgroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null || user!.userId.isEmpty) {
      return Container(
        color: backgroundColor,
        alignment: Alignment.center,
        child: const Icon(
          Icons.person,
          color: Colors.white54,
          size: 48,
        ),
      );
    }

    final view = zoom_view.View(
      key: Key(user!.userId),
      creationParams: {
        'userId': user!.userId,
        'videoAspect': videoAspect,
        'fullScreen': fullScreen,
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: ColoredBox(
          color: backgroundColor,
          child: view,
        ),
      );
    }

    return ColoredBox(
      color: backgroundColor,
      child: view,
    );
  }
}