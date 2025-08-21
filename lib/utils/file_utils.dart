String getDisplayFileName(String filePath) {
  final String fileName = filePath.split('/').last;
  return fileName.replaceAll(RegExp(r'\.[^.]+$'), '').toUpperCase();
}
