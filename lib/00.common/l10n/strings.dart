import 'app_localizations.dart';

import 'l10n.dart';

/// 全局翻译服务，无需 BuildContext。
///
/// 薄门面：委托给由 gen-l10n 生成的 [AppLocalizations]（翻译源为
/// lib/00.common/l10n/app_en.arb / app_zh.arb）。实例由 [LanguageProvider] 持有并随
/// 语言切换重载，故 base / middle / upper 各层均可无 context 访问本地化字符串。
/// 修改文案请编辑 ARB 文件，而非本文件。
class S {
  S._();

  static AppLocalizations get _l => LanguageProvider.instance.current;

  // ==================== 通用 ====================
  static String get confirm => _l.confirm;
  static String get cancel => _l.cancel;
  static String get close => _l.close;
  static String get ok => _l.ok;
  static String get clear => _l.clear;
  static String get exit => _l.exit;
  static String get restart => _l.restart;
  static String get create => _l.create;
  static String get join => _l.join;
  static String get stop => _l.stop;
  static String get stopAll => _l.stopAll;
  static String get gameOver => _l.gameOver;
  static String get selectOption => _l.selectOption;
  static String currentValue(String v) => _l.currentValue(v);

  // ==================== 首页 ====================
  static String get roomList => _l.roomList;
  static String get local => _l.local;
  static String get createdRooms => _l.createdRooms;
  static String get otherRooms => _l.otherRooms;
  static String get createRoom => _l.createRoom;
  static String get enterRoomName => _l.enterRoomName;
  static String get joinRoom => _l.joinRoom;
  static String get joinByIp => _l.joinByIp;
  static String get enterUserName => _l.enterUserName;
  static String get userName => _l.userName;
  static String get hostIp => _l.hostIp;
  static String get port => _l.port;
  static String get game => _l.game;
  static String get type => _l.type;
  static String get leave => _l.leave;
  static String get leaveRoom => _l.leaveRoom;
  static String get language => _l.language;
  static String get theme => _l.theme;
  static String get themeLight => _l.themeLight;
  static String get themeDark => _l.themeDark;
  static String get chinese => _l.chinese;
  static String get english => _l.english;

  // ==================== 通用网络 ====================
  static String get disconnected => _l.disconnected;
  static String get roomClosed => _l.roomClosed;
  static String get cannotReconnect => _l.cannotReconnect;
  static String reconnecting(int cur, int max) => _l.reconnecting(cur, max);
  static String get competitorsWithdraw => _l.competitorsWithdraw;
  static String get opponentWithdrawn => _l.opponentWithdrawn;
  static String get typeMessage => _l.typeMessage;
  static String get wait => _l.wait;
  static String get youSurrendered => _l.youSurrendered;
  static String get opponentSurrendered => _l.opponentSurrendered;

  // ==================== 聊天 ====================
  static String get chatRoom => _l.chatRoom;
  static String get online => _l.online;
  static String get connecting => _l.connecting;
  static String get members => _l.members;
  static String get chatSettings => _l.chatSettings;
  static String get clearHistory => _l.clearHistory;
  static String get clearHistoryConfirm => _l.clearHistoryConfirm;
  static String get darkMode => _l.darkMode;
  static String get messageNotification => _l.messageNotification;
  static String get attachment => _l.attachment;
  static String get album => _l.album;
  static String get camera => _l.camera;
  static String get file => _l.file;
  static String get location => _l.location;
  static String get imageLoadFailed => _l.imageLoadFailed;
  static String get unknownFile => _l.unknownFile;
  static String get selectImageFailed => _l.selectImageFailed;
  static String get takePhotoFailed => _l.takePhotoFailed;
  static String get sendImageFailed => _l.sendImageFailed;
  static String get selectFileFailed => _l.selectFileFailed;
  static String get today => _l.today;
  static String get yesterday => _l.yesterday;
  static String get saveSuccess => _l.saveSuccess;
  static String get saveFailed => _l.saveFailed;
  static String get savedTo => _l.savedTo;
  static String get downloading => _l.downloading;

