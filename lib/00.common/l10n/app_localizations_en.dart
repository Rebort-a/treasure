// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get clear => 'Clear';

  @override
  String get exit => 'Exit';

  @override
  String get restart => 'Restart';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get stop => 'Stop';

  @override
  String get stopAll => 'STOP ALL';

  @override
  String get gameOver => 'Game Over';

  @override
  String get selectOption => 'Select Option';

  @override
  String currentValue(String v) {
    return 'Current: $v';
  }

  @override
  String get roomList => 'Room List';

  @override
  String get local => 'Local';

  @override
  String get createdRooms => 'The rooms you created';

  @override
  String get otherRooms => 'The other rooms';

  @override
  String get createRoom => 'Create Room';

  @override
  String get enterRoomName => 'Enter room name';

  @override
  String get joinRoom => 'Join Room';

  @override
  String get joinByIp => 'Join by IP';

  @override
  String get enterUserName => 'Enter user name';

  @override
  String get userName => 'User name';

  @override
  String get hostIp => 'Host IP';

  @override
  String get port => 'Port';

  @override
  String get game => 'Game';

  @override
  String get type => 'Type';

  @override
  String get leave => 'Leave';

  @override
  String get leaveRoom => 'About to leave the room';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get roomClosed => 'Room closed';

  @override
  String get cannotReconnect => 'Cannot reconnect to server';

  @override
  String reconnecting(int cur, int max) {
    return 'Reconnecting... ($cur/$max)';
  }

  @override
  String get competitorsWithdraw => 'Opponent Left';

  @override
  String get opponentWithdrawn => 'The opponent has withdrawn';

  @override
  String get typeMessage => 'Type a message';

  @override
  String get wait => 'Wait';

  @override
  String get youSurrendered => 'You Surrendered';

  @override
  String get opponentSurrendered => 'Opponent Surrendered';

  @override
  String get chatRoom => 'Chat Room';

  @override
  String get online => 'Online';

  @override
  String get connecting => 'Connecting...';

  @override
  String get members => 'Members';

  @override
  String get chatSettings => 'Chat Settings';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get clearHistoryConfirm =>
      'Clear all chat history? This cannot be undone.';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get messageNotification => 'Notifications';

  @override
  String get attachment => 'Attachment';

  @override
  String get album => 'Album';

  @override
  String get camera => 'Camera';

  @override
  String get file => 'File';

  @override
  String get location => 'Location';

  @override
  String get imageLoadFailed => 'Image load failed';

  @override
  String get unknownFile => 'Unknown file';

  @override
  String get selectImageFailed => 'Failed to select image';

  @override
  String get takePhotoFailed => 'Failed to take photo';

  @override
  String get sendImageFailed => 'Failed to send image';

  @override
  String get selectFileFailed => 'Failed to select file';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get saveSuccess => 'File saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get savedTo => 'Saved to';

  @override
  String get downloading => 'Saving...';

  @override
  String get emojiCommon => 'Common';

  @override
  String get emojiGesture => 'Gestures';

  @override
  String get emojiHeart => 'Hearts';

  @override
  String get emojiAnimal => 'Animals';

  @override
  String get emojiFood => 'Food';

  @override
  String get emojiSport => 'Sports';

  @override
  String get emojiTravel => 'Travel';

  @override
  String get emojiSymbol => 'Symbols';

  @override
  String get stepDisconnect => 'Waiting to connect';

  @override
  String get stepConnected => 'Connected, waiting for opponent...';

  @override
  String get stepFrontConfig => 'Please configure';

  @override
  String get stepRearWait => 'Waiting for first player config';

  @override
  String get stepFrontWait => 'Waiting for second player config';

  @override
  String get stepRearConfig => 'Configure or view opponent config';

  @override
  String get stepAction => 'In Progress';

  @override
  String get stepGameOver => 'Game Over';

  @override
  String get animalChess => 'Animal Chess';

  @override
  String get netAnimalChess => 'Net Animal Chess';

  @override
  String get setBoardSize => 'Set Board Size';

  @override
  String get redTurn => 'Red\'s Turn';

  @override
  String get blueTurn => 'Blue\'s Turn';

  @override
  String get yourTurn => 'Your Turn';

  @override
  String get opponentTurn => 'Opponent\'s Turn';

  @override
  String get redWin => 'Red Wins!';

  @override
  String get blueWin => 'Blue Wins!';

  @override
  String get gobang => 'Gomoku';

  @override
  String get netGobang => 'Net Gomoku';

  @override
  String get blackSide => 'Black';

  @override
  String get whiteSide => 'White';

  @override
  String currentTurn(String side) {
    return 'Current Turn: $side';
  }

  @override
  String sideWin(String side) {
    return '$side Wins!';
  }

  @override
  String yourSideTurn(String side) {
    return 'Your Turn $side';
  }

  @override
  String opponentSideTurn(String side) {
    return 'Opponent\'s Turn $side';
  }

  @override
  String get aiLabel => 'AI';

  @override
  String get aiThinking => 'AI Thinking…';

  @override
  String get undo => 'Undo';

  @override
  String get weiqi => 'Go';

  @override
  String get finalLength => 'Final Length';

  @override
  String get sudoku => 'Sudoku';

  @override
  String get setDifficulty => 'Set Difficulty';

  @override
  String get pleaseConfirm => 'Please Confirm';

  @override
  String get leaveRoomLoseProgress => 'Leaving will lose progress';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String difficultyTime(String d, String t) {
    return 'Difficulty: $d Time: $t';
  }

  @override
  String get startNewGame => 'Start New Game';

  @override
  String get importPuzzle => 'Import Puzzle';

  @override
  String get importFailConflict =>
      'Board has conflicts. Check rows, columns and boxes for duplicates.';

  @override
  String get importFailEmpty => 'Fill in at least one number.';

  @override
  String get importFailNotUnique =>
      'The puzzle has no unique solution. Adjust the numbers.';

  @override
  String get confirmImport => 'Confirm';

  @override
  String get cancelImport => 'Cancel';

  @override
  String get guess => 'Guess';

  @override
  String timeTaken(int s) {
    return 'Time Taken: $s seconds';
  }

  @override
  String correctCount(int c) {
    return 'Correct Count: $c';
  }

  @override
  String get memoryCard => 'Memory Match';

  @override
  String remainingPairs(int v) {
    return 'Remaining $v pairs';
  }

  @override
  String get bestTimeLabel => 'Best Time';

  @override
  String get schulte => 'Schulte';

  @override
  String nextNumber(int v) {
    return 'Next: $v';
  }

  @override
  String get threeTiles => '3tiles';

  @override
  String timeSeconds(int v) {
    return 'Time: $v s';
  }

  @override
  String remaining(int v) {
    return 'Remaining: $v';
  }

  @override
  String get youLost => 'You Lost';

  @override
  String get chooseDifficulty => 'Choose Difficulty';

  @override
  String get easy => 'Easy';

  @override
  String get medium => 'Medium';

  @override
  String get hard => 'Hard';

  @override
  String difficultyTimeSeconds(String d, int t) {
    return 'Difficulty: $d Time: $t s';
  }

  @override
  String get spaceship => 'Space Ship';

  @override
  String lives(double v) {
    return 'Lives: $v';
  }

  @override
  String score(int v) {
    return 'Score: $v';
  }

  @override
  String level(int v) {
    return 'Level: $v';
  }

  @override
  String get startGame => 'Start Game';

  @override
  String get gamePaused => 'Game Paused';

  @override
  String get continueGame => 'Continue';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'General';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get restartGame => 'Restart';

  @override
  String get exitGame => 'Exit Game';

  @override
  String get levelUp => 'Level Up';

  @override
  String currentLevel(int v) {
    return 'Current Level: $v';
  }

  @override
  String get harderChallenge => 'Ready for harder challenges!';

  @override
  String get finalScore => 'Final Score';

  @override
  String get reachedLevel => 'Reached Level';

  @override
  String get unlockedAchievement => 'Unlocked Achievement';

  @override
  String get playAgain => 'Play Again';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get noAchievements => 'No achievements unlocked';

  @override
  String get enemyEscaped => 'Enemy Escaped!';

  @override
  String get bossAppear => 'Boss Appeared!';

  @override
  String get sensitivitySetting => 'Sensitivity';

  @override
  String get mapDataEmpty => 'Map data is empty';

  @override
  String get boardDataEmpty => 'Board data is empty';

  @override
  String get achFirstKill => 'First Blood';

  @override
  String get achFirstKillDesc => 'First enemy defeated';

  @override
  String get achScore100 => 'Steel Will';

  @override
  String get achScore100Desc => 'Score reaches 100';

  @override
  String get achScore500 => 'Half Kingdom';

  @override
  String get achScore500Desc => 'Score reaches 500';

  @override
  String get achScore1000 => 'Veteran';

  @override
  String get achScore1000Desc => 'Score reaches 1000';

  @override
  String get achLevel5 => 'Level 5 Challenge';

  @override
  String get achLevel5Desc => 'Reach level 5';

  @override
  String get achLevel10 => 'Level 10 Master';

  @override
  String get achLevel10Desc => 'Reach level 10';

  @override
  String get achBossHunter => 'Boss Hunter';

  @override
  String get achBossHunterDesc => 'First BOSS defeated';

  @override
  String get achEightKills => 'Eight Streak';

  @override
  String get achEightKillsDesc => 'Defeat 8 enemies in a row';

  @override
  String get towerDefense => 'Tower Defense';

  @override
  String get surrender => 'Surrender';

  @override
  String get startWave => 'Start Wave';

  @override
  String get netTowerDefense => 'Net Tower Defense';

  @override
  String hp(int cur, int max) {
    return 'HP $cur/$max';
  }

  @override
  String hpMax(int v) {
    return 'HP $v';
  }

  @override
  String goldCost(int v) {
    return '${v}g';
  }

  @override
  String get wavePrefix => 'W';

  @override
  String get attack => 'Attack';

  @override
  String get parry => 'Parry';

  @override
  String get skill => 'Skill';

  @override
  String get escape => 'Escape';

  @override
  String get pursuit => 'Pursuit';

  @override
  String get victory => 'Victory';

  @override
  String get defeat => 'Defeat';

  @override
  String get win => 'Win';

  @override
  String get youWon => 'You Won!';

  @override
  String get youLost2 => 'You Lost...';

  @override
  String get youEscaped => 'You escaped the battle';

  @override
  String get opponentEscaped => 'Opponent escaped';

  @override
  String get yourTurnAct => 'Your turn, take action';

  @override
  String get enemyTurnWait => 'Enemy\'s turn, please wait';

  @override
  String choseAttack(String name) {
    return '$name chose Attack';
  }

  @override
  String castSkill(String src, String skill, String tgt, String desc) {
    return '$src cast $skill\n$tgt receives $desc';
  }

  @override
  String switchIn(String name) {
    return '$name enters';
  }

  @override
  String switchTo(String from, String to) {
    return '$from switched to $to';
  }

  @override
  String get levelLabel => 'Level';

  @override
  String get healthLabel => 'HP';

  @override
  String get attackLabel => 'ATK';

  @override
  String get defenceLabel => 'DEF';

  @override
  String get selectEnergy => 'Choose Energy';

  @override
  String get selectSkill => 'Choose a Skill';

  @override
  String get chooseEnergy => 'Choose Energy:';

  @override
  String get chooseAttribute => 'Choose Attribute:';

  @override
  String get enemyImp => 'Imp';

  @override
  String get enemyClown => 'Clown';

  @override
  String get enemyDemon => 'Demon';

  @override
  String get enemyKing => 'Demon King';

  @override
  String get dummy => 'Dummy';

  @override
  String get traveler => 'Traveler';

  @override
  String floorName(int v) {
    return 'B$v';
  }

  @override
  String get mainCity => 'Main City';

  @override
  String get returnedToCity => 'Returned to Main City';

  @override
  String get notice => 'Notice';

  @override
  String get slept => 'You slept and recovered';

  @override
  String get gotMedicine => 'Got a potion';

  @override
  String get gotWeapon => 'Got a weapon';

  @override
  String get gotArmor => 'Got armor';

  @override
  String gotMoneyBag(int m) {
    return 'Got a money bag, $m coins';
  }

  @override
  String get cannotContinue => 'Cannot continue adventure';

  @override
  String get levelUpSuccess => 'Level Up!';

  @override
  String get notEnoughExp => 'Not enough EXP!';

  @override
  String get backpack => 'Backpack';

  @override
  String get status => 'Status';

  @override
  String get switchElement => 'Switch';

  @override
  String get store => 'Store';

  @override
  String get buy => 'Buy';

  @override
  String get use => 'Use';

  @override
  String get learn => 'Learn';

  @override
  String get forget => 'Forget';

  @override
  String get active => 'Active';

  @override
  String get passive => 'Passive';

  @override
  String get preparing => 'Preparing';

  @override
  String get configCharacter => 'Configure';

  @override
  String get viewOpponent => 'View Opponent';

  @override
  String get characterConfig => 'Character Config';

  @override
  String remainingPoints(int v) {
    return 'Points: $v';
  }

  @override
  String coinCount(int v) {
    return 'Coins: $v';
  }

  @override
  String itemName(String n) {
    return 'Name:$n';
  }

  @override
  String get buySuccess => 'Purchase Success';

  @override
  String get notEnoughCoins => 'Not enough coins';

  @override
  String get learnSuccess => 'Learned!';

  @override
  String skillTarget(String t) {
    return 'Target: $t';
  }

  @override
  String skillEffect(String d) {
    return 'Effect: $d';
  }

  @override
  String get notYourTurn => 'Not your turn';

  @override
  String get serverNotYourTurn => '\nServer: Not your turn\n';

  @override
  String exp(int v) {
    return 'EXP: $v';
  }

  @override
  String lv(int v) {
    return 'Level: $v';
  }

  @override
  String hpCap(int v) {
    return 'HP Cap: $v';
  }

  @override
  String baseAtk(int v) {
    return 'Base ATK: $v';
  }

  @override
  String baseDef(int v) {
    return 'Base DEF: $v';
  }

  @override
  String curHp(int v) {
    return 'Cur HP: $v';
  }

  @override
  String curAtk(int v) {
    return 'Cur ATK: $v';
  }

  @override
  String curDef(int v) {
    return 'Cur DEF: $v';
  }

  @override
  String get masteredSkills => 'Skills:';

  @override
  String get activeEffects => 'Effects:';

  @override
  String get potion => 'Potion';

  @override
  String get potionDesc => 'HP +32';

  @override
  String get sword => 'Sword';

  @override
  String get swordDesc => 'ATK +8';

  @override
  String get shield => 'Shield';

  @override
  String get shieldDesc => 'DEF +8';

  @override
  String get scroll => 'Scroll';

  @override
  String get scrollDesc => 'Return home anytime';

  @override
  String get targetSelfFront => 'Self Front';

  @override
  String get targetSelfAny => 'Self Any';

  @override
  String get targetEnemyFront => 'Enemy Front';

  @override
  String get targetEnemyAny => 'Enemy Any';

  @override
  String get skParry => 'Parry';

  @override
  String get skParryDesc => 'Reduce damage by 75%, once.';

  @override
  String get skMetalP0 => 'Balanced Force';

  @override
  String get skMetalP0Desc => '+50% ATK and DEF in combat.';

  @override
  String get skWoodP0 => 'Life Drain';

  @override
  String get skWoodP0Desc => 'Heal 25% of damage dealt.';

  @override
  String get skWaterP0 => 'Adaptive Flow';

  @override
  String get skWaterP0Desc =>
      'After taking damage, lose DEF, gain 75% of lost DEF as ATK. Magic damage also enchants.\n\nWater adapts to its container.';

  @override
  String get skFireP0 => 'Ignite';

  @override
  String get skFireP0Desc =>
      '100% enchant, all damage ignores defense.\n\nIt\'s on fire.';

  @override
  String get skEarthP0 => 'Accumulate';

  @override
  String get skEarthP0Desc =>
      'After damage: +50% physical, +15% magic as ATK bonus.\n\nEarth remembers all.';

  @override
  String get skMetalA0 => 'Retreat to Advance';

  @override
  String get skMetalA0Desc => 'Extra attack next turn, once.';

  @override
  String get skWoodA0 => 'Deep Roots';

  @override
  String get skWoodA0Desc => 'Heal 12.5% max HP, once.';

  @override
  String get skWaterA0 => 'Slow Down';

  @override
  String get skWaterA0Desc => 'Reduce enemy ATK by 50%, twice.';

  @override
  String get skFireA0 => 'Explosion';

  @override
  String get skFireA0Desc =>
      'HP to 1, boost damage by ratio, attack once.\n\nExplosion!';

  @override
  String get skEarthA0 => 'Immovable';

  @override
  String get skEarthA0Desc => 'Counter-attack when hit.\nForce is mutual.';

  @override
  String get skMetalAdv0 => 'Wait and See';

  @override
  String get skMetalAdv0Desc => 'Retreat to Advance targets any ally.';

  @override
  String get skWoodAdv0 => 'Spread Roots';

  @override
  String get skWoodAdv0Desc => 'Deep Roots targets any ally.';

  @override
  String get skWaterAdv0 => 'Tight Seal';

  @override
  String get skWaterAdv0Desc => 'Slow Down targets any enemy.';

  @override
  String get skFireAdv0 => 'Pass the Torch';

  @override
  String get skFireAdv0Desc => 'Explosion targets any ally.';

  @override
  String get skEarthAdv0 => 'Mutual Destruction';

  @override
  String get skEarthAdv0Desc => 'Immovable targets any ally.';

  @override
  String get skMetalAux0 => 'Full Arms';

  @override
  String get skMetalAux0Desc => '+50% ATK and DEF, twice.';

  @override
  String get skWoodAux0 => 'Graft';

  @override
  String get skWoodAux0Desc => 'Heal 25% of damage dealt, twice.';

  @override
  String get skWaterAux0 => 'Adapt';

  @override
  String get skWaterAux0Desc =>
      'Lose DEF, gain 75% as ATK, twice.\n\nWater flows with the land.';

  @override
  String get skFireAux0 => 'Full Firepower';

  @override
  String get skFireAux0Desc => '100% enchant, twice.\n\nUse Fire Fist!';

  @override
  String get skEarthAux0 => 'Comeback';

  @override
  String get skEarthAux0Desc => '+50% phys, +15% magic as ATK, twice.';

  @override
  String get skMetalF0 => 'Dragon Slayer';

  @override
  String get skMetalF0Desc => '+ATK based on 25% enemy HP, once.';

  @override
  String get skWoodF0 => 'Shackle';

  @override
  String get skWoodF0Desc => 'Overflow healing increases max HP.';

  @override
  String get skWaterF0 => 'Still Water';

  @override
  String get skWaterF0Desc =>
      'Survive lethal damage at 1 HP, once.\n\nJust a scratch.';

  @override
  String get skFireF0 => 'Scorch';

  @override
  String get skFireF0Desc =>
      'Magic burns enemy, +25% damage on next hit, twice.\n\nAmaterasu.';

  @override
  String get skEarthF0 => 'Sharpen';

  @override
  String get skEarthF0Desc =>
      'On hit: 25% lost HP as ATK, 25% multiplier, twice.';

  @override
  String healLog(String name, int actual, int hp) {
    return '$name healed $actual HP, now $hp';
  }

  @override
  String selfDamageLog(String name, int dmg) {
    return '$name took $dmg self damage, damage multiplier increased';
  }

  @override
  String damageLogPhysical(String name, int dmg, int hp) {
    return '$name took $dmg physical damage, HP $hp';
  }

  @override
  String damageLogMagic(String name, int dmg, int hp) {
    return '$name took $dmg magic damage, HP $hp';
  }

  @override
  String get mapDataEmpty2 => 'Map data is empty';

  @override
  String get boardDataEmpty2 => 'Board data is empty';

  @override
  String get roomTypeChat => 'Chat';

  @override
  String get elementalBattle => 'Elemental Battle';

  @override
  String get greedySnake => 'Greedy Snake';

  @override
  String get soft => 'Soft';

  @override
  String get minecraft => 'Minecraft';
}
