import 'package:flutter_test/flutter_test.dart';
import 'package:trallzero/services/ocr_service.dart';

void main() {
  group('OcrService.parseAddressFromText', () {
    test('extrai endereço estruturado de NF-e', () {
      const raw = '''
DESTINATÁRIO: COMERCIO TIRADENTES LTDA
CNPJ: 12.345.678/0001-90
ENDEREÇO: RUA TIRADENTES 123
BAIRRO: CENTRO
MUNICÍPIO: BELO HORIZONTE
UF: MG
CEP: 30100-000
''';
      final result = OcrService.parseAddressFromText(raw);
      expect(result.toLowerCase(), contains('rua tiradentes'));
      expect(result, contains('123'));
      expect(result.toLowerCase(), contains('centro'));
      expect(result.toLowerCase(), contains('belo horizonte'));
    });

    test('extrai número sem rótulo "N°:"', () {
      const raw = 'ENDEREÇO: AV. GETULIO VARGAS 1500\nBAIRRO: CENTRO\n';
      final result = OcrService.parseAddressFromText(raw);
      expect(result.toLowerCase(), contains('getulio vargas'));
      expect(result, contains('1500'));
    });

    test('extrai endereço via fallback linha a linha', () {
      const raw = 'RUA XV DE NOVEMBRO, 200\nCEP: 20040-020\n';
      final result = OcrService.parseAddressFromText(raw);
      expect(result.toLowerCase(), contains('xv de novembro'));
      expect(result, contains('200'));
    });
  });

  group('OcrService.parseClientNameFromText', () {
    test('extrai nome via NOME/RAZÃO SOCIAL', () {
      const raw =
          'NOME/RAZÃO SOCIAL: TRANSPORTADORA ANDRADE LTDA\nCNPJ: 12.345.678/0001-90';
      final result = OcrService.parseClientNameFromText(raw);
      expect(result.toLowerCase(), contains('andrade'));
    });

    test('extrai nome na linha seguinte ao rótulo', () {
      const raw =
          'DESTINATÁRIO:\nMERCADO SAO JOSE EPP\nCNPJ: 00.000.000/0001-00';
      final result = OcrService.parseClientNameFromText(raw);
      expect(result.toLowerCase(), contains('mercado sao jose'));
    });

    test('fallback por razão social quando não há rótulo', () {
      const raw =
          'EMISSÃO 01/01/2026\nPADARIA BOM PÃO LTDA\nCNPJ: 12.123.123/0001-01';
      final result = OcrService.parseClientNameFromText(raw);
      expect(result.toLowerCase(), contains('padaria bom'));
    });
  });
}