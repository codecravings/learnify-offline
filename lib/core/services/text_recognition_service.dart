import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR via Google ML Kit. Replaces the broken
/// `flutter_gemma` multimodal path: the `.litertlm` build of gemma-4-E2B-it
/// silently drops image inputs, so we OCR the page locally and pass the
/// extracted text to Gemma as a normal text prompt.
///
/// Lazy-init: the recognizer spins up on first call, then is cached for the
/// lifetime of the singleton. Latin script only — fits English/Hindi/most
/// European languages of the supported profile set.
class TextRecognitionService {
  TextRecognitionService._();
  static final TextRecognitionService instance = TextRecognitionService._();

  TextRecognizer? _recognizer;

  TextRecognizer _ensure() {
    return _recognizer ??=
        TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<String> extractFromFile(String filePath) async {
    final input = InputImage.fromFilePath(filePath);
    final result = await _ensure().processImage(input);
    return result.text.trim();
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
