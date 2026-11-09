import 'package:flutter/foundation.dart';

enum AppLanguage { spanish, english, portuguese, french }

final ValueNotifier<AppLanguage> appLanguage =
    ValueNotifier<AppLanguage>(AppLanguage.spanish);

String languageCode(AppLanguage language) {
  switch (language) {
    case AppLanguage.spanish:
      return 'es';
    case AppLanguage.english:
      return 'en';
    case AppLanguage.portuguese:
      return 'pt';
    case AppLanguage.french:
      return 'fr';
  }
}

AppLanguage parseLanguage(String? code) {
  return code == 'en' ? AppLanguage.english : AppLanguage.spanish;
}

const Map<String, Map<AppLanguage, String>> _labels =
    <String, Map<AppLanguage, String>>{
  'title': <AppLanguage, String>{
    AppLanguage.spanish: 'DEPORTE TOTAL 360°',
    AppLanguage.english: 'TOTAL SPORTS 360°',
    AppLanguage.portuguese: 'ESPORTE TOTAL 360°',
    AppLanguage.french: 'SPORT TOTAL 360°',
  },
  'tagline': <AppLanguage, String>{
    AppLanguage.spanish: 'TODOS LOS DEPORTES EN UN SOLO LUGAR',
    AppLanguage.english: 'ALL SPORTS IN ONE PLACE',
    AppLanguage.portuguese: 'TODOS OS ESPORTES EM UM SÓ LUGAR',
    AppLanguage.french: 'TOUS LES SPORTS AU MÊME ENDROIT',
  },
  'home': <AppLanguage, String>{
    AppLanguage.spanish: 'Inicio',
    AppLanguage.english: 'Home',
    AppLanguage.portuguese: 'Início',
    AppLanguage.french: 'Accueil',
  },
  'football': <AppLanguage, String>{
    AppLanguage.spanish: 'Fútbol',
    AppLanguage.english: 'Football',
    AppLanguage.portuguese: 'Futebol',
    AppLanguage.french: 'Football',
  },
  'live': <AppLanguage, String>{
    AppLanguage.spanish: 'En vivo',
    AppLanguage.english: 'Live',
    AppLanguage.portuguese: 'Ao vivo',
    AppLanguage.french: 'En direct',
  },
  'agenda': <AppLanguage, String>{
    AppLanguage.spanish: 'Agenda',
    AppLanguage.english: 'Schedule',
    AppLanguage.portuguese: 'Agenda',
    AppLanguage.french: 'Agenda',
  },
  'web_agenda': <AppLanguage, String>{
    AppLanguage.spanish: 'Agenda web',
    AppLanguage.english: 'Web schedule',
    AppLanguage.portuguese: 'Agenda web',
    AppLanguage.french: 'Agenda web',
  },
  'chat': <AppLanguage, String>{
    AppLanguage.spanish: 'Chat',
    AppLanguage.english: 'Chat',
    AppLanguage.portuguese: 'Chat',
    AppLanguage.french: 'Chat',
  },
  'settings': <AppLanguage, String>{
    AppLanguage.spanish: 'Ajustes',
    AppLanguage.english: 'Settings',
    AppLanguage.portuguese: 'Configurações',
    AppLanguage.french: 'Réglages',
  },
  'streams': <AppLanguage, String>{
    AppLanguage.spanish: 'TRANSMISIONES EN VIVO',
    AppLanguage.english: 'LIVE STREAMS',
    AppLanguage.portuguese: 'TRANSMISSÕES AO VIVO',
    AppLanguage.french: 'DIFFUSIONS EN DIRECT',
  },
  'matches': <AppLanguage, String>{
    AppLanguage.spanish: 'AGENDA DE PARTIDOS',
    AppLanguage.english: 'MATCH SCHEDULE',
    AppLanguage.portuguese: 'AGENDA DE JOGOS',
    AppLanguage.french: 'CALENDRIER DES MATCHS',
  },
  'telegram': <AppLanguage, String>{
    AppLanguage.spanish: 'TELEGRAM',
    AppLanguage.english: 'TELEGRAM',
    AppLanguage.portuguese: 'TELEGRAM',
    AppLanguage.french: 'TELEGRAM',
  },
  'contact': <AppLanguage, String>{
    AppLanguage.spanish: 'CONTACTAR CON EL CREADOR',
    AppLanguage.english: 'CONTACT THE CREATOR',
    AppLanguage.portuguese: 'CONTACTAR O CRIADOR',
    AppLanguage.french: 'CONTACTER LE CRÉATEUR',
  },
  'donations': <AppLanguage, String>{
    AppLanguage.spanish: 'DONACIONES',
    AppLanguage.english: 'DONATIONS',
    AppLanguage.portuguese: 'DOAÇÕES',
    AppLanguage.french: 'DONS',
  },
  'language': {
    AppLanguage.spanish: 'Idioma',
    AppLanguage.english: 'Language',
    AppLanguage.portuguese: 'Idioma',
    AppLanguage.french: 'Langue',
  },
  'settings_description': {
    AppLanguage.spanish: 'Ajustes de la aplicación',
    AppLanguage.english: 'Application settings',
    AppLanguage.portuguese: 'Configurações do aplicativo',
    AppLanguage.french: 'Paramètres de l’application',
  },
  'settings_intro': {
    AppLanguage.spanish: 'Configura tu idioma y tus enlaces oficiales.',
    AppLanguage.english: 'Configure your language and official links.',
    AppLanguage.portuguese: 'Configure seu idioma e links oficiais.',
    AppLanguage.french: 'Configurez votre langue et vos liens officiels.',
  },
  'telegram_section': {
    AppLanguage.spanish: 'CANAL DE TELEGRAM',
    AppLanguage.english: 'TELEGRAM CHANNEL',
    AppLanguage.portuguese: 'CANAL DO TELEGRAM',
    AppLanguage.french: 'CHAÎNE TELEGRAM',
  },
  'telegram_description': {
    AppLanguage.spanish: 'Este espacio queda reservado para tu canal real. No se abrirá ningún enlace genérico si lo dejas vacío.',
    AppLanguage.english: 'This space is reserved for your real channel. No generic link will open if you leave it empty.',
    AppLanguage.portuguese: 'Este espaço fica reservado para seu canal real. Nenhum link genérico será aberto se ficar vazio.',
    AppLanguage.french: 'Cet espace est réservé à votre véritable chaîne. Aucun lien générique ne sera ouvert si vous le laissez vide.',
  },
  'public_link': {
    AppLanguage.spanish: 'Enlace público (opcional)',
    AppLanguage.english: 'Public link (optional)',
    AppLanguage.portuguese: 'Link público (opcional)',
    AppLanguage.french: 'Lien public (facultatif)',
  },
  'statistics': <AppLanguage, String>{
    AppLanguage.spanish: 'Estadísticas',
    AppLanguage.english: 'Statistics',
    AppLanguage.portuguese: 'Estatísticas',
    AppLanguage.french: 'Statistiques',
  },
  'stats_title': <AppLanguage, String>{
    AppLanguage.spanish: 'ESTADÍSTICAS DEPORTIVAS',
    AppLanguage.english: 'SPORTS STATISTICS',
    AppLanguage.portuguese: 'ESTATÍSTICAS ESPORTIVAS',
    AppLanguage.french: 'STATISTIQUES SPORTIVES',
  },
  'stats_description': <AppLanguage, String>{
    AppLanguage.spanish: 'Resultados, clasificaciones, temporadas e identificadores oficiales de todos los deportes disponibles.',
    AppLanguage.english: 'Results, standings, seasons and official identifiers for all available sports.',
    AppLanguage.portuguese: 'Resultados, classificações, temporadas e identificadores oficiais de todos os esportes disponíveis.',
    AppLanguage.french: 'Résultats, classements, saisons et identifiants officiels de tous les sports disponibles.',
  },
  'notifications': <AppLanguage, String>{
    AppLanguage.spanish: 'NOTIFICACIONES DEPORTIVAS',
    AppLanguage.english: 'SPORTS NOTIFICATIONS',
    AppLanguage.portuguese: 'NOTIFICAÇÕES ESPORTIVAS',
    AppLanguage.french: 'NOTIFICATIONS SPORTIVES',
  },
  'notifications_description': <AppLanguage, String>{
    AppLanguage.spanish: 'Recibe avisos locales 60, 30, 15 y 5 minutos antes de los eventos cargados en la agenda.',
    AppLanguage.english: 'Get local alerts 60, 30, 15 and 5 minutes before scheduled events start.',
    AppLanguage.portuguese: 'Receba avisos locais 60, 30, 15 e 5 minutos antes dos eventos carregados na agenda.',
    AppLanguage.french: 'Recevez des alertes locales 60, 30, 15 et 5 minutes avant les événements chargés dans le calendrier.',
  },
  'notifications_enabled': <AppLanguage, String>{
    AppLanguage.spanish: 'Activar recordatorios',
    AppLanguage.english: 'Enable reminders',
    AppLanguage.portuguese: 'Ativar lembretes',
    AppLanguage.french: 'Activer les rappels',
  },
  'public_chat': <AppLanguage, String>{
    AppLanguage.spanish: 'CHAT PÚBLICO',
    AppLanguage.english: 'PUBLIC CHAT',
    AppLanguage.portuguese: 'CHAT PÚBLICO',
    AppLanguage.french: 'CHAT PUBLIC',
  },
  'public_chat_online': <AppLanguage, String>{
    AppLanguage.spanish: 'SALA COMPARTIDA · TODOS LOS USUARIOS',
    AppLanguage.english: 'SHARED ROOM · ALL USERS',
    AppLanguage.portuguese: 'SALA COMPARTILHADA · TODOS OS USUÁRIOS',
    AppLanguage.french: 'SALON PARTAGÉ · TOUS LES UTILISATEURS',
  },
  'public_chat_name': <AppLanguage, String>{
    AppLanguage.spanish: 'Tu nombre público',
    AppLanguage.english: 'Your public name',
    AppLanguage.portuguese: 'Seu nome público',
    AppLanguage.french: 'Votre nom public',
  },
  'public_chat_name_hint': <AppLanguage, String>{
    AppLanguage.spanish: 'Ej.: Damian',
    AppLanguage.english: 'e.g. Alex',
    AppLanguage.portuguese: 'Ex.: Alex',
    AppLanguage.french: 'Ex. : Alex',
  },
  'public_chat_message_hint': <AppLanguage, String>{
    AppLanguage.spanish: 'Escribe un mensaje…',
    AppLanguage.english: 'Write a message…',
    AppLanguage.portuguese: 'Escreva uma mensagem…',
    AppLanguage.french: 'Écrivez un message…',
  },
  'public_chat_retry': <AppLanguage, String>{
    AppLanguage.spanish: 'REINTENTAR',
    AppLanguage.english: 'RETRY',
    AppLanguage.portuguese: 'TENTAR NOVAMENTE',
    AppLanguage.french: 'RÉESSAYER',
  },
  'public_chat_empty': <AppLanguage, String>{
    AppLanguage.spanish: 'Todavía no hay mensajes. ¡Saluda a la comunidad!',
    AppLanguage.english: 'There are no messages yet. Say hello to the community!',
    AppLanguage.portuguese: 'Ainda não há mensagens. Dê oi à comunidade!',
    AppLanguage.french: 'Aucun message pour le moment. Saluez la communauté !',
  },
  'public_chat_rules': <AppLanguage, String>{
    AppLanguage.spanish: 'Chat público: todos pueden leer y escribir. No compartas contraseñas, teléfonos ni datos personales. Los nombres son alias y no están verificados.',
    AppLanguage.english: 'Public chat: everyone can read and post. Do not share passwords, phone numbers or personal data. Names are unverified nicknames.',
    AppLanguage.portuguese: 'Chat público: todos podem ler e escrever. Não compartilhe senhas, telefones ou dados pessoais. Os nomes são apelidos não verificados.',
    AppLanguage.french: 'Chat public : tout le monde peut lire et écrire. Ne partagez pas de mots de passe, numéros de téléphone ou données personnelles. Les noms sont des pseudonymes non vérifiés.',
  },
};

String tr(String key) => _labels[key]?[appLanguage.value] ?? key;

String appText(String spanish, String english, String portuguese, String french) {
  switch (appLanguage.value) {
    case AppLanguage.spanish: return spanish;
    case AppLanguage.english: return english;
    case AppLanguage.portuguese: return portuguese;
    case AppLanguage.french: return french;
  }
}
