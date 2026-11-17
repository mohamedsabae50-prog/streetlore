import 'package:supabase_flutter/supabase_flutter.dart';

String sanitizeCheckInError(Object error, {required String locale}) {
  final rawMessage = error is PostgrestException ? error.message : '$error';
  if (RegExp(
    r'too far|out of range|outside|distance|radius|within .*m|نطاق|مسافة|بعيد|قريب|متر',
    caseSensitive: false,
  ).hasMatch(rawMessage)) {
    return locale == 'ar'
        ? 'يجب أن تكون داخل نطاق المكان (200 متر) لتسجيل الزيارة'
        : 'You must be within 200 meters of this place to check in';
  }

  final cleanMessage = rawMessage
      .replaceAll(
        RegExp(
          r'\b(?:PostgrestException|StateError|Exception)\s*:\s*',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'^PostgrestException\s*\([^)]*\)\s*:?\s*',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (cleanMessage.isNotEmpty &&
      !RegExp(
        r'Exception:|StateError:|PostgrestException',
        caseSensitive: false,
      ).hasMatch(cleanMessage)) {
    return cleanMessage;
  }
  return locale == 'ar'
      ? 'تعذر حفظ تسجيل الزيارة. حاول مرة أخرى.'
      : 'Check-in could not be saved. Please try again.';
}
