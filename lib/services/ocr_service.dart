import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('Erro no OCR: $e');
      return '';
    }
  }

  /// Tenta extrair um endereço do texto bruto da nota fiscal
  String parseAddressFromText(String rawText) {
    if (rawText.isEmpty) return '';

    String rawUpper = rawText.toUpperCase();
    
    // --- 1. Tenta extração de campos estruturados da Nota Fiscal ---
    String logradouro = '';
    final logMatch = RegExp(r'(?:ENDERE[ÇC]O:\s*)?(RUA|AV\.|AVENIDA|RODOVIA|ROD\.|ESTRADA|TRAVESSA|R\.)\s+([^\n]+)').firstMatch(rawUpper);
    if (logMatch != null) {
      logradouro = '${logMatch.group(1)} ${logMatch.group(2)}'.trim();
      logradouro = logradouro.split(RegExp(r'\s+(N[°º]?|BAIRRO|MUNIC[ÍI]PIO|UF|CEP|COMP)\s*:')).first.trim();
      logradouro = logradouro.split(RegExp(r'\s+N[°º]$')).first.trim();
    }

    String numero = '';
    final numMatch = RegExp(r'N[°º]?\s*:\s*([A-Z0-9/]+)').firstMatch(rawUpper);
    if (numMatch != null) {
      numero = numMatch.group(1)!.split(RegExp(r'\s+(BAIRRO|MUNIC[ÍI]PIO|UF|CEP|COMP)\s*:')).first.trim();
    }

    String bairro = '';
    final bairroMatch = RegExp(r'BAIRRO\s*:\s*([^\n]+)').firstMatch(rawUpper);
    if (bairroMatch != null) {
      bairro = bairroMatch.group(1)!.split(RegExp(r'\s+(N[°º]?|MUNIC[ÍI]PIO|UF|CEP|COMP)\s*:')).first.trim();
    }

    String municipio = '';
    final munMatch = RegExp(r'MUNIC[ÍI]PIO\s*:\s*([^\n]+)').firstMatch(rawUpper);
    if (munMatch != null) {
      municipio = munMatch.group(1)!.split(RegExp(r'\s+(N[°º]?|BAIRRO|UF|CEP|COMP)\s*:')).first.trim();
    }

    // Monta o endereço estruturado se achou o logradouro
    if (logradouro.isNotEmpty) {
      final parts = <String>[logradouro];
      if (numero.isNotEmpty && numero != 'S/N' && numero != 'SN') parts.add(numero);
      if (bairro.isNotEmpty) parts.add(bairro);
      if (municipio.isNotEmpty) parts.add(municipio);
      
      String result = parts.join(', ');
      // Limpa possíveis duplos espaços ou vírgulas soltas
      result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (result.endsWith(',')) result = result.substring(0, result.length - 1);
      
      return result;
    }

    // --- 2. Fallback: Lógica antiga linha a linha ---
    final lines = rawText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String possibleAddress = '';

    final addressRegexFallback = RegExp(
      r'^(?:ENDERE[ÇC]O:\s*)?(RUA|AV\.|AVENIDA|RODOVIA|ROD\.|ESTRADA|TRAVESSA|R\.)\s+',
      caseSensitive: false,
    );
    final cepRegex = RegExp(r'\d{5}-\d{3}');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (addressRegexFallback.hasMatch(line)) {
        possibleAddress += line;
        if (i + 1 < lines.length && lines[i + 1].length > 3) {
          if (!RegExp(r'^[\d\s\.\,\-\/]+$').hasMatch(lines[i + 1])) {
            possibleAddress += ', ${lines[i + 1]}';
          }
        }
        break;
      }
    }

    if (possibleAddress.isEmpty) {
      for (final line in lines) {
        if (cepRegex.hasMatch(line)) {
          possibleAddress = line;
          break;
        }
      }
    }

    return possibleAddress.trim();
  }

  /// Tenta extrair o nome do cliente/destinatário do texto bruto da nota fiscal
  String parseClientNameFromText(String rawText) {
    if (rawText.isEmpty) return '';

    String rawUpper = rawText.toUpperCase();

    // 1. Regex de captura em linha única
    // Ex: NOME/RAZÃO SOCIAL: JOÃO DA SILVA
    // Ex: DESTINATÁRIO: TRANSPORTADORA XYZ
    final singleLineRegexes = [
      RegExp(r'(?:NOME\s*/\s*RAZ[ÃA]O\s+SOCIAL|NOME\s+RAZ[ÃA]O\s+SOCIAL|DESTINAT[AÁ]RIO\s*/\s*REMETENTE|DESTINAT[AÁ]RIO|CLIENTE)\s*[:\-]?\s*([A-ZÁÀÂÃÉÈÊÍÏÓÒÔÕÚÇÑ0-9\.\-\s]{3,})'),
      RegExp(r'(?:RAZ[ÃA]O\s+SOCIAL)\s*[:\-]?\s*([A-ZÁÀÂÃÉÈÊÍÏÓÒÔÕÚÇÑ0-9\.\-\s]{3,})'),
    ];

    for (final reg in singleLineRegexes) {
      final match = reg.firstMatch(rawUpper);
      if (match != null) {
        String name = match.group(1)!.trim();
        // Remove delimitadores de campo comuns
        name = name.split(RegExp(r'\s+(CNPJ|CPF|ENDERE[ÇC]O|FONE|INSCRI[ÇC]ÃO|DATA|BAIRRO)\b')).first.trim();
        if (name.isNotEmpty && name.length > 2) {
          return _toTitleCase(name);
        }
      }
    }

    // 2. Se não achou na mesma linha, tenta procurar linha a linha
    final lines = rawText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();
      if (lineUpper.contains('DESTINATÁRIO') || 
          lineUpper.contains('DESTINATARIO') || 
          lineUpper.contains('NOME / RAZÃO SOCIAL') ||
          lineUpper.contains('NOME/RAZÃO SOCIAL') ||
          lineUpper.contains('RAZÃO SOCIAL') ||
          lineUpper.contains('RAZAO SOCIAL') ||
          lineUpper.contains('CLIENTE:')) {
        
        String cleaned = lines[i].replaceAll(RegExp(r'(?:DESTINAT[AÁ]RIO(?:\s*/\s*REMETENTE)?|NOME\s*/\s*RAZ[ÃA]O\s+SOCIAL|RAZ[ÃA]O\s+SOCIAL|CLIENTE)\s*[:\-]?\s*', caseSensitive: false), '').trim();
        if (cleaned.length > 3 && !RegExp(r'^\d+$').hasMatch(cleaned)) {
          return _toTitleCase(cleaned);
        }
        
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.length > 3 && 
              !nextLine.toUpperCase().contains('CNPJ') && 
              !nextLine.toUpperCase().contains('ENDEREÇO') &&
              !RegExp(r'^\d+$').hasMatch(nextLine)) {
            return _toTitleCase(nextLine);
          }
        }
      }
    }

    return '';
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      final lower = word.toLowerCase();
      if (const ['de', 'di', 'da', 'do', 'dos', 'das', 'e'].contains(lower)) {
        return lower;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
