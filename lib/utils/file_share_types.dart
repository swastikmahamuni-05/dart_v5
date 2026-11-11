enum FileShareStatus {
  success,
  unsupported,
  canceled,
  error,
}

class FileShareResult {
  final FileShareStatus status;
  final String? message;
  final String? filePath;

  const FileShareResult({
    required this.status,
    this.message,
    this.filePath,
  });

  bool get isSuccess => status == FileShareStatus.success;
  bool get isUnsupported => status == FileShareStatus.unsupported;

  factory FileShareResult.success([String? message, String? filePath]) => FileShareResult(
        status: FileShareStatus.success,
        message: message ?? 'Report shared successfully',
        filePath: filePath,
      );

  factory FileShareResult.unsupported([String? message]) => FileShareResult(
        status: FileShareStatus.unsupported,
        message: message ??
            'File sharing is not supported by this browser. The report has been prepared and can be downloaded instead.',
      );

  factory FileShareResult.canceled() => const FileShareResult(
        status: FileShareStatus.canceled,
        message: 'Share canceled by user',
      );

  factory FileShareResult.error(String message) => FileShareResult(
        status: FileShareStatus.error,
        message: message,
      );
}
