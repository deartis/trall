import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Contraste suave (1.25x) centrado no cinza médio (-32): faz o texto
  /// apagado "aparecer" sem estourar os claros nem perder detalhes.
  static const ui.ColorFilter _contrast = ui.ColorFilter.matrix(<double>[
    1.25, 0, 0, 0, -32,
    0, 1.25, 0, 0, -32,
    0, 0, 1.25, 0, -32,
    0, 0, 0, 1, 0,
  ]);

  /// Extrai texto da imagem aplicando pré-processamento leve (redimensiona
  /// para uma dimensão amigável ao ML Kit e aumenta o contraste de forma
  /// suave). Tudo roda no dispositivo — nenhum dado sai do aparelho.
  Future<String> extractTextFromImage(String imagePath) async {
    File? tempFile;
    try {
      final bytes = await File(imagePath).readAsBytes();
      final pngBytes = await _preprocessToPng(bytes);

      tempFile = File(
        '${Directory.systemTemp.path}/trallzero_ocr_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(pngBytes, flush: true);

      final recognizedText =
          await _textRecognizer.processImage(InputImage.fromFilePath(tempFile.path));
      return recognizedText.text;
    } catch (e) {
      debugPrint('Erro no OCR: $e');
      return '';
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // arquivo temporário pode ser limpo pelo SO/cache dir
        }
      }
    }
  }

  /// Decodifica a imagem (limitando a largura a ~1800px, sem upscale de fotos
  /// pequenas) e devolve como PNG com contraste aplicado.
  Future<Uint8List> _preprocessToPng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1800,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final source = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(source, ui.Offset.zero, ui.Paint()..colorFilter = _contrast);
    final picture = recorder.endRecording();

    final output = await picture.toImage(source.width, source.height);
    final png = await output.toByteData(format: ui.ImageByteFormat.png);

    source.dispose();
    output.dispose();
    codec.dispose();
    picture.dispose();

    return png!.buffer.asUint8List();
  }

  /// Tenta extrair um endereço do texto bruto da nota fiscal.
  ///
  /// Prefere campos estruturados (ENDEREÇO/BAIRRO/MUNICÍPIO), suporta número
  /// com e sem o rótulo "N°:", e cai para uma busca linha a linha se preciso.
  static String parseAddressFromText(String rawText) {
    if (rawText.isEmpty) return '';

    final rawUpper = rawText.toUpperCase();

    // Prefixos de logradouro comuns em NF-e/DANFE
    // Prefixo de logradouro capturante (grupo 1) + restante da linha (grupo 2)
    const streetPrefix =
        r'(RUA|R\.|AV\.|AVENIDA|RODOVIA|ROD\.|ESTRADA|EST\.|TRAVESSA|TRAV\.|ALAMEDA|AL\.|PRA[ÇC]A|PC\.|BECO|FAZENDA|S[ÍI]TIO|CH[ÁA]CARA|CONJUNTO|QUADRA|VIA|LARGO)';

    // --- 1. Extração de campos estruturados ---
    String logradouro = '';
    final logMatch = RegExp(
      r'(?:ENDERE[ÇC]O\s*:\s*)?' + streetPrefix + r'\s+([^\n]+)',
    ).firstMatch(rawUpper);
    if (logMatch != null) {
      logradouro = '${logMatch.group(1)} ${logMatch.group(2)}'.trim();
      // Corta no próximo campo conhecido
      logradouro = logradouro
          .split(RegExp(
              r'\s+(N[°º]?|NÚMERO|BAIRRO|DISTRITO|MUNIC[ÍI]PIO|CIDADE|UF|CEP|COMPLEMENTO)\s*:'))
          .first
          .trim();
      logradouro = logradouro.split(RegExp(r'\s+N[°º]$')).first.trim();
      // Limpa caracteres soltos que o OCR costuma deixar no fim
      logradouro = logradouro.replaceAll(RegExp(r'[\s,;:\-]+$'), '').trim();
    }

    String numero = '';
    final numMatch = RegExp(
      r'N[°º]?\s*:\s*([A-Z0-9]+(?:\s*/\s*[A-Z0-9]+)*)',
    ).firstMatch(rawUpper);
    if (numMatch != null) {
      numero = numMatch.group(1)!
          .split(RegExp(
              r'\s+(BAIRRO|MUNIC[ÍI]PIO|UF|CEP|COMPLEMENTO)\s*:'))
          .first
          .trim();
    } else if (logradouro.isNotEmpty) {
      // Caso comum sem "N°:" — número no fim do logradouro (ex: RUA X 123)
      final inlineNum = RegExp(r'\s(\d{1,5})$').firstMatch(logradouro);
      if (inlineNum != null) {
        numero = inlineNum.group(1)!;
        logradouro = logradouro.substring(0, inlineNum.start).trim();
      }
    }

    String bairro = '';
    final bairroMatch = RegExp(r'BAIRRO\s*:\s*([^\n]+)').firstMatch(rawUpper);
    if (bairroMatch != null) {
      bairro = bairroMatch.group(1)!
          .split(RegExp(
              r'\s+(N[°º]?|MUNIC[ÍI]PIO|CIDADE|UF|CEP|COMPLEMENTO)\s*:'))
          .first
          .trim();
    }

    String municipio = '';
    final munMatch =
        RegExp(r'(?:MUNIC[ÍI]PIO|CIDADE)\s*:\s*([^\n]+)').firstMatch(rawUpper);
    if (munMatch != null) {
      municipio = munMatch.group(1)!
          .split(RegExp(r'\s+(N[°º]?|BAIRRO|UF|CEP|COMPLEMENTO)\s*:'))
          .first
          .trim();
    }

    if (logradouro.isNotEmpty) {
      final parts = <String>[logradouro];
      final normalizedNum = numero.toUpperCase();
      if (normalizedNum.isNotEmpty &&
          normalizedNum != 'S/N' &&
          normalizedNum != 'SN') {
        parts.add(numero);
      }
      if (bairro.isNotEmpty) parts.add(bairro);
      if (municipio.isNotEmpty) parts.add(municipio);

      var result = parts.join(', ');
      result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
      result = result.replaceAll(RegExp(r'\s+,\s*'), ', ').trim();
      result = result.replaceFirst(RegExp(r',+\s*$'), '').trim();
      return result;
    }

    // --- 2. Fallback: busca linha a linha ---
    final lines = rawText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String possibleAddress = '';
    final addressRegexFallback = RegExp(
      r'^(?:ENDERE[ÇC]O\s*:\s*)?' + streetPrefix + r'\s+',
    );

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
        if (RegExp(r'\d{5}-\d{3}').hasMatch(line)) {
          possibleAddress = line;
          break;
        }
      }
    }

    return possibleAddress.replaceAll(RegExp(r'\s+,\s*'), ', ').trim();
  }

  /// Tenta extrair o nome do cliente/destinatário do texto bruto da nota fiscal.
  ///
  /// Procura rótulos típicos de NF-e (DESTINATÁRIO, NOME/RAZÃO SOCIAL, etc.)
  /// e, no pior caso, linhas que pareçam razões sociais (LTDA, S/A, MEI...).
  static String parseClientNameFromText(String rawText) {
    if (rawText.isEmpty) return '';

    final rawUpper = rawText.toUpperCase();

    // Rótulos que precedem o nome do destinatário/cliente em NF-e
    const labels =
        r'(?:NOME\s*(?:/\s*|\/)?\s*RAZ[ÃA]O\s+SOCIAL|RAZ[ÃA]O\s+SOCIAL|NOME\s+DO\s+RECEBEDOR|NOME\s+DO\s+CLIENTE|DESTINAT[AÁ]RIO\s*(?:/\s*REMETENTE)?|RECEBEDOR|TOMADOR|CLIENTE|LOJA|COM[ÉE]RCIO|MERCADO|SUPERMERCADO|DISTRIBUIDORA)';

    // Delimitadores que encerram o campo nome
    const delimiters =
        r'\s+(CNPJ|CPF|INSCRI[ÇC]|ENDERE[ÇC]O|FONE|TELEFONE|DATA\s+DA\s+EMISS[ÃA]O|DATA|BAIRRO|MUNIC[ÍI]PIO|N[°º]|CEP|EMAIL?)\b';

    // 1. Captura em linha única
    final nameChars = r'[A-ZÁÀÂÃÉÈÊÍÏÓÒÔÕÚÇÑ0-9\.\-\s]';
    final singleLineRegex = RegExp('$labels\\s*:?\\s*($nameChars{3,})');

    final match = singleLineRegex.firstMatch(rawUpper);
    if (match != null) {
      var name = match.group(1)!.trim();
      name = name.split(RegExp(delimiters)).first.trim();
      name = name.replaceAll(RegExp(r'^[\s:=\-]+'), '').trim();
      name = name.replaceAll(RegExp(r'[\s,;:=\-]+$'), '').trim();
      if (name.isNotEmpty && name.length > 2) {
        return _toTitleCase(name);
      }
    }

    // 2. Linha a linha
    final lines = rawText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final labelMatch = RegExp(labels);
    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();
      if (!labelMatch.hasMatch(lineUpper)) continue;

      var cleaned =
          lineUpper.replaceAll(RegExp(labels + r'\s*[:\-]?\s*'), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'[\s,;:=\-]+$'), '').trim();
      if (cleaned.length > 3 && !RegExp(r'^\d+$').hasMatch(cleaned)) {
        if (_looksLikeAddress(cleaned)) continue;
        return _toTitleCase(cleaned);
      }

      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.length > 3 &&
            !nextLine.toUpperCase().contains('CNPJ') &&
            !nextLine.toUpperCase().contains('ENDEREÇO') &&
            !_looksLikeAddress(nextLine) &&
            !RegExp(r'^\d+$').hasMatch(nextLine)) {
          return _toTitleCase(nextLine);
        }
      }
    }

    // 3. Fallback: linhas com características de razão social
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (!(upper.contains('LTDA') ||
          upper.contains('S/A') ||
          upper.contains('S.A.') ||
          upper.contains('MEI') ||
          upper.contains(' EPP'))) {
        continue;
      }

      if (!upper.contains('CNPJ') &&
          !upper.contains('CPF') &&
          !upper.contains('INSCRI') &&
          !_looksLikeAddress(line) &&
          !RegExp(r'^\d+$').hasMatch(line)) {
        final cleaned = line.replaceAll(RegExp(r'[\s,;:=\-]+$'), '').trim();
        if (cleaned.isNotEmpty) return _toTitleCase(cleaned);
      }
    }

    return '';
  }

  /// Verdadeiro quando a linha parece um endereço (e não um nome de negócio).
  static bool _looksLikeAddress(String line) {
    final upper = line.toUpperCase();
    return RegExp(
      r'\b(RUA|R\.|AV\.|AVENIDA|RODOVIA|ROD\.|ESTRADA|TRAVESSA|ALAMEDA|MUNIC[ÍI]PIO|CEP)\b',
    ).hasMatch(upper) ||
        RegExp(r'^\d{5}-\d{3}').hasMatch(upper);
  }

  static String _toTitleCase(String text) {
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