  // ==================== 表情分类 ====================
  static String get emojiCommon => _l.emojiCommon;
  static String get emojiGesture => _l.emojiGesture;
  static String get emojiHeart => _l.emojiHeart;
  static String get emojiAnimal => _l.emojiAnimal;
  static String get emojiFood => _l.emojiFood;
  static String get emojiSport => _l.emojiSport;
  static String get emojiTravel => _l.emojiTravel;
  static String get emojiSymbol => _l.emojiSymbol;

  // ==================== 游戏步骤 ====================
  static String get stepDisconnect => _l.stepDisconnect;
  static String get stepConnected => _l.stepConnected;
  static String get stepFrontConfig => _l.stepFrontConfig;
  static String get stepRearWait => _l.stepRearWait;
  static String get stepFrontWait => _l.stepFrontWait;
  static String get stepRearConfig => _l.stepRearConfig;
  static String get stepAction => _l.stepAction;
  static String get stepGameOver => _l.stepGameOver;

  // ==================== 斗兽棋 ====================
  static String get animalChess => _l.animalChess;
  static String get netAnimalChess => _l.netAnimalChess;
  static String get setBoardSize => _l.setBoardSize;
  static String redTurn() => _l.redTurn;
  static String blueTurn() => _l.blueTurn;
  static String yourTurn() => _l.yourTurn;
  static String opponentTurn() => _l.opponentTurn;
  static String redWin() => _l.redWin;
  static String blueWin() => _l.blueWin;

  // ==================== 五子棋 ====================
  static String get gobang => _l.gobang;
  static String get netGobang => _l.netGobang;
  static String get blackSide => _l.blackSide;
  static String get whiteSide => _l.whiteSide;
  static String currentTurn(String side) => _l.currentTurn(side);
  static String sideWin(String side) => _l.sideWin(side);
  static String yourSideTurn(String side) => _l.yourSideTurn(side);
  static String opponentSideTurn(String side) => _l.opponentSideTurn(side);
  static String get aiLabel => _l.aiLabel;
  static String get aiThinking => _l.aiThinking;
  static String get undo => _l.undo;

  // ==================== 围棋 ====================
  static String get weiqi => _l.weiqi;

  // ==================== 贪吃蛇 ====================
  static String get finalLength => _l.finalLength;

  // ==================== 数独 ====================
  static String get sudoku => _l.sudoku;
  static String get setDifficulty => _l.setDifficulty;
  static String get pleaseConfirm => _l.pleaseConfirm;
  static String get leaveRoomLoseProgress => _l.leaveRoomLoseProgress;
  static String get congratulations => _l.congratulations;
  static String difficultyTime(String d, String t) => _l.difficultyTime(d, t);
  static String get startNewGame => _l.startNewGame;
  static String get importPuzzle => _l.importPuzzle;
  static String get importFailConflict => _l.importFailConflict;
  static String get importFailEmpty => _l.importFailEmpty;
  static String get importFailNotUnique => _l.importFailNotUnique;
  static String get confirmImport => _l.confirmImport;
  static String get cancelImport => _l.cancelImport;

  // ==================== 猜枚 ====================
  static String get guess => _l.guess;
  static String timeTaken(int s) => _l.timeTaken(s);
  static String correctCount(int c) => _l.correctCount(c);

  // ==================== 记忆翻牌 ====================
  static String get memoryCard => _l.memoryCard;
  static String remainingPairs(int v) => _l.remainingPairs(v);
  static String get bestTimeLabel => _l.bestTimeLabel;

  // ==================== 舒尔特 ====================
  static String get schulte => _l.schulte;
  static String nextNumber(int v) => _l.nextNumber(v);

  // ==================== 3tiles ====================
  static String get threeTiles => _l.threeTiles;
  static String timeSeconds(int v) => _l.timeSeconds(v);
  static String remaining(int v) => _l.remaining(v);
  static String get youLost => _l.youLost;
  static String get chooseDifficulty => _l.chooseDifficulty;
  static String get easy => _l.easy;
  static String get medium => _l.medium;
  static String get hard => _l.hard;
  static String difficultyTimeSeconds(String d, int t) =>
      _l.difficultyTimeSeconds(d, t);

