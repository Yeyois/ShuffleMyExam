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

  // Shuffled-PDF library.
  static const libraryTitle = 'מבחנים מעורבבים';
  static const openLibrary = 'מבחנים מעורבבים';
  static const emptyLibrary =
      'עדיין אין קבצים מעורבבים. צרו מבחן מעורבב כדי שיופיע כאן.';
  static const shuffleAgain = 'צור מבחן מעורבב';
  static const shareFile = 'שיתוף / הורדה';
  static const deleteFile = 'מחיקת קובץ';
  static const deleteFileConfirm = 'למחוק את הקובץ המעורבב הזה?';
  static const savedToLibrary = 'הקובץ נשמר לספריית המבחנים המעורבבים';

  // Practice screen.
  static const revealOriginalAnswers = 'הצג פתרון מקורי';
  static const showCroppedAgain = 'הסתר פתרון';
  static const nextQuestion = 'השאלה הבאה';
  static const previousQuestion = 'הקודמת';
  static const finishPractice = 'סיים תרגול והצג ציון';
  static String questionOf(int current, int total) =>
      'שאלה $current מתוך $total';

  // Immediate answer feedback.
  static const answerCorrect = 'נכון! כל הכבוד';
  static const answerWrong = 'טעות';
  static const correctAnswerIs = 'התשובה הנכונה מסומנת בירוק';

  // Results screen.
  static const resultsTitle = 'תוצאות התרגול';
  static const statsTitle = 'סטטיסטיקה';
  static const statCorrect = 'תשובות נכונות';
  static const statWrong = 'תשובות שגויות';
  static const statUnanswered = 'ללא מענה';
  static const statVisual = 'שאלות לבדיקה עצמית';
  static const mistakesTitle = 'שאלות שטעיתם בהן';
  static const noMistakes = 'מושלם! אין טעויות.';
  static const yourAnswer = 'התשובה שלך';
  static const correctAnswer = 'התשובה הנכונה';
  static const backToHome = 'חזרה לתרגולים';
}
