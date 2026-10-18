import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/receipt_parser_helper.dart';
import '../../logic/providers/category_provider.dart';
import '../models/receipt_scan_result.dart';

class ReceiptScannerService {
  final ImagePicker _imagePicker;

  ReceiptScannerService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  /// Mengambil gambar struk menggunakan kamera atau galeri
  Future<XFile?> pickReceiptImage({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// Membaca dan mengenali teks (OCR) dari file gambar menggunakan Google ML Kit
  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      // Pastikan recognizer selalu ditutup untuk membebaskan memory
      await textRecognizer.close();
    }
  }

  /// Menganalisis string teks struk: mengekstrak nominal terbesar, judul toko, dan mencocokkan kategori
  Future<ReceiptScanResult> analyzeReceiptText({
    required String rawText,
    required CategoryProvider categoryProvider,
    bool autoCreateCategoryIfNotFound = true,
  }) async {
    final largestAmount = ReceiptParserHelper.extractLargestAmount(rawText);
    final merchantTitle = ReceiptParserHelper.extractMerchantTitle(rawText);

    final matchResult = await ReceiptParserHelper.matchOrSuggestCategory(
      rawText: rawText,
      existingCategories: categoryProvider.categories,
      categoryProvider: categoryProvider,
      autoCreateIfNotFound: autoCreateCategoryIfNotFound,
    );

    return ReceiptScanResult(
      rawText: rawText,
      detectedTitle: merchantTitle,
      totalAmount: largestAmount,
      category: matchResult.category,
      isNewCategoryCreated: matchResult.isNewCreated,
      detectedDate: DateTime.now(),
    );
  }

  /// Alur lengkap: Ambil gambar struk -> OCR Teks -> Ekstraksi Nominal & Kategori
  Future<ReceiptScanResult?> scanAndProcessReceipt({
    ImageSource source = ImageSource.camera,
    required CategoryProvider categoryProvider,
    bool autoCreateCategoryIfNotFound = true,
  }) async {
    final image = await pickReceiptImage(source: source);
    if (image == null) return null;

    final rawText = await recognizeText(image.path);
    if (rawText.trim().isEmpty) {
      throw Exception('Tidak ada teks yang berhasil dibaca dari gambar struk.');
    }

    return await analyzeReceiptText(
      rawText: rawText,
      categoryProvider: categoryProvider,
      autoCreateCategoryIfNotFound: autoCreateCategoryIfNotFound,
    );
  }
}
