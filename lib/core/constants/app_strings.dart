/// Hebrew UI strings used across the app.
///
/// The app is Hebrew-first and fully RTL, so strings live here rather than
/// in an l10n pipeline.
abstract final class AppStrings {
  static const appTitle = 'JCT MixExam';

  // Home screen.
  static const homeTitle = 'התרגולים שלי';
  static const emptyHome = 'עדיין אין מבחנים. ייבאו קובץ PDF כדי להתחיל.';
  static const importExam = 'ייבוא מבחן';
  static const deleteExam = 'מחיקת מבחן';
  static const deleteExamConfirm = 'למחוק את המבחן הזה? הפעולה אינה הפיכה.';
  static const cancel = 'ביטול';
  static const delete = 'מחיקה';

  // Loading / processing screen.
  static const processingTitle = 'מעבדים את הקובץ...';
  static const processingHint = 'החילוץ מתבצע במכשיר בלבד, ללא חיבור לרשת.';
  static const extractionSucceeded = 'המבחן חולץ בהצלחה!';
  static String questionsFound(int count) => 'נמצאו $count שאלות.';
  static const startPractice = 'התחל תרגול';
  static const extractionFailed = 'חילוץ המבחן נכשל';
  static const backHome = 'חזרה למסך הבית';

  // Shuffled-PDF export.
  static const downloadShuffledPdf = 'הורדת מבחן מעורבב (PDF)';
  static const preparingPdf = 'מכינים את הקובץ...';
  static const exportFailed = 'יצירת הקובץ נכשלה';
  static const sharePdfSubject = 'מבחן מעורבב';

  // Practice screen.
  static const revealCorrectAnswer = 'הצג תשובה נכונה';
  static const revealOriginalAnswers = 'הצג פתרון מקורי';
  static const showCroppedAgain = 'הסתר פתרון';
  static const finishPractice = 'סיים תרגול והצג ציון';
  static String questionOf(int current, int total) =>
      'שאלה $current מתוך $total';

  // Results screen.
  static const resultsTitle = 'תוצאות התרגול';
  static const mistakesTitle = 'שאלות שטעיתם בהן';
  static const noMistakes = 'מושלם! אין טעויות.';
  static const yourAnswer = 'התשובה שלך';
  static const correctAnswer = 'התשובה הנכונה';
  static const backToHome = 'חזרה לתרגולים';
}
