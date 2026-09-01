import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopAll.
  ///
  /// In en, this message translates to:
  /// **'STOP ALL'**
  String get stopAll;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get gameOver;

  /// No description provided for @selectOption.
  ///
  /// In en, this message translates to:
  /// **'Select Option'**
  String get selectOption;

  /// No description provided for @currentValue.
  ///
  /// In en, this message translates to:
  /// **'Current: {v}'**
  String currentValue(String v);

  /// No description provided for @roomList.
  ///
  /// In en, this message translates to:
  /// **'Room List'**
  String get roomList;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @createdRooms.
  ///
  /// In en, this message translates to:
  /// **'The rooms you created'**
  String get createdRooms;

  /// No description provided for @otherRooms.
  ///
  /// In en, this message translates to:
  /// **'The other rooms'**
  String get otherRooms;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// No description provided for @enterRoomName.
  ///
  /// In en, this message translates to:
  /// **'Enter room name'**
  String get enterRoomName;

  /// No description provided for @joinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join Room'**
  String get joinRoom;

  /// No description provided for @joinByIp.
  ///
  /// In en, this message translates to:
  /// **'Join by IP'**
  String get joinByIp;

  /// No description provided for @enterUserName.
  ///
  /// In en, this message translates to:
  /// **'Enter user name'**
  String get enterUserName;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// No description provided for @hostIp.
  ///
  /// In en, this message translates to:
  /// **'Host IP'**
  String get hostIp;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'About to leave the room'**
  String get leaveRoom;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @roomClosed.
  ///
  /// In en, this message translates to:
  /// **'Room closed'**
  String get roomClosed;

  /// No description provided for @cannotReconnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot reconnect to server'**
  String get cannotReconnect;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting... ({cur}/{max})'**
  String reconnecting(int cur, int max);

  /// No description provided for @competitorsWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Opponent Left'**
  String get competitorsWithdraw;

  /// No description provided for @opponentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'The opponent has withdrawn'**
  String get opponentWithdrawn;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessage;

  /// No description provided for @wait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get wait;

  /// No description provided for @youSurrendered.
  ///
  /// In en, this message translates to:
  /// **'You Surrendered'**
  String get youSurrendered;

  /// No description provided for @opponentSurrendered.
  ///
  /// In en, this message translates to:
  /// **'Opponent Surrendered'**
  String get opponentSurrendered;

  /// No description provided for @chatRoom.
  ///
  /// In en, this message translates to:
  /// **'Chat Room'**
  String get chatRoom;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Chat Settings'**
  String get chatSettings;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all chat history? This cannot be undone.'**
  String get clearHistoryConfirm;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @messageNotification.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get messageNotification;

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @imageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image load failed'**
  String get imageLoadFailed;

  /// No description provided for @unknownFile.
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get unknownFile;

  /// No description provided for @selectImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select image'**
  String get selectImageFailed;

  /// No description provided for @takePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to take photo'**
  String get takePhotoFailed;

  /// No description provided for @sendImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send image'**
  String get sendImageFailed;

  /// No description provided for @selectFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select file'**
  String get selectFileFailed;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get saveSuccess;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to'**
  String get savedTo;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get downloading;

  /// No description provided for @emojiCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get emojiCommon;

  /// No description provided for @emojiGesture.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get emojiGesture;

  /// No description provided for @emojiHeart.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get emojiHeart;

  /// No description provided for @emojiAnimal.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get emojiAnimal;

  /// No description provided for @emojiFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get emojiFood;

  /// No description provided for @emojiSport.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get emojiSport;

  /// No description provided for @emojiTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get emojiTravel;

  /// No description provided for @emojiSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get emojiSymbol;

  /// No description provided for @stepDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Waiting to connect'**
  String get stepDisconnect;

  /// No description provided for @stepConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected, waiting for opponent...'**
  String get stepConnected;

  /// No description provided for @stepFrontConfig.
  ///
  /// In en, this message translates to:
  /// **'Please configure'**
  String get stepFrontConfig;

  /// No description provided for @stepRearWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first player config'**
  String get stepRearWait;

  /// No description provided for @stepFrontWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for second player config'**
  String get stepFrontWait;

  /// No description provided for @stepRearConfig.
  ///
  /// In en, this message translates to:
  /// **'Configure or view opponent config'**
  String get stepRearConfig;

  /// No description provided for @stepAction.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get stepAction;

  /// No description provided for @stepGameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get stepGameOver;

  /// No description provided for @animalChess.
  ///
  /// In en, this message translates to:
  /// **'Animal Chess'**
  String get animalChess;

  /// No description provided for @netAnimalChess.
  ///
  /// In en, this message translates to:
  /// **'Net Animal Chess'**
  String get netAnimalChess;

  /// No description provided for @setBoardSize.
  ///
  /// In en, this message translates to:
  /// **'Set Board Size'**
  String get setBoardSize;

  /// No description provided for @redTurn.
  ///
  /// In en, this message translates to:
  /// **'Red\'s Turn'**
  String get redTurn;

  /// No description provided for @blueTurn.
  ///
  /// In en, this message translates to:
  /// **'Blue\'s Turn'**
  String get blueTurn;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your Turn'**
  String get yourTurn;

  /// No description provided for @opponentTurn.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s Turn'**
  String get opponentTurn;

  /// No description provided for @redWin.
  ///
  /// In en, this message translates to:
  /// **'Red Wins!'**
  String get redWin;

  /// No description provided for @blueWin.
  ///
  /// In en, this message translates to:
  /// **'Blue Wins!'**
  String get blueWin;

  /// No description provided for @gobang.
  ///
  /// In en, this message translates to:
  /// **'Gomoku'**
  String get gobang;

  /// No description provided for @netGobang.
  ///
  /// In en, this message translates to:
  /// **'Net Gomoku'**
  String get netGobang;

  /// No description provided for @blackSide.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get blackSide;

  /// No description provided for @whiteSide.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get whiteSide;

  /// No description provided for @currentTurn.
  ///
  /// In en, this message translates to:
  /// **'Current Turn: {side}'**
  String currentTurn(String side);

  /// No description provided for @sideWin.
  ///
  /// In en, this message translates to:
  /// **'{side} Wins!'**
  String sideWin(String side);

  /// No description provided for @yourSideTurn.
  ///
  /// In en, this message translates to:
  /// **'Your Turn {side}'**
  String yourSideTurn(String side);

  /// No description provided for @opponentSideTurn.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s Turn {side}'**
  String opponentSideTurn(String side);

  /// No description provided for @aiLabel.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiLabel;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'AI Thinking…'**
  String get aiThinking;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @weiqi.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get weiqi;

  /// No description provided for @finalLength.
  ///
  /// In en, this message translates to:
  /// **'Final Length'**
  String get finalLength;

  /// No description provided for @sudoku.
  ///
  /// In en, this message translates to:
  /// **'Sudoku'**
  String get sudoku;

  /// No description provided for @setDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Set Difficulty'**
  String get setDifficulty;

  /// No description provided for @pleaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Please Confirm'**
  String get pleaseConfirm;

  /// No description provided for @leaveRoomLoseProgress.
  ///
  /// In en, this message translates to:
  /// **'Leaving will lose progress'**
  String get leaveRoomLoseProgress;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @difficultyTime.
  ///
  /// In en, this message translates to:
  /// **'Difficulty: {d} Time: {t}'**
  String difficultyTime(String d, String t);

  /// No description provided for @startNewGame.
  ///
  /// In en, this message translates to:
  /// **'Start New Game'**
  String get startNewGame;

  /// No description provided for @importPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Import Puzzle'**
  String get importPuzzle;

  /// No description provided for @importFailConflict.
  ///
  /// In en, this message translates to:
  /// **'Board has conflicts. Check rows, columns and boxes for duplicates.'**
  String get importFailConflict;

  /// No description provided for @importFailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Fill in at least one number.'**
  String get importFailEmpty;

  /// No description provided for @importFailNotUnique.
  ///
  /// In en, this message translates to:
  /// **'The puzzle has no unique solution. Adjust the numbers.'**
  String get importFailNotUnique;

  /// No description provided for @confirmImport.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmImport;

  /// No description provided for @cancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelImport;

  /// No description provided for @guess.
  ///
  /// In en, this message translates to:
  /// **'Guess'**
  String get guess;

  /// No description provided for @timeTaken.
  ///
  /// In en, this message translates to:
  /// **'Time Taken: {s} seconds'**
  String timeTaken(int s);

  /// No description provided for @correctCount.
  ///
  /// In en, this message translates to:
  /// **'Correct Count: {c}'**
  String correctCount(int c);

  /// No description provided for @memoryCard.
  ///
  /// In en, this message translates to:
  /// **'Memory Match'**
  String get memoryCard;

  /// No description provided for @remainingPairs.
  ///
  /// In en, this message translates to:
  /// **'Remaining {v} pairs'**
  String remainingPairs(int v);

  /// No description provided for @bestTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Time'**
  String get bestTimeLabel;

  /// No description provided for @schulte.
  ///
  /// In en, this message translates to:
  /// **'Schulte'**
  String get schulte;

  /// No description provided for @nextNumber.
  ///
  /// In en, this message translates to:
  /// **'Next: {v}'**
  String nextNumber(int v);

  /// No description provided for @threeTiles.
  ///
  /// In en, this message translates to:
  /// **'3tiles'**
  String get threeTiles;

  /// No description provided for @timeSeconds.
  ///
  /// In en, this message translates to:
  /// **'Time: {v} s'**
  String timeSeconds(int v);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {v}'**
  String remaining(int v);

  /// No description provided for @youLost.
  ///
  /// In en, this message translates to:
  /// **'You Lost'**
  String get youLost;

  /// No description provided for @chooseDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Choose Difficulty'**
  String get chooseDifficulty;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @difficultyTimeSeconds.
  ///
  /// In en, this message translates to:
  /// **'Difficulty: {d} Time: {t} s'**
  String difficultyTimeSeconds(String d, int t);

  /// No description provided for @spaceship.
  ///
  /// In en, this message translates to:
  /// **'Space Ship'**
  String get spaceship;

  /// No description provided for @lives.
  ///
  /// In en, this message translates to:
  /// **'Lives: {v}'**
  String lives(double v);

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score: {v}'**
  String score(int v);

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level: {v}'**
  String level(int v);

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// No description provided for @gamePaused.
  ///
  /// In en, this message translates to:
  /// **'Game Paused'**
  String get gamePaused;

  /// No description provided for @continueGame.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueGame;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @restartGame.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartGame;

  /// No description provided for @exitGame.
  ///
  /// In en, this message translates to:
  /// **'Exit Game'**
  String get exitGame;

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get levelUp;

  /// No description provided for @currentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level: {v}'**
  String currentLevel(int v);

  /// No description provided for @harderChallenge.
  ///
  /// In en, this message translates to:
  /// **'Ready for harder challenges!'**
  String get harderChallenge;

  /// No description provided for @finalScore.
  ///
  /// In en, this message translates to:
  /// **'Final Score'**
  String get finalScore;

  /// No description provided for @reachedLevel.
  ///
  /// In en, this message translates to:
  /// **'Reached Level'**
  String get reachedLevel;

  /// No description provided for @unlockedAchievement.
  ///
  /// In en, this message translates to:
  /// **'Unlocked Achievement'**
  String get unlockedAchievement;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @noAchievements.
  ///
  /// In en, this message translates to:
  /// **'No achievements unlocked'**
  String get noAchievements;

  /// No description provided for @enemyEscaped.
  ///
  /// In en, this message translates to:
  /// **'Enemy Escaped!'**
  String get enemyEscaped;

  /// No description provided for @bossAppear.
  ///
  /// In en, this message translates to:
  /// **'Boss Appeared!'**
  String get bossAppear;

  /// No description provided for @sensitivitySetting.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get sensitivitySetting;

  /// No description provided for @mapDataEmpty.
  ///
  /// In en, this message translates to:
  /// **'Map data is empty'**
  String get mapDataEmpty;

  /// No description provided for @boardDataEmpty.
  ///
  /// In en, this message translates to:
  /// **'Board data is empty'**
  String get boardDataEmpty;

  /// No description provided for @achFirstKill.
  ///
  /// In en, this message translates to:
  /// **'First Blood'**
  String get achFirstKill;

  /// No description provided for @achFirstKillDesc.
  ///
  /// In en, this message translates to:
  /// **'First enemy defeated'**
  String get achFirstKillDesc;

  /// No description provided for @achScore100.
  ///
  /// In en, this message translates to:
  /// **'Steel Will'**
  String get achScore100;

  /// No description provided for @achScore100Desc.
  ///
  /// In en, this message translates to:
  /// **'Score reaches 100'**
  String get achScore100Desc;

  /// No description provided for @achScore500.
  ///
  /// In en, this message translates to:
  /// **'Half Kingdom'**
  String get achScore500;

  /// No description provided for @achScore500Desc.
  ///
  /// In en, this message translates to:
  /// **'Score reaches 500'**
  String get achScore500Desc;

  /// No description provided for @achScore1000.
  ///
  /// In en, this message translates to:
  /// **'Veteran'**
  String get achScore1000;

  /// No description provided for @achScore1000Desc.
  ///
  /// In en, this message translates to:
  /// **'Score reaches 1000'**
  String get achScore1000Desc;

  /// No description provided for @achLevel5.
  ///
  /// In en, this message translates to:
  /// **'Level 5 Challenge'**
  String get achLevel5;

  /// No description provided for @achLevel5Desc.
  ///
  /// In en, this message translates to:
  /// **'Reach level 5'**
  String get achLevel5Desc;

  /// No description provided for @achLevel10.
  ///
  /// In en, this message translates to:
  /// **'Level 10 Master'**
  String get achLevel10;

  /// No description provided for @achLevel10Desc.
  ///
  /// In en, this message translates to:
  /// **'Reach level 10'**
  String get achLevel10Desc;

  /// No description provided for @achBossHunter.
  ///
  /// In en, this message translates to:
  /// **'Boss Hunter'**
  String get achBossHunter;

  /// No description provided for @achBossHunterDesc.
  ///
  /// In en, this message translates to:
  /// **'First BOSS defeated'**
  String get achBossHunterDesc;

  /// No description provided for @achEightKills.
  ///
  /// In en, this message translates to:
  /// **'Eight Streak'**
  String get achEightKills;

  /// No description provided for @achEightKillsDesc.
  ///
  /// In en, this message translates to:
  /// **'Defeat 8 enemies in a row'**
  String get achEightKillsDesc;

  /// No description provided for @towerDefense.
  ///
  /// In en, this message translates to:
  /// **'Tower Defense'**
  String get towerDefense;

  /// No description provided for @surrender.
  ///
  /// In en, this message translates to:
  /// **'Surrender'**
  String get surrender;

  /// No description provided for @startWave.
  ///
  /// In en, this message translates to:
  /// **'Start Wave'**
  String get startWave;

  /// No description provided for @netTowerDefense.
  ///
  /// In en, this message translates to:
  /// **'Net Tower Defense'**
  String get netTowerDefense;

  /// No description provided for @hp.
  ///
  /// In en, this message translates to:
  /// **'HP {cur}/{max}'**
  String hp(int cur, int max);

  /// No description provided for @hpMax.
  ///
  /// In en, this message translates to:
  /// **'HP {v}'**
  String hpMax(int v);

  /// No description provided for @goldCost.
  ///
  /// In en, this message translates to:
  /// **'{v}g'**
  String goldCost(int v);

  /// No description provided for @wavePrefix.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get wavePrefix;

  /// No description provided for @attack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get attack;

  /// No description provided for @parry.
  ///
  /// In en, this message translates to:
  /// **'Parry'**
  String get parry;

  /// No description provided for @skill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skill;

  /// No description provided for @escape.
  ///
  /// In en, this message translates to:
  /// **'Escape'**
  String get escape;

  /// No description provided for @pursuit.
  ///
  /// In en, this message translates to:
  /// **'Pursuit'**
  String get pursuit;

  /// No description provided for @victory.
  ///
  /// In en, this message translates to:
  /// **'Victory'**
  String get victory;

  /// No description provided for @defeat.
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get defeat;

  /// No description provided for @win.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get win;

  /// No description provided for @youWon.
  ///
  /// In en, this message translates to:
  /// **'You Won!'**
  String get youWon;

  /// No description provided for @youLost2.
  ///
  /// In en, this message translates to:
  /// **'You Lost...'**
  String get youLost2;

  /// No description provided for @youEscaped.
  ///
  /// In en, this message translates to:
  /// **'You escaped the battle'**
  String get youEscaped;

  /// No description provided for @opponentEscaped.
  ///
  /// In en, this message translates to:
  /// **'Opponent escaped'**
  String get opponentEscaped;

  /// No description provided for @yourTurnAct.
  ///
  /// In en, this message translates to:
  /// **'Your turn, take action'**
  String get yourTurnAct;

  /// No description provided for @enemyTurnWait.
  ///
  /// In en, this message translates to:
  /// **'Enemy\'s turn, please wait'**
  String get enemyTurnWait;

  /// No description provided for @choseAttack.
  ///
  /// In en, this message translates to:
  /// **'{name} chose Attack'**
  String choseAttack(String name);

  /// No description provided for @castSkill.
  ///
  /// In en, this message translates to:
  /// **'{src} cast {skill}\n{tgt} receives {desc}'**
  String castSkill(String src, String skill, String tgt, String desc);

  /// No description provided for @switchIn.
  ///
  /// In en, this message translates to:
  /// **'{name} enters'**
  String switchIn(String name);

  /// No description provided for @switchTo.
  ///
  /// In en, this message translates to:
  /// **'{from} switched to {to}'**
  String switchTo(String from, String to);

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelLabel;

  /// No description provided for @healthLabel.
  ///
  /// In en, this message translates to:
  /// **'HP'**
  String get healthLabel;

  /// No description provided for @attackLabel.
  ///
  /// In en, this message translates to:
  /// **'ATK'**
  String get attackLabel;

  /// No description provided for @defenceLabel.
  ///
  /// In en, this message translates to:
  /// **'DEF'**
  String get defenceLabel;

  /// No description provided for @selectEnergy.
  ///
  /// In en, this message translates to:
  /// **'Choose Energy'**
  String get selectEnergy;

  /// No description provided for @selectSkill.
  ///
  /// In en, this message translates to:
  /// **'Choose a Skill'**
  String get selectSkill;

  /// No description provided for @chooseEnergy.
  ///
  /// In en, this message translates to:
  /// **'Choose Energy:'**
  String get chooseEnergy;

  /// No description provided for @chooseAttribute.
  ///
  /// In en, this message translates to:
  /// **'Choose Attribute:'**
  String get chooseAttribute;

  /// No description provided for @enemyImp.
  ///
  /// In en, this message translates to:
  /// **'Imp'**
  String get enemyImp;

  /// No description provided for @enemyClown.
  ///
  /// In en, this message translates to:
  /// **'Clown'**
  String get enemyClown;

  /// No description provided for @enemyDemon.
  ///
  /// In en, this message translates to:
  /// **'Demon'**
  String get enemyDemon;

  /// No description provided for @enemyKing.
  ///
  /// In en, this message translates to:
  /// **'Demon King'**
  String get enemyKing;

  /// No description provided for @dummy.
  ///
  /// In en, this message translates to:
  /// **'Dummy'**
  String get dummy;

  /// No description provided for @traveler.
  ///
  /// In en, this message translates to:
  /// **'Traveler'**
  String get traveler;

  /// No description provided for @floorName.
  ///
  /// In en, this message translates to:
  /// **'B{v}'**
  String floorName(int v);

  /// No description provided for @mainCity.
  ///
  /// In en, this message translates to:
  /// **'Main City'**
  String get mainCity;

  /// No description provided for @returnedToCity.
  ///
  /// In en, this message translates to:
  /// **'Returned to Main City'**
  String get returnedToCity;

  /// No description provided for @notice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get notice;

  /// No description provided for @slept.
  ///
  /// In en, this message translates to:
  /// **'You slept and recovered'**
  String get slept;

  /// No description provided for @gotMedicine.
  ///
  /// In en, this message translates to:
  /// **'Got a potion'**
  String get gotMedicine;

  /// No description provided for @gotWeapon.
  ///
  /// In en, this message translates to:
  /// **'Got a weapon'**
  String get gotWeapon;

  /// No description provided for @gotArmor.
  ///
  /// In en, this message translates to:
  /// **'Got armor'**
  String get gotArmor;

  /// No description provided for @gotMoneyBag.
  ///
  /// In en, this message translates to:
  /// **'Got a money bag, {m} coins'**
  String gotMoneyBag(int m);

  /// No description provided for @cannotContinue.
  ///
  /// In en, this message translates to:
  /// **'Cannot continue adventure'**
  String get cannotContinue;

  /// No description provided for @levelUpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Level Up!'**
  String get levelUpSuccess;

  /// No description provided for @notEnoughExp.
  ///
  /// In en, this message translates to:
  /// **'Not enough EXP!'**
  String get notEnoughExp;

  /// No description provided for @backpack.
  ///
  /// In en, this message translates to:
  /// **'Backpack'**
  String get backpack;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @switchElement.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchElement;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// No description provided for @learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @passive.
  ///
  /// In en, this message translates to:
  /// **'Passive'**
  String get passive;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @configCharacter.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configCharacter;

  /// No description provided for @viewOpponent.
  ///
  /// In en, this message translates to:
  /// **'View Opponent'**
  String get viewOpponent;

  /// No description provided for @characterConfig.
  ///
  /// In en, this message translates to:
  /// **'Character Config'**
  String get characterConfig;

  /// No description provided for @remainingPoints.
  ///
  /// In en, this message translates to:
  /// **'Points: {v}'**
  String remainingPoints(int v);

  /// No description provided for @coinCount.
  ///
  /// In en, this message translates to:
  /// **'Coins: {v}'**
  String coinCount(int v);

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Name:{n}'**
  String itemName(String n);

  /// No description provided for @buySuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase Success'**
  String get buySuccess;

  /// No description provided for @notEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get notEnoughCoins;

  /// No description provided for @learnSuccess.
  ///
  /// In en, this message translates to:
  /// **'Learned!'**
  String get learnSuccess;

  /// No description provided for @skillTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {t}'**
  String skillTarget(String t);

  /// No description provided for @skillEffect.
  ///
  /// In en, this message translates to:
  /// **'Effect: {d}'**
  String skillEffect(String d);

  /// No description provided for @notYourTurn.
  ///
  /// In en, this message translates to:
  /// **'Not your turn'**
  String get notYourTurn;

  /// No description provided for @serverNotYourTurn.
  ///
  /// In en, this message translates to:
  /// **'\nServer: Not your turn\n'**
  String get serverNotYourTurn;

  /// No description provided for @exp.
  ///
  /// In en, this message translates to:
  /// **'EXP: {v}'**
  String exp(int v);

  /// No description provided for @lv.
  ///
  /// In en, this message translates to:
  /// **'Level: {v}'**
  String lv(int v);

  /// No description provided for @hpCap.
  ///
  /// In en, this message translates to:
  /// **'HP Cap: {v}'**
  String hpCap(int v);

  /// No description provided for @baseAtk.
  ///
  /// In en, this message translates to:
  /// **'Base ATK: {v}'**
  String baseAtk(int v);

  /// No description provided for @baseDef.
  ///
  /// In en, this message translates to:
  /// **'Base DEF: {v}'**
  String baseDef(int v);

  /// No description provided for @curHp.
  ///
  /// In en, this message translates to:
  /// **'Cur HP: {v}'**
  String curHp(int v);

  /// No description provided for @curAtk.
  ///
  /// In en, this message translates to:
  /// **'Cur ATK: {v}'**
  String curAtk(int v);

  /// No description provided for @curDef.
  ///
  /// In en, this message translates to:
  /// **'Cur DEF: {v}'**
  String curDef(int v);

  /// No description provided for @masteredSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills:'**
  String get masteredSkills;

  /// No description provided for @activeEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects:'**
  String get activeEffects;

  /// No description provided for @potion.
  ///
  /// In en, this message translates to:
  /// **'Potion'**
  String get potion;

  /// No description provided for @potionDesc.
  ///
  /// In en, this message translates to:
  /// **'HP +32'**
  String get potionDesc;

  /// No description provided for @sword.
  ///
  /// In en, this message translates to:
  /// **'Sword'**
  String get sword;

  /// No description provided for @swordDesc.
  ///
  /// In en, this message translates to:
  /// **'ATK +8'**
  String get swordDesc;

  /// No description provided for @shield.
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get shield;

  /// No description provided for @shieldDesc.
  ///
  /// In en, this message translates to:
  /// **'DEF +8'**
  String get shieldDesc;

  /// No description provided for @scroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get scroll;

  /// No description provided for @scrollDesc.
  ///
  /// In en, this message translates to:
  /// **'Return home anytime'**
  String get scrollDesc;

  /// No description provided for @targetSelfFront.
  ///
  /// In en, this message translates to:
  /// **'Self Front'**
  String get targetSelfFront;

  /// No description provided for @targetSelfAny.
  ///
  /// In en, this message translates to:
  /// **'Self Any'**
  String get targetSelfAny;

  /// No description provided for @targetEnemyFront.
  ///
  /// In en, this message translates to:
  /// **'Enemy Front'**
  String get targetEnemyFront;

  /// No description provided for @targetEnemyAny.
  ///
  /// In en, this message translates to:
  /// **'Enemy Any'**
  String get targetEnemyAny;

  /// No description provided for @skParry.
  ///
  /// In en, this message translates to:
  /// **'Parry'**
  String get skParry;

  /// No description provided for @skParryDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce damage by 75%, once.'**
  String get skParryDesc;

  /// No description provided for @skMetalP0.
  ///
  /// In en, this message translates to:
  /// **'Balanced Force'**
  String get skMetalP0;

  /// No description provided for @skMetalP0Desc.
  ///
  /// In en, this message translates to:
  /// **'+50% ATK and DEF in combat.'**
  String get skMetalP0Desc;

  /// No description provided for @skWoodP0.
  ///
  /// In en, this message translates to:
  /// **'Life Drain'**
  String get skWoodP0;

  /// No description provided for @skWoodP0Desc.
  ///
  /// In en, this message translates to:
  /// **'Heal 25% of damage dealt.'**
  String get skWoodP0Desc;

  /// No description provided for @skWaterP0.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Flow'**
  String get skWaterP0;

  /// No description provided for @skWaterP0Desc.
  ///
  /// In en, this message translates to:
  /// **'After taking damage, lose DEF, gain 75% of lost DEF as ATK. Magic damage also enchants.\n\nWater adapts to its container.'**
  String get skWaterP0Desc;

  /// No description provided for @skFireP0.
  ///
  /// In en, this message translates to:
  /// **'Ignite'**
  String get skFireP0;

  /// No description provided for @skFireP0Desc.
  ///
  /// In en, this message translates to:
  /// **'100% enchant, all damage ignores defense.\n\nIt\'s on fire.'**
  String get skFireP0Desc;

  /// No description provided for @skEarthP0.
  ///
  /// In en, this message translates to:
  /// **'Accumulate'**
  String get skEarthP0;

  /// No description provided for @skEarthP0Desc.
  ///
  /// In en, this message translates to:
  /// **'After damage: +50% physical, +15% magic as ATK bonus.\n\nEarth remembers all.'**
  String get skEarthP0Desc;

  /// No description provided for @skMetalA0.
  ///
  /// In en, this message translates to:
  /// **'Retreat to Advance'**
  String get skMetalA0;

  /// No description provided for @skMetalA0Desc.
  ///
  /// In en, this message translates to:
  /// **'Extra attack next turn, once.'**
  String get skMetalA0Desc;

  /// No description provided for @skWoodA0.
  ///
  /// In en, this message translates to:
  /// **'Deep Roots'**
  String get skWoodA0;

  /// No description provided for @skWoodA0Desc.
  ///
  /// In en, this message translates to:
  /// **'Heal 12.5% max HP, once.'**
  String get skWoodA0Desc;

  /// No description provided for @skWaterA0.
  ///
  /// In en, this message translates to:
  /// **'Slow Down'**
  String get skWaterA0;

  /// No description provided for @skWaterA0Desc.
  ///
  /// In en, this message translates to:
  /// **'Reduce enemy ATK by 50%, twice.'**
  String get skWaterA0Desc;

  /// No description provided for @skFireA0.
  ///
  /// In en, this message translates to:
  /// **'Explosion'**
  String get skFireA0;

  /// No description provided for @skFireA0Desc.
  ///
  /// In en, this message translates to:
  /// **'HP to 1, boost damage by ratio, attack once.\n\nExplosion!'**
  String get skFireA0Desc;

  /// No description provided for @skEarthA0.
  ///
  /// In en, this message translates to:
  /// **'Immovable'**
  String get skEarthA0;

  /// No description provided for @skEarthA0Desc.
  ///
  /// In en, this message translates to:
  /// **'Counter-attack when hit.\nForce is mutual.'**
  String get skEarthA0Desc;

  /// No description provided for @skMetalAdv0.
  ///
  /// In en, this message translates to:
  /// **'Wait and See'**
  String get skMetalAdv0;

  /// No description provided for @skMetalAdv0Desc.
  ///
  /// In en, this message translates to:
  /// **'Retreat to Advance targets any ally.'**
  String get skMetalAdv0Desc;

  /// No description provided for @skWoodAdv0.
  ///
  /// In en, this message translates to:
  /// **'Spread Roots'**
  String get skWoodAdv0;

  /// No description provided for @skWoodAdv0Desc.
  ///
  /// In en, this message translates to:
  /// **'Deep Roots targets any ally.'**
  String get skWoodAdv0Desc;

  /// No description provided for @skWaterAdv0.
  ///
  /// In en, this message translates to:
  /// **'Tight Seal'**
  String get skWaterAdv0;

  /// No description provided for @skWaterAdv0Desc.
  ///
  /// In en, this message translates to:
  /// **'Slow Down targets any enemy.'**
  String get skWaterAdv0Desc;

  /// No description provided for @skFireAdv0.
  ///
  /// In en, this message translates to:
  /// **'Pass the Torch'**
  String get skFireAdv0;

  /// No description provided for @skFireAdv0Desc.
  ///
  /// In en, this message translates to:
  /// **'Explosion targets any ally.'**
  String get skFireAdv0Desc;

  /// No description provided for @skEarthAdv0.
  ///
  /// In en, this message translates to:
  /// **'Mutual Destruction'**
  String get skEarthAdv0;

  /// No description provided for @skEarthAdv0Desc.
  ///
  /// In en, this message translates to:
  /// **'Immovable targets any ally.'**
  String get skEarthAdv0Desc;

  /// No description provided for @skMetalAux0.
  ///
  /// In en, this message translates to:
  /// **'Full Arms'**
  String get skMetalAux0;

  /// No description provided for @skMetalAux0Desc.
  ///
  /// In en, this message translates to:
  /// **'+50% ATK and DEF, twice.'**
  String get skMetalAux0Desc;

  /// No description provided for @skWoodAux0.
  ///
  /// In en, this message translates to:
  /// **'Graft'**
  String get skWoodAux0;

  /// No description provided for @skWoodAux0Desc.
  ///
  /// In en, this message translates to:
  /// **'Heal 25% of damage dealt, twice.'**
  String get skWoodAux0Desc;

  /// No description provided for @skWaterAux0.
  ///
  /// In en, this message translates to:
  /// **'Adapt'**
  String get skWaterAux0;

  /// No description provided for @skWaterAux0Desc.
  ///
  /// In en, this message translates to:
  /// **'Lose DEF, gain 75% as ATK, twice.\n\nWater flows with the land.'**
  String get skWaterAux0Desc;

  /// No description provided for @skFireAux0.
  ///
  /// In en, this message translates to:
  /// **'Full Firepower'**
  String get skFireAux0;

  /// No description provided for @skFireAux0Desc.
  ///
  /// In en, this message translates to:
  /// **'100% enchant, twice.\n\nUse Fire Fist!'**
  String get skFireAux0Desc;

  /// No description provided for @skEarthAux0.
  ///
  /// In en, this message translates to:
  /// **'Comeback'**
  String get skEarthAux0;

  /// No description provided for @skEarthAux0Desc.
  ///
  /// In en, this message translates to:
  /// **'+50% phys, +15% magic as ATK, twice.'**
  String get skEarthAux0Desc;

  /// No description provided for @skMetalF0.
  ///
  /// In en, this message translates to:
  /// **'Dragon Slayer'**
  String get skMetalF0;

  /// No description provided for @skMetalF0Desc.
  ///
  /// In en, this message translates to:
  /// **'+ATK based on 25% enemy HP, once.'**
  String get skMetalF0Desc;

  /// No description provided for @skWoodF0.
  ///
  /// In en, this message translates to:
  /// **'Shackle'**
  String get skWoodF0;

  /// No description provided for @skWoodF0Desc.
  ///
  /// In en, this message translates to:
  /// **'Overflow healing increases max HP.'**
  String get skWoodF0Desc;

  /// No description provided for @skWaterF0.
  ///
  /// In en, this message translates to:
  /// **'Still Water'**
  String get skWaterF0;

  /// No description provided for @skWaterF0Desc.
  ///
  /// In en, this message translates to:
  /// **'Survive lethal damage at 1 HP, once.\n\nJust a scratch.'**
  String get skWaterF0Desc;

  /// No description provided for @skFireF0.
  ///
  /// In en, this message translates to:
  /// **'Scorch'**
  String get skFireF0;

  /// No description provided for @skFireF0Desc.
  ///
  /// In en, this message translates to:
  /// **'Magic burns enemy, +25% damage on next hit, twice.\n\nAmaterasu.'**
  String get skFireF0Desc;

  /// No description provided for @skEarthF0.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get skEarthF0;

  /// No description provided for @skEarthF0Desc.
  ///
  /// In en, this message translates to:
  /// **'On hit: 25% lost HP as ATK, 25% multiplier, twice.'**
  String get skEarthF0Desc;

  /// No description provided for @healLog.
  ///
  /// In en, this message translates to:
  /// **'{name} healed {actual} HP, now {hp}'**
  String healLog(String name, int actual, int hp);

  /// No description provided for @selfDamageLog.
  ///
  /// In en, this message translates to:
  /// **'{name} took {dmg} self damage, damage multiplier increased'**
  String selfDamageLog(String name, int dmg);

  /// No description provided for @damageLogPhysical.
  ///
  /// In en, this message translates to:
  /// **'{name} took {dmg} physical damage, HP {hp}'**
  String damageLogPhysical(String name, int dmg, int hp);

  /// No description provided for @damageLogMagic.
  ///
  /// In en, this message translates to:
  /// **'{name} took {dmg} magic damage, HP {hp}'**
  String damageLogMagic(String name, int dmg, int hp);

  /// No description provided for @mapDataEmpty2.
  ///
  /// In en, this message translates to:
  /// **'Map data is empty'**
  String get mapDataEmpty2;

  /// No description provided for @boardDataEmpty2.
  ///
  /// In en, this message translates to:
  /// **'Board data is empty'**
  String get boardDataEmpty2;

  /// No description provided for @roomTypeChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get roomTypeChat;

  /// No description provided for @elementalBattle.
  ///
  /// In en, this message translates to:
  /// **'Elemental Battle'**
  String get elementalBattle;

  /// No description provided for @greedySnake.
  ///
  /// In en, this message translates to:
  /// **'Greedy Snake'**
  String get greedySnake;

  /// No description provided for @soft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get soft;

  /// No description provided for @minecraft.
  ///
  /// In en, this message translates to:
  /// **'Minecraft'**
  String get minecraft;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
