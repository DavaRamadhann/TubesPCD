import 'dart:io';
// Ubah import di bawah ini menggunakan _new
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class VideoFrameExtractor {
  /// Extracts frames from a video at a specific fps.
  /// Returns a sorted list of file paths to the extracted frames.
  static Future<List<String>?> extractFrames(
    String videoPath, {
    int fps = 30,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final tempDirName = DateTime.now().millisecondsSinceEpoch.toString();
      final targetDir = Directory('${directory.path}/$tempDirName');
      await targetDir.create(recursive: true);

      final outputPathPattern = '${targetDir.path}/frame_%04d.jpg';
      final command = '-y -i "$videoPath" -vf fps=$fps "$outputPathPattern"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final List<FileSystemEntity> files = targetDir.listSync();
        final List<String> framePaths = files
            .where((file) => file.path.endsWith('.jpg'))
            .map((file) => file.path)
            .toList();

        // Ensure chronological order
        framePaths.sort();
        return framePaths;
      } else {
        final logs = await session.getLogs();
        debugPrint("FFmpeg failed. Code: $returnCode, Logs: $logs");
        return null;
      }
    } catch (e) {
      debugPrint("Error extracting frames: $e");
      return null;
    }
  }

  /// Cleans up the directory containing the extracted frames.
  static Future<void> cleanupFrames(List<String> framePaths) async {
    if (framePaths.isEmpty) return;
    try {
      final firstFile = File(framePaths.first);
      final parentDir = firstFile.parent;
      if (await parentDir.exists()) {
        await parentDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint("Error cleaning up frames: $e");
    }
  }

  /// Trims a video and returns the path to the trimmed video file
  static Future<String?> trimVideo(
    String videoPath,
    double startTime,
    double endTime,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final tempDirName = DateTime.now().millisecondsSinceEpoch.toString();
      final targetPath = '${directory.path}/trimmed_$tempDirName.mp4';

      // Use -c copy for fast slicing without re-encoding, if possible
      // Or standard re-encoding if accuracy is more important. For short fitness videos, re-encoding is fine.
      final command =
          '-y -ss $startTime -to $endTime -i "$videoPath" "$targetPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return targetPath;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("Error trimming video: $e");
      return null;
    }
  }
}