  // ==================== 星际战机 ====================
  static String get spaceship => _l.spaceship;
  static String lives(double v) => _l.lives(v);
  static String score(int v) => _l.score(v);
  static String level(int v) => _l.level(v);
  static String get startGame => _l.startGame;
  static String get gamePaused => _l.gamePaused;
  static String get continueGame => _l.continueGame;
  static String get settings => _l.settings;
  static String get general => _l.general;
  static String get about => _l.about;
  static String get version => _l.version;
  static String get restartGame => _l.restartGame;
  static String get exitGame => _l.exitGame;
  static String get levelUp => _l.levelUp;
  static String currentLevel(int v) => _l.currentLevel(v);
  static String get harderChallenge => _l.harderChallenge;
  static String get finalScore => _l.finalScore;
  static String get reachedLevel => _l.reachedLevel;
  static String get unlockedAchievement => _l.unlockedAchievement;
  static String get playAgain => _l.playAgain;
  static String get backToHome => _l.backToHome;
  static String get noAchievements => _l.noAchievements;
  static String get enemyEscaped => _l.enemyEscaped;
  static String get bossAppear => _l.bossAppear;
  static String get sensitivitySetting => _l.sensitivitySetting;
  static String get mapDataEmpty => _l.mapDataEmpty;
  static String get boardDataEmpty => _l.boardDataEmpty;

  // ==================== 星际战机 成就 ====================
  static String get achFirstKill => _l.achFirstKill;
  static String get achFirstKillDesc => _l.achFirstKillDesc;
  static String get achScore100 => _l.achScore100;
  static String get achScore100Desc => _l.achScore100Desc;
  static String get achScore500 => _l.achScore500;
  static String get achScore500Desc => _l.achScore500Desc;
  static String get achScore1000 => _l.achScore1000;
  static String get achScore1000Desc => _l.achScore1000Desc;
  static String get achLevel5 => _l.achLevel5;
  static String get achLevel5Desc => _l.achLevel5Desc;
  static String get achLevel10 => _l.achLevel10;
  static String get achLevel10Desc => _l.achLevel10Desc;
  static String get achBossHunter => _l.achBossHunter;
  static String get achBossHunterDesc => _l.achBossHunterDesc;
  static String get achEightKills => _l.achEightKills;
  static String get achEightKillsDesc => _l.achEightKillsDesc;

  // ==================== 塔防 ====================
  static String get towerDefense => _l.towerDefense;
  static String get surrender => _l.surrender;
  static String get startWave => _l.startWave;
  static String get netTowerDefense => _l.netTowerDefense;
  static String hp(int cur, int max) => _l.hp(cur, max);
  static String hpMax(int v) => _l.hpMax(v);
  static String goldCost(int v) => _l.goldCost(v);
  static String get wavePrefix => _l.wavePrefix;

  // ==================== 五行之战 通用 ====================
  static String get attack => _l.attack;
  static String get parry => _l.parry;
  static String get skill => _l.skill;
  static String get escape => _l.escape;
  static String get pursuit => _l.pursuit;
  static String get victory => _l.victory;
  static String get defeat => _l.defeat;
  static String get win => _l.win;
  static String get youWon => _l.youWon;
  static String get youLost2 => _l.youLost2;
  static String get youEscaped => _l.youEscaped;
  static String get opponentEscaped => _l.opponentEscaped;
  static String get yourTurnAct => _l.yourTurnAct;
  static String get enemyTurnWait => _l.enemyTurnWait;
  static String choseAttack(String name) => _l.choseAttack(name);
  static String castSkill(String src, String skill, String tgt, String desc) =>
      _l.castSkill(src, skill, tgt, desc);
  static String switchIn(String name) => _l.switchIn(name);
  static String switchTo(String from, String to) => _l.switchTo(from, to);

  // ==================== 五行之战 属性标签 ====================
  static String get levelLabel => _l.levelLabel;
  static String get healthLabel => _l.healthLabel;
  static String get attackLabel => _l.attackLabel;
  static String get defenceLabel => _l.defenceLabel;

  // ==================== 五行之战 灵根选择 ====================
  static String get selectEnergy => _l.selectEnergy;
  static String get selectSkill => _l.selectSkill;
  static String get chooseEnergy => _l.chooseEnergy;
  static String get chooseAttribute => _l.chooseAttribute;

  // ==================== 五行之战 敌人 ====================
  static String get enemyImp => _l.enemyImp;
  static String get enemyClown => _l.enemyClown;
  static String get enemyDemon => _l.enemyDemon;
  static String get enemyKing => _l.enemyKing;
  static String get dummy => _l.dummy;

  // ==================== 五行之战 玩家 ====================
  static String get traveler => _l.traveler;

  // ==================== 五行之战 迷宫 ====================
  static String floorName(int v) => _l.floorName(v);
  static String get mainCity => _l.mainCity;
  static String get returnedToCity => _l.returnedToCity;
  static String get notice => _l.notice;
  static String get slept => _l.slept;
  static String get gotMedicine => _l.gotMedicine;
  static String get gotWeapon => _l.gotWeapon;
  static String get gotArmor => _l.gotArmor;
  static String gotMoneyBag(int m) => _l.gotMoneyBag(m);
  static String get cannotContinue => _l.cannotContinue;
  static String get levelUpSuccess => _l.levelUpSuccess;
  static String get notEnoughExp => _l.notEnoughExp;

  // ==================== 五行之战 UI 页面 ====================
  static String get backpack => _l.backpack;
  static String get status => _l.status;
  static String get switchElement => _l.switchElement;
  static String get store => _l.store;
  static String get buy => _l.buy;
  static String get use => _l.use;
  static String get learn => _l.learn;
  static String get forget => _l.forget;
  static String get active => _l.active;
  static String get passive => _l.passive;
  static String get preparing => _l.preparing;
  static String get configCharacter => _l.configCharacter;
  static String get viewOpponent => _l.viewOpponent;
  static String get characterConfig => _l.characterConfig;
  static String remainingPoints(int v) => _l.remainingPoints(v);
  static String coinCount(int v) => _l.coinCount(v);
  static String itemName(String n) => _l.itemName(n);
  static String get buySuccess => _l.buySuccess;
  static String get notEnoughCoins => _l.notEnoughCoins;
  static String get learnSuccess => _l.learnSuccess;
  static String skillTarget(String t) => _l.skillTarget(t);
  static String skillEffect(String d) => _l.skillEffect(d);
  static String get notYourTurn => _l.notYourTurn;
  static String get serverNotYourTurn => _l.serverNotYourTurn;
  static String exp(int v) => _l.exp(v);
  static String lv(int v) => _l.lv(v);
  static String hpCap(int v) => _l.hpCap(v);
  static String baseAtk(int v) => _l.baseAtk(v);
  static String baseDef(int v) => _l.baseDef(v);
  static String curHp(int v) => _l.curHp(v);
  static String curAtk(int v) => _l.curAtk(v);
  static String curDef(int v) => _l.curDef(v);
  static String get masteredSkills => _l.masteredSkills;
  static String get activeEffects => _l.activeEffects;

  // ==================== 五行之战 道具 ====================
  static String get potion => _l.potion;
  static String get potionDesc => _l.potionDesc;
  static String get sword => _l.sword;
  static String get swordDesc => _l.swordDesc;
  static String get shield => _l.shield;
  static String get shieldDesc => _l.shieldDesc;
  static String get scroll => _l.scroll;
  static String get scrollDesc => _l.scrollDesc;

  // ==================== 五行之战 技能 ====================
  static String get targetSelfFront => _l.targetSelfFront;
  static String get targetSelfAny => _l.targetSelfAny;
  static String get targetEnemyFront => _l.targetEnemyFront;
  static String get targetEnemyAny => _l.targetEnemyAny;

  // 技能名
  static String get skParry => _l.skParry;
  static String get skParryDesc => _l.skParryDesc;
  static String get skMetalP0 => _l.skMetalP0;
  static String get skMetalP0Desc => _l.skMetalP0Desc;
  static String get skWoodP0 => _l.skWoodP0;
  static String get skWoodP0Desc => _l.skWoodP0Desc;
  static String get skWaterP0 => _l.skWaterP0;
  static String get skWaterP0Desc => _l.skWaterP0Desc;
  static String get skFireP0 => _l.skFireP0;
  static String get skFireP0Desc => _l.skFireP0Desc;
  static String get skEarthP0 => _l.skEarthP0;
  static String get skEarthP0Desc => _l.skEarthP0Desc;
  static String get skMetalA0 => _l.skMetalA0;
  static String get skMetalA0Desc => _l.skMetalA0Desc;
  static String get skWoodA0 => _l.skWoodA0;
  static String get skWoodA0Desc => _l.skWoodA0Desc;
  static String get skWaterA0 => _l.skWaterA0;
  static String get skWaterA0Desc => _l.skWaterA0Desc;
  static String get skFireA0 => _l.skFireA0;
  static String get skFireA0Desc => _l.skFireA0Desc;
  static String get skEarthA0 => _l.skEarthA0;
  static String get skEarthA0Desc => _l.skEarthA0Desc;
  static String get skMetalAdv0 => _l.skMetalAdv0;
  static String get skMetalAdv0Desc => _l.skMetalAdv0Desc;
  static String get skWoodAdv0 => _l.skWoodAdv0;
  static String get skWoodAdv0Desc => _l.skWoodAdv0Desc;
  static String get skWaterAdv0 => _l.skWaterAdv0;
  static String get skWaterAdv0Desc => _l.skWaterAdv0Desc;
  static String get skFireAdv0 => _l.skFireAdv0;
  static String get skFireAdv0Desc => _l.skFireAdv0Desc;
  static String get skEarthAdv0 => _l.skEarthAdv0;
  static String get skEarthAdv0Desc => _l.skEarthAdv0Desc;
  static String get skMetalAux0 => _l.skMetalAux0;
  static String get skMetalAux0Desc => _l.skMetalAux0Desc;
  static String get skWoodAux0 => _l.skWoodAux0;
  static String get skWoodAux0Desc => _l.skWoodAux0Desc;
  static String get skWaterAux0 => _l.skWaterAux0;
  static String get skWaterAux0Desc => _l.skWaterAux0Desc;
  static String get skFireAux0 => _l.skFireAux0;
  static String get skFireAux0Desc => _l.skFireAux0Desc;
  static String get skEarthAux0 => _l.skEarthAux0;
  static String get skEarthAux0Desc => _l.skEarthAux0Desc;
  static String get skMetalF0 => _l.skMetalF0;
  static String get skMetalF0Desc => _l.skMetalF0Desc;
  static String get skWoodF0 => _l.skWoodF0;
  static String get skWoodF0Desc => _l.skWoodF0Desc;
  static String get skWaterF0 => _l.skWaterF0;
  static String get skWaterF0Desc => _l.skWaterF0Desc;
  static String get skFireF0 => _l.skFireF0;
  static String get skFireF0Desc => _l.skFireF0Desc;
  static String get skEarthF0 => _l.skEarthF0;
  static String get skEarthF0Desc => _l.skEarthF0Desc;

  // ==================== 战斗日志 ====================
  static String healLog(String name, int actual, int hp) =>
      _l.healLog(name, actual, hp);
  static String selfDamageLog(String name, int dmg) =>
      _l.selfDamageLog(name, dmg);
  static String damageLog(String name, int dmg, bool magic, int hp) => magic
      ? _l.damageLogMagic(name, dmg, hp)
      : _l.damageLogPhysical(name, dmg, hp);

  // ==================== 地图/棋盘 ====================
  static String get mapDataEmpty2 => _l.mapDataEmpty2;
  static String get boardDataEmpty2 => _l.boardDataEmpty2;

  // ==================== 对局游戏名翻译 ====================
  static String roomTypeString(String raw) {
    switch (raw) {
      case 'onlyChat':
        return _l.roomTypeChat;
      case 'animalChess':
        return _l.animalChess;
      case 'elementalBattle':
        return _l.elementalBattle;
      case 'gobang':
        return _l.gobang;
      case 'greedySnake':
        return _l.greedySnake;
      case 'weiqi':
        return _l.weiqi;
      case 'sudoku':
        return _l.sudoku;
      case 'guess':
        return _l.guess;
      case 'memoryCard':
        return _l.memoryCard;
      case 'schulte':
        return _l.schulte;
      case 'threeTiles':
        return _l.threeTiles;
      case 'spaceship':
        return _l.spaceship;
      case 'soft':
        return _l.soft;
      case 'minecraft':
        return _l.minecraft;
      case 'towerDefense':
        return _l.towerDefense;
      default:
        return raw;
    }
  }
}
