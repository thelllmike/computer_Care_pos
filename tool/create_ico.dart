import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Creates a .ico file from multiple PNG images
void main() async {
  final basePath = Directory.current.path;

  // PNG files in order: 16, 32, 48, 64
  final pngFiles = [
    '$basePath/assets/logo-16.png',
    '$basePath/assets/logo-32.png',
    '$basePath/assets/logo-48.png',
    '$basePath/assets/logo-64.png',
  ];

  // Also check for larger sizes
  final logo256 = File('$basePath/assets/logo-256.png');
  final logo128 = File('$basePath/assets/logo-128.png');
  final logoMain = File('$basePath/assets/logo.png');

  if (await logo256.exists()) pngFiles.add(logo256.path);
  if (await logo128.exists()) pngFiles.add(logo128.path);

  // Load all PNG images
  final pngDataList = <Uint8List>[];
  final images = <img.Image>[];

  for (final path in pngFiles) {
    final file = File(path);
    if (!await file.exists()) {
      print('WARNING: $path not found, skipping');
      continue;
    }
    final bytes = await file.readAsBytes();
    final decoded = img.decodePng(bytes);
    if (decoded != null) {
      pngDataList.add(bytes);
      images.add(decoded);
      print('Added: ${decoded.width}x${decoded.height} from $path');
    }
  }

  // If we have logo.png and no 256, resize it to fill gaps
  if (!await logo256.exists() && await logoMain.exists()) {
    final mainBytes = await logoMain.readAsBytes();
    final mainImg = img.decodePng(mainBytes);
    if (mainImg != null) {
      for (final size in [128, 256]) {
        if (!images.any((i) => i.width == size)) {
          final resized = img.copyResize(mainImg, width: size, height: size, interpolation: img.Interpolation.linear);
          final resizedPng = img.encodePng(resized);
          pngDataList.add(Uint8List.fromList(resizedPng));
          images.add(resized);
          print('Added: ${size}x$size (resized from logo.png)');
        }
      }
    }
  }

  if (images.isEmpty) {
    print('ERROR: No valid PNG images found!');
    exit(1);
  }

  // Build ICO file
  // ICO format: Header (6 bytes) + Directory entries (16 bytes each) + PNG data
  final numImages = images.length;
  final headerSize = 6;
  final dirEntrySize = 16;
  final dataOffset = headerSize + (dirEntrySize * numImages);

  final buffer = BytesBuilder();

  // ICO Header
  buffer.add([0, 0]); // Reserved
  buffer.add([1, 0]); // Type: 1 = ICO
  buffer.addByte(numImages & 0xFF);
  buffer.addByte((numImages >> 8) & 0xFF);

  // Calculate offsets for each image
  var currentOffset = dataOffset;
  final offsets = <int>[];
  for (final pngData in pngDataList) {
    offsets.add(currentOffset);
    currentOffset += pngData.length;
  }

  // Directory entries
  for (var i = 0; i < numImages; i++) {
    final image = images[i];
    final pngData = pngDataList[i];

    // Width (0 means 256)
    buffer.addByte(image.width >= 256 ? 0 : image.width);
    // Height (0 means 256)
    buffer.addByte(image.height >= 256 ? 0 : image.height);
    buffer.addByte(0); // Color palette (0 for PNG)
    buffer.addByte(0); // Reserved
    buffer.add([1, 0]); // Color planes
    buffer.add([32, 0]); // Bits per pixel

    // Size of image data (4 bytes, little-endian)
    final size = pngData.length;
    buffer.addByte(size & 0xFF);
    buffer.addByte((size >> 8) & 0xFF);
    buffer.addByte((size >> 16) & 0xFF);
    buffer.addByte((size >> 24) & 0xFF);

    // Offset to image data (4 bytes, little-endian)
    final offset = offsets[i];
    buffer.addByte(offset & 0xFF);
    buffer.addByte((offset >> 8) & 0xFF);
    buffer.addByte((offset >> 16) & 0xFF);
    buffer.addByte((offset >> 24) & 0xFF);
  }

  // Image data
  for (final pngData in pngDataList) {
    buffer.add(pngData);
  }

  // Write the ICO file
  final outputPath = '$basePath/windows/runner/resources/app_icon.ico';
  final outputFile = File(outputPath);
  await outputFile.writeAsBytes(buffer.toBytes());
  print('\nICO file created: $outputPath');
  print('Contains ${images.length} sizes: ${images.map((i) => "${i.width}x${i.height}").join(", ")}');
}
