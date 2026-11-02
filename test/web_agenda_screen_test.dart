import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/web_agenda_screen.dart';

void main() {
  group('WebAgendaScreen.isAgendaPageUrl', () {
    test('permite solo el dominio de la agenda y su variante www', () {
      expect(WebAgendaScreen.isAgendaPageUrl('https://futbol-libre.cam/'), isTrue);
      expect(WebAgendaScreen.isAgendaPageUrl('https://www.futbol-libre.cam/agenda'), isTrue);
    });

    test('rechaza redirecciones a dominios externos o imitaciones', () {
      expect(WebAgendaScreen.isAgendaPageUrl('https://example.com/'), isFalse);
      expect(WebAgendaScreen.isAgendaPageUrl('https://futbol-libre.cam.evil.test/'), isFalse);
      expect(WebAgendaScreen.isAgendaPageUrl('https://futbol-libre.futbol/'), isFalse);
      expect(WebAgendaScreen.isAgendaPageUrl('javascript:alert(1)'), isFalse);
    });
  });
}
