import 'package:flutter/material.dart';
import '../services/upload_manager.dart';

class UploadStatusBanner extends StatelessWidget {
  const UploadStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UploadStatus>(
      valueListenable: UploadManager.instance.status,
      builder: (context, status, _) {
        if (status == UploadStatus.idle) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ValueListenableBuilder<double?>(
                valueListenable: UploadManager.instance.progress,
                builder: (context, progress, _) {
                  final pct = (progress ?? 0.0).clamp(0.0, 1.0);
                  if (status == UploadStatus.uploading) {
                    return Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.lightBlueAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }
                  if (status == UploadStatus.success) {
                    return const Center(
                      child: Text(
                        'تم رفع المنتج',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return const Center(
                    child: Text(
                      'فشل رفع المنتج',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}