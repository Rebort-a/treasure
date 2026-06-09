import 'l10n.dart';

/// 全局翻译服务，无需 BuildContext
class S {
  S._();
  static AppLocale get _loc => LanguageProvider.instance.locale.value;
  static bool get isZh => _loc == AppLocale.zh;

  // ==================== 通用 ====================
  static String get confirm => isZh ? '确认' : 'Confirm';
  static String get cancel => isZh ? '取消' : 'Cancel';
  static String get close => isZh ? '关闭' : 'Close';
  static String get ok => isZh ? '确定' : 'OK';
  static String get clear => isZh ? '清除' : 'Clear';
  static String get exit => isZh ? '退出' : 'Exit';
  static String get restart => isZh ? '重开' : 'Restart';
  static String get create => isZh ? '创建' : 'Create';
  static String get join => isZh ? '加入' : 'Join';
  static String get stop => isZh ? '停止' : 'Stop';
  static String get stopAll => isZh ? '全部停止' : 'STOP ALL';
  static String get gameOver => isZh ? '游戏结束' : 'Game Over';
  static String get selectOption => isZh ? '选择选项' : 'Select Option';
  static String currentValue(String v) => isZh ? '当前值: $v' : 'Current: $v';

  // ==================== 首页 ====================
  static String get roomList => isZh ? '房间列表' : 'Room List';
  static String get local => isZh ? '本地' : 'Local';
  static String get createdRooms => isZh ? '你创建的房间' : 'The rooms you created';
  static String get otherRooms => isZh ? '其他房间' : 'The other rooms';
  static String get createRoom => isZh ? '创建房间' : 'Create Room';
  static String get enterRoomName => isZh ? '输入房间名' : 'Enter room name';
  static String get joinRoom => isZh ? '加入房间' : 'Join Room';
  static String get joinByIp => isZh ? '手动加入' : 'Join by IP';
  static String get enterUserName => isZh ? '输入用户名' : 'Enter user name';
  static String get userName => isZh ? '用户名' : 'User name';
  static String get hostIp =>
      isZh ? '主机IP (如 192.168.1.100)' : 'Host IP (e.g. 192.168.1.100)';
  static String get port => isZh ? '端口' : 'Port';
  static String get game => isZh ? '游戏' : 'Game';
  static String get leave => isZh ? '离开' : 'Leave';
  static String get leaveRoom => isZh ? '即将退出房间' : 'About to leave the room';
  static String get language => isZh ? '语言' : 'Language';

  // ==================== 通用网络 ====================
  static String get disconnected => isZh ? '连接断开' : 'Disconnected';
  static String get roomClosed => isZh ? '房间已关闭' : 'Room closed';
  static String get cannotReconnect =>
      isZh ? '无法重新连接到服务器' : 'Cannot reconnect to server';
  static String reconnecting(int cur, int max) =>
      isZh ? '正在尝试重新连接... ($cur/$max)' : 'Reconnecting... ($cur/$max)';
  static String get competitorsWithdraw => isZh ? '对手退出' : 'Opponent Left';
  static String get opponentWithdrawn =>
      isZh ? '对手已退出' : 'The opponent has withdrawn';
  static String get typeMessage => isZh ? '输入消息...' : 'Type a message';
  static String get wait => isZh ? '等待中' : 'Wait';

  // ==================== 聊天 ====================
  static String get chatRoom => isZh ? '聊天室' : 'Chat Room';
  static String get online => isZh ? '在线' : 'Online';
  static String get connecting => isZh ? '连接中...' : 'Connecting...';
  static String get members => isZh ? '成员列表' : 'Members';
  static String get chatSettings => isZh ? '聊天设置' : 'Chat Settings';
  static String get clearHistory => isZh ? '清空聊天记录' : 'Clear History';
  static String get clearHistoryConfirm => isZh
      ? '确定要清空所有聊天记录吗？此操作不可撤销。'
      : 'Clear all chat history? This cannot be undone.';
  static String get darkMode => isZh ? '深色模式' : 'Dark Mode';
  static String get messageNotification => isZh ? '消息通知' : 'Notifications';
  static String get attachment => isZh ? '附件' : 'Attachment';
  static String get album => isZh ? '相册' : 'Album';
  static String get camera => isZh ? '拍照' : 'Camera';
  static String get file => isZh ? '文件' : 'File';
  static String get location => isZh ? '位置' : 'Location';
  static String get imageLoadFailed => isZh ? '图片加载失败' : 'Image load failed';
  static String get unknownFile => isZh ? '未知文件' : 'Unknown file';
  static String get selectImageFailed =>
      isZh ? '选择图片失败' : 'Failed to select image';
  static String get takePhotoFailed => isZh ? '拍照失败' : 'Failed to take photo';
  static String get sendImageFailed => isZh ? '发送图片失败' : 'Failed to send image';
  static String get selectFileFailed =>
      isZh ? '选择文件失败' : 'Failed to select file';
  static String get today => isZh ? '今天' : 'Today';
  static String get yesterday => isZh ? '昨天' : 'Yesterday';
  static String get saveSuccess => isZh ? '文件已保存' : 'File saved';
  static String get saveFailed => isZh ? '保存失败' : 'Save failed';
  static String get savedTo => isZh ? '已保存到' : 'Saved to';
  static String get downloading => isZh ? '正在保存...' : 'Saving...';

  // ==================== 表情分类 ====================
  static String get emojiCommon => isZh ? '常用' : 'Common';
  static String get emojiGesture => isZh ? '手势' : 'Gestures';
  static String get emojiHeart => isZh ? '心形' : 'Hearts';
  static String get emojiAnimal => isZh ? '动物' : 'Animals';
  static String get emojiFood => isZh ? '食物' : 'Food';
  static String get emojiSport => isZh ? '运动' : 'Sports';
  static String get emojiTravel => isZh ? '旅行' : 'Travel';
  static String get emojiSymbol => isZh ? '符号' : 'Symbols';

  // ==================== 游戏步骤 ====================
  static String get stepDisconnect => isZh ? '等待连接' : 'Waiting to connect';
  static String get stepConnected =>
      isZh ? '已连接，等待对手加入...' : 'Connected, waiting for opponent...';
  static String get stepFrontConfig => isZh ? '请配置' : 'Please configure';
  static String get stepRearWait =>
      isZh ? '等待先手配置' : 'Waiting for first player config';
  static String get stepFrontWait =>
      isZh ? '等待后手配置' : 'Waiting for second player config';
  static String get stepRearConfig =>
      isZh ? '请配置或查看对方配置' : 'Configure or view opponent config';
  static String get stepAction => isZh ? '进行中' : 'In Progress';
  static String get stepGameOver => isZh ? '游戏结束' : 'Game Over';

  // ==================== 斗兽棋 ====================
  static String get animalChess => isZh ? '斗兽棋' : 'Animal Chess';
  static String get netAnimalChess => isZh ? '联机斗兽棋' : 'Net Animal Chess';
  static String get setBoardSize => isZh ? '设置棋牌大小' : 'Set Board Size';
  static String redTurn() => isZh ? '红方回合' : "Red's Turn";
  static String blueTurn() => isZh ? '蓝方回合' : "Blue's Turn";
  static String yourTurn() => isZh ? '你的回合' : 'Your Turn';
  static String opponentTurn() => isZh ? '对方回合' : "Opponent's Turn";
  static String redWin() => isZh ? '红方获胜！' : 'Red Wins!';
  static String blueWin() => isZh ? '蓝方获胜！' : 'Blue Wins!';

  // ==================== 五子棋 ====================
  static String get gobang => isZh ? '五子棋' : 'Gomoku';
  static String get netGobang => isZh ? '联机五子棋' : 'Net Gomoku';
  static String get blackSide => isZh ? '黑方' : 'Black';
  static String get whiteSide => isZh ? '白方' : 'White';
  static String currentTurn(String side) =>
      isZh ? '当前回合: $side' : 'Current Turn: $side';
  static String sideWin(String side) => isZh ? '$side获胜!' : '$side Wins!';
  static String yourSideTurn(String side) =>
      isZh ? '你的回合 $side' : 'Your Turn $side';
  static String opponentSideTurn(String side) =>
      isZh ? '对方回合 $side' : "Opponent's Turn $side";

  // ==================== 围棋 ====================
  static String get weiqi => isZh ? '围棋' : 'Go';

  // ==================== 贪吃蛇 ====================
  static String get finalLength => isZh ? '最终长度' : 'Final Length';

  // ==================== 数独 ====================
  static String get sudoku => isZh ? '数独' : 'Sudoku';
  static String get setDifficulty => isZh ? '设置难度' : 'Set Difficulty';
  static String get pleaseConfirm => isZh ? '请确认' : 'Please Confirm';
  static String get leaveRoomLoseProgress =>
      isZh ? '离开房间将丢失进度' : 'Leaving will lose progress';
  static String get congratulations => isZh ? '恭喜完成！' : 'Congratulations!';
  static String difficultyTime(String d, String t) =>
      isZh ? '难度: $d 用时: $t' : 'Difficulty: $d Time: $t';
  static String get startNewGame => isZh ? '开始新游戏' : 'Start New Game';
  static String get importPuzzle => isZh ? '导入棋局' : 'Import Puzzle';
  static String get importFailConflict =>
      isZh ? '棋盘中存在冲突，请检查行、列或宫格中是否有重复数字'
      : 'Board has conflicts. Check rows, columns and boxes for duplicates.';
  static String get importFailEmpty =>
      isZh ? '请至少填写一个数字' : 'Fill in at least one number.';
  static String get importFailNotUnique =>
      isZh ? '该棋局没有唯一解，请调整数字' : 'The puzzle has no unique solution. Adjust the numbers.';
  static String get confirmImport => isZh ? '确认导入' : 'Confirm';
  static String get cancelImport => isZh ? '取消' : 'Cancel';

  // ==================== 猜枚 ====================
  static String get guess => isZh ? '猜枚' : 'Guess';
  static String timeTaken(int s) =>
      isZh ? '用时: $s 秒' : 'Time Taken: $s seconds';
  static String correctCount(int c) => isZh ? '正确次数: $c' : 'Correct Count: $c';

  // ==================== 3tiles ====================
  static String get threeTiles => isZh ? '羊了个羊' : '3tiles';
  static String timeSeconds(int v) => isZh ? '时间: $v 秒' : 'Time: $v s';
  static String remaining(int v) => isZh ? '剩余: $v' : 'Remaining: $v';
  static String get youLost => isZh ? '你输了' : 'You Lost';
  static String get chooseDifficulty => isZh ? '选择难度' : 'Choose Difficulty';
  static String get easy => isZh ? '简单' : 'Easy';
  static String get medium => isZh ? '中等' : 'Medium';
  static String get hard => isZh ? '困难' : 'Hard';
  static String difficultyTimeSeconds(String d, int t) =>
      isZh ? '难度: $d 用时: $t 秒' : 'Difficulty: $d Time: $t s';

  // ==================== 星际战机 ====================
  static String get spaceship => isZh ? '星际战机' : 'Space Ship';
  static String lives(double v) => isZh ? '生命: $v' : 'Lives: $v';
  static String score(int v) => isZh ? '分数: $v' : 'Score: $v';
  static String level(int v) => isZh ? '等级: $v' : 'Level: $v';
  static String get startGame => isZh ? '开始游戏' : 'Start Game';
  static String get gamePaused => isZh ? '游戏暂停' : 'Game Paused';
  static String get continueGame => isZh ? '继续游戏' : 'Continue';
  static String get gameSettings => isZh ? '设置' : 'Settings';
  static String get general => isZh ? '通用' : 'General';
  static String get about => isZh ? '关于' : 'About';
  static String get version => isZh ? '版本' : 'Version';
  static String get restartGame => isZh ? '重新开始' : 'Restart';
  static String get exitGame => isZh ? '退出游戏' : 'Exit Game';
  static String get levelUp => isZh ? '等级提升' : 'Level Up';
  static String currentLevel(int v) => isZh ? '当前等级: $v' : 'Current Level: $v';
  static String get harderChallenge =>
      isZh ? '准备迎接更难的挑战!' : 'Ready for harder challenges!';
  static String get finalScore => isZh ? '最终得分' : 'Final Score';
  static String get reachedLevel => isZh ? '达到等级' : 'Reached Level';
  static String get unlockedAchievement =>
      isZh ? '解锁成就' : 'Unlocked Achievement';
  static String get playAgain => isZh ? '再玩一次' : 'Play Again';
  static String get backToHome => isZh ? '返回主页' : 'Back to Home';
  static String get noAchievements =>
      isZh ? '没有解锁任何成就' : 'No achievements unlocked';
  static String get enemyEscaped => isZh ? '敌人逃脱！' : 'Enemy Escaped!';
  static String get bossAppear => isZh ? 'Boss出现！' : 'Boss Appeared!';
  static String get sensitivitySetting => isZh ? '灵敏度设置' : 'Sensitivity';
  static String get mapDataEmpty => isZh ? '地图数据为空' : 'Map data is empty';
  static String get boardDataEmpty => isZh ? '棋盘数据为空' : 'Board data is empty';

  // ==================== 星际战机 成就 ====================
  static String get achFirstKill => isZh ? '初露锋芒' : 'First Blood';
  static String get achFirstKillDesc =>
      isZh ? '首次击败敌人' : 'First enemy defeated';
  static String get achScore100 => isZh ? '百炼成钢' : 'Steel Will';
  static String get achScore100Desc => isZh ? '得分达到100分' : 'Score reaches 100';
  static String get achScore500 => isZh ? '半壁江山' : 'Half Kingdom';
  static String get achScore500Desc => isZh ? '得分达到500分' : 'Score reaches 500';
  static String get achScore1000 => isZh ? '千锤百炼' : 'Veteran';
  static String get achScore1000Desc =>
      isZh ? '得分达到1000分' : 'Score reaches 1000';
  static String get achLevel5 => isZh ? '五级挑战' : 'Level 5 Challenge';
  static String get achLevel5Desc => isZh ? '达到5级' : 'Reach level 5';
  static String get achLevel10 => isZh ? '十级大师' : 'Level 10 Master';
  static String get achLevel10Desc => isZh ? '达到10级' : 'Reach level 10';
  static String get achBossHunter => isZh ? 'Boss猎手' : 'Boss Hunter';
  static String get achBossHunterDesc =>
      isZh ? '首次击败BOSS' : 'First BOSS defeated';
  static String get achEightKills => isZh ? '八连杀' : 'Eight Streak';
  static String get achEightKillsDesc =>
      isZh ? '连续击败八个敌人' : 'Defeat 8 enemies in a row';

  // ==================== 塔防 ====================
  static String get towerDefense => isZh ? '塔防' : 'Tower Defense';
  static String get surrender => isZh ? '投降' : 'Surrender';
  static String get startWave => isZh ? '开始波次' : 'Start Wave';
  static String get netTowerDefense => isZh ? '联机塔防' : 'Net Tower Defense';

  // ==================== 五行之战 通用 ====================
  static String get attack => isZh ? '攻击' : 'Attack';
  static String get parry => isZh ? '格挡' : 'Parry';
  static String get skill => isZh ? '技能' : 'Skill';
  static String get escape => isZh ? '逃跑' : 'Escape';
  static String get pursuit => isZh ? '追击' : 'Pursuit';
  static String get victory => isZh ? '胜利' : 'Victory';
  static String get defeat => isZh ? '失败' : 'Defeat';
  static String get win => isZh ? '胜利' : 'Win';
  static String get youWon => isZh ? '你获得了胜利！' : 'You Won!';
  static String get youLost2 => isZh ? '很遗憾，你输了...' : 'You Lost...';
  static String get youEscaped => isZh ? '你成功逃脱了战斗' : 'You escaped the battle';
  static String get opponentEscaped => isZh ? '对方逃跑了' : 'Opponent escaped';
  static String get yourTurnAct => isZh ? '你的回合，请行动' : 'Your turn, take action';
  static String get enemyTurnWait =>
      isZh ? '敌人的回合，请等待' : "Enemy's turn, please wait";
  static String choseAttack(String name) =>
      isZh ? '$name 选择了 攻击' : '$name chose Attack';
  static String castSkill(String src, String skill, String tgt, String desc) =>
      isZh
      ? '$src 施放了技能 $skill\n$tgt 获得效果 $desc'
      : '$src cast $skill\n$tgt receives $desc';
  static String switchIn(String name) => isZh ? '$name 上场' : '$name enters';
  static String switchTo(String from, String to) =>
      isZh ? '$from 切换为 $to' : '$from switched to $to';

  // ==================== 五行之战 属性标签 ====================
  static String get levelLabel => isZh ? '等级' : 'Level';
  static String get healthLabel => isZh ? '生命值' : 'HP';
  static String get attackLabel => isZh ? '攻击力' : 'ATK';
  static String get defenceLabel => isZh ? '防御力' : 'DEF';

  // ==================== 五行之战 灵根选择 ====================
  static String get selectEnergy => isZh ? '选择一个灵根' : 'Choose Energy';
  static String get selectSkill => isZh ? '选择一个技能' : 'Choose a Skill';
  static String get chooseEnergy => isZh ? '选择灵根:' : 'Choose Energy:';
  static String get chooseAttribute => isZh ? '选择属性:' : 'Choose Attribute:';

  // ==================== 五行之战 敌人 ====================
  static String get enemyImp => isZh ? '小鬼' : 'Imp';
  static String get enemyClown => isZh ? '小丑' : 'Clown';
  static String get enemyDemon => isZh ? '恶魔' : 'Demon';
  static String get enemyKing => isZh ? '鬼王' : 'Demon King';
  static String get dummy => isZh ? '假人' : 'Dummy';

  // ==================== 五行之战 玩家 ====================
  static String get traveler => isZh ? '旅行者' : 'Traveler';

  // ==================== 五行之战 迷宫 ====================
  static String floorName(int v) => isZh ? '地下$v层' : 'B$v';
  static String get mainCity => isZh ? '主城' : 'Main City';
  static String get returnedToCity => isZh ? '你回到了主城' : 'Returned to Main City';
  static String get notice => isZh ? '提示' : 'Notice';
  static String get slept => isZh ? '你睡了一觉，恢复了状态' : 'You slept and recovered';
  static String get gotMedicine => isZh ? '你得到了一个药' : 'Got a potion';
  static String get gotWeapon => isZh ? '你得到了一个武器' : 'Got a weapon';
  static String get gotArmor => isZh ? '你得到了一个防具' : 'Got armor';
  static String gotMoneyBag(int m) =>
      isZh ? '你得到了一个钱袋，获得了$m枚金币' : 'Got a money bag, $m coins';
  static String get cannotContinue =>
      isZh ? '无法继续冒险' : 'Cannot continue adventure';
  static String get levelUpSuccess => isZh ? '升级成功！' : 'Level Up!';
  static String get notEnoughExp => isZh ? '经验不足！' : 'Not enough EXP!';

  // ==================== 五行之战 UI 页面 ====================
  static String get backpack => isZh ? '背包' : 'Backpack';
  static String get status => isZh ? '状态' : 'Status';
  static String get switchElement => isZh ? '切换' : 'Switch';
  static String get store => isZh ? '商店' : 'Store';
  static String get buy => isZh ? '购买' : 'Buy';
  static String get use => isZh ? '使用' : 'Use';
  static String get learn => isZh ? '学习' : 'Learn';
  static String get forget => isZh ? '遗忘' : 'Forget';
  static String get active => isZh ? '主动' : 'Active';
  static String get passive => isZh ? '被动' : 'Passive';
  static String get preparing => isZh ? '准备中' : 'Preparing';
  static String get configCharacter => isZh ? '配置角色' : 'Configure';
  static String get viewOpponent => isZh ? '查看对手信息' : 'View Opponent';
  static String get characterConfig => isZh ? '角色配置' : 'Character Config';
  static String remainingPoints(int v) => isZh ? '剩余点数: $v' : 'Points: $v';
  static String coinCount(int v) => isZh ? '金币数量: $v' : 'Coins: $v';
  static String itemName(String n) => isZh ? '名称:$n' : 'Name:$n';
  static String get buySuccess => isZh ? '购买成功' : 'Purchase Success';
  static String get notEnoughCoins => isZh ? '金币不足' : 'Not enough coins';
  static String get learnSuccess => isZh ? '学习成功！' : 'Learned!';
  static String skillTarget(String t) => isZh ? '目标: $t' : 'Target: $t';
  static String skillEffect(String d) => isZh ? '效果: $d' : 'Effect: $d';
  static String get notYourTurn => isZh ? '不是你的回合' : 'Not your turn';
  static String get serverNotYourTurn =>
      isZh ? '\n服务器：不是你的回合\n' : '\nServer: Not your turn\n';
  static String exp(int v) => isZh ? '经验: $v' : 'EXP: $v';
  static String lv(int v) => isZh ? '等级: $v' : 'Level: $v';
  static String hpCap(int v) => isZh ? '生命值上限: $v' : 'HP Cap: $v';
  static String baseAtk(int v) => isZh ? '初始攻击力: $v' : 'Base ATK: $v';
  static String baseDef(int v) => isZh ? '初始防御力: $v' : 'Base DEF: $v';
  static String curHp(int v) => isZh ? '当前生命值: $v' : 'Cur HP: $v';
  static String curAtk(int v) => isZh ? '当前攻击力: $v' : 'Cur ATK: $v';
  static String curDef(int v) => isZh ? '当前防御力: $v' : 'Cur DEF: $v';
  static String get masteredSkills => isZh ? '掌握技能:' : 'Skills:';
  static String get activeEffects => isZh ? '获得影响:' : 'Effects:';

  // ==================== 五行之战 道具 ====================
  static String get potion => isZh ? '药' : 'Potion';
  static String get potionDesc => isZh ? '生命值+32' : 'HP +32';
  static String get sword => isZh ? '剑' : 'Sword';
  static String get swordDesc => isZh ? '攻击力+8' : 'ATK +8';
  static String get shield => isZh ? '盾' : 'Shield';
  static String get shieldDesc => isZh ? '防御力+8' : 'DEF +8';
  static String get scroll => isZh ? '回城卷轴' : 'Scroll';
  static String get scrollDesc => isZh ? '随时随地可以回家' : 'Return home anytime';

  // ==================== 五行之战 技能 ====================
  static String get targetSelfFront => isZh ? '所属灵根' : 'Self Front';
  static String get targetSelfAny => isZh ? '任一灵根' : 'Self Any';
  static String get targetEnemyFront => isZh ? '敌方当前灵根' : 'Enemy Front';
  static String get targetEnemyAny => isZh ? '敌方任一灵根' : 'Enemy Any';

  // 技能名
  static String get skParry => isZh ? '格挡' : 'Parry';
  static String get skParryDesc =>
      isZh ? '防守时，减少75%受到的伤害，生效一次。' : 'Reduce damage by 75%, once.';
  static String get skMetalP0 => isZh ? '攻防兼备' : 'Balanced Force';
  static String get skMetalP0Desc =>
      isZh ? '战斗时，获得50%额外的攻击力和防御力。' : '+50% ATK and DEF in combat.';
  static String get skWoodP0 => isZh ? '叶落归根' : 'Life Drain';
  static String get skWoodP0Desc =>
      isZh ? '造成伤害后，根据伤害量的25%，回复生命。' : 'Heal 25% of damage dealt.';
  static String get skWaterP0 => isZh ? '水无常形' : 'Adaptive Flow';
  static String get skWaterP0Desc => isZh
      ? '受到伤害后，防御力减少，根据减少量的75%，提高攻击力，如果是法术伤害，还会因此附魔。\n\n兵无常势，水无常形。'
      : 'After taking damage, lose DEF, gain 75% of lost DEF as ATK. Magic damage also enchants.\n\nWater adapts to its container.';
  static String get skFireP0 => isZh ? '燃烧吧' : 'Ignite';
  static String get skFireP0Desc => isZh
      ? '攻击时，获得100%附魔，所有伤害均为无视防御的法术伤害。\n\n燃起来了。'
      : '100% enchant, all damage ignores defense.\n\nIt\'s on fire.';
  static String get skEarthP0 => isZh ? '厚积薄发' : 'Accumulate';
  static String get skEarthP0Desc => isZh
      ? '受到伤害后，将物理伤害的50%和法术伤害的15%作为加成，提高下次攻击的攻击力。\n\n大地会记住一切。'
      : 'After damage: +50% physical, +15% magic as ATK bonus.\n\nEarth remembers all.';
  static String get skMetalA0 => isZh ? '以退为进' : 'Retreat to Advance';
  static String get skMetalA0Desc =>
      isZh ? '下次攻击时，额外进行一次，生效一次。' : 'Extra attack next turn, once.';
  static String get skWoodA0 => isZh ? '根深蒂固' : 'Deep Roots';
  static String get skWoodA0Desc =>
      isZh ? '根据自身生命上限的12.5%回复生命，生效一次。' : 'Heal 12.5% max HP, once.';
  static String get skWaterA0 => isZh ? '拖泥带水' : 'Slow Down';
  static String get skWaterA0Desc =>
      isZh ? '下次攻击时，减少50%的攻击力，生效两次。' : 'Reduce enemy ATK by 50%, twice.';
  static String get skFireA0 => isZh ? '爆裂魔法' : 'Explosion';
  static String get skFireA0Desc => isZh
      ? '生命值降为1，根据降低的比例，提高伤害系数，并进行一次攻击。\n\n Explosion！'
      : 'HP to 1, boost damage by ratio, attack once.\n\nExplosion!';
  static String get skEarthA0 => isZh ? '不动如山' : 'Immovable';
  static String get skEarthA0Desc => isZh
      ? '下次受到伤害时，进行一次攻击。\n力的作用是相互的。'
      : 'Counter-attack when hit.\nForce is mutual.';
  static String get skMetalAdv0 => isZh ? '以逸待劳' : 'Wait and See';
  static String get skMetalAdv0Desc => isZh
      ? '以退为进可以施加给己方任一灵根，使其下次攻击时，额外进行一次。'
      : 'Retreat to Advance targets any ally.';
  static String get skWoodAdv0 => isZh ? '开枝散叶' : 'Spread Roots';
  static String get skWoodAdv0Desc => isZh
      ? '根深蒂固可以施加给己方任一灵根，根据自身生命上限的12.5%回复其生命。'
      : 'Deep Roots targets any ally.';
  static String get skWaterAdv0 => isZh ? '水泄不通' : 'Tight Seal';
  static String get skWaterAdv0Desc => isZh
      ? '拖泥带水可以施加给敌方任一灵根，使其下次攻击时，减少50%的攻击力，生效两次。'
      : 'Slow Down targets any enemy.';
  static String get skFireAdv0 => isZh ? '薪火相传' : 'Pass the Torch';
  static String get skFireAdv0Desc => isZh
      ? '爆裂魔法可以施加给己方任一灵根，使其生命值降为1，根据降低的比例，提高伤害系数，并上场进行一次攻击。'
      : 'Explosion targets any ally.';
  static String get skEarthAdv0 => isZh ? '玉石俱焚' : 'Mutual Destruction';
  static String get skEarthAdv0Desc => isZh
      ? '不动如山可以施加给己方任一灵根，使其下次受到伤害时，进行一次攻击。'
      : 'Immovable targets any ally.';
  static String get skMetalAux0 => isZh ? '全副武装' : 'Full Arms';
  static String get skMetalAux0Desc =>
      isZh ? '战斗时，额外获得50%的攻击力和防御力，生效两次。' : '+50% ATK and DEF, twice.';
  static String get skWoodAux0 => isZh ? '移花接木' : 'Graft';
  static String get skWoodAux0Desc =>
      isZh ? '造成伤害时，根据伤害量的25%，回复生命，生效两次。' : 'Heal 25% of damage dealt, twice.';
  static String get skWaterAux0 => isZh ? '因地制流' : 'Adapt';
  static String get skWaterAux0Desc => isZh
      ? '受到伤害后，防御力减少，根据减少量的75%，提高攻击力，生效两次。\n\n水因地制流，兵因敌制胜。'
      : 'Lose DEF, gain 75% as ATK, twice.\n\nWater flows with the land.';
  static String get skFireAux0 => isZh ? '火力全开' : 'Full Firepower';
  static String get skFireAux0Desc => isZh
      ? '攻击时，获得100%附魔比例，造成无视防御的法术伤害，生效两次。\n\n对他使用炎拳吧！'
      : '100% enchant, twice.\n\nUse Fire Fist!';
  static String get skEarthAux0 => isZh ? '卷土重来' : 'Comeback';
  static String get skEarthAux0Desc => isZh
      ? '受到伤害后，将物理伤害的50%和法术伤害的15%作为加成，提高下次攻击的攻击力，生效两次。'
      : '+50% phys, +15% magic as ATK, twice.';
  static String get skMetalF0 => isZh ? '屠龙' : 'Dragon Slayer';
  static String get skMetalF0Desc => isZh
      ? '攻击时，基于敌方当前生命值的25%，提高自身攻击力，生效一次。'
      : '+ATK based on 25% enemy HP, once.';
  static String get skWoodF0 => isZh ? '桎梏' : 'Shackle';
  static String get skWoodF0Desc =>
      isZh ? '回复生命时，溢出的治疗量会提高生命值上限。' : 'Overflow healing increases max HP.';
  static String get skWaterF0 => isZh ? '止水' : 'Still Water';
  static String get skWaterF0Desc => isZh
      ? '受到致命伤害时，生命值回复到1，生效一次。\n\n区区致命伤。'
      : 'Survive lethal damage at 1 HP, once.\n\nJust a scratch.';
  static String get skFireF0 => isZh ? '灼烧' : 'Scorch';
  static String get skFireF0Desc => isZh
      ? '造成的法术伤害，会使敌人烧伤，使其再次受到伤害时，追加本次伤害值25%的伤害，生效两次。\n\n阿玛忒拉斯。'
      : 'Magic burns enemy, +25% damage on next hit, twice.\n\nAmaterasu.';
  static String get skEarthF0 => isZh ? '砥砺' : 'Sharpen';
  static String get skEarthF0Desc => isZh
      ? '受到伤害时，将已损失生命值的25%作为攻击力，造成一次伤害系数为25%的物理伤害，生效两次。'
      : 'On hit: 25% lost HP as ATK, 25% multiplier, twice.';

  // ==================== 战斗日志 ====================
  static String healLog(String name, int actual, int hp) => isZh
      ? '$name 回复了 $actual 生命值，当前生命值 $hp'
      : '$name healed $actual HP, now $hp';
  static String selfDamageLog(String name, int dmg) => isZh
      ? '$name 对自身造成 $dmg 伤害，伤害系数提高'
      : '$name took $dmg self damage, damage multiplier increased';
  static String damageLog(String name, int dmg, bool magic, int hp) => isZh
      ? '$name 受到 $dmg ${magic ? "法术" : "物理"} 伤害, 生命值 $hp'
      : '$name took $dmg ${magic ? "magic" : "physical"} damage, HP $hp';

  // ==================== 地图/棋盘 ====================
  static String get mapDataEmpty2 => isZh ? '地图数据为空' : 'Map data is empty';
  static String get boardDataEmpty2 => isZh ? '棋盘数据为空' : 'Board data is empty';

  // ==================== 对局游戏名翻译 ====================
  static String localGameName(String raw) {
    switch (raw) {
      case 'animalChess':
        return isZh ? '斗兽棋' : 'Animal Chess';
      case 'elementalBattle':
        return isZh ? '五行之战' : 'Elemental Battle';
      case 'gobang':
        return isZh ? '五子棋' : 'Gomoku';
      case 'greedySnake':
        return isZh ? '贪吃蛇' : 'Greedy Snake';
      case 'weiqi':
        return isZh ? '围棋' : 'Go';
      case 'sudoku':
        return isZh ? '数独' : 'Sudoku';
      case 'guess':
        return isZh ? '猜枚' : 'Guess';
      case 'threeTiles':
        return isZh ? '羊了个羊' : '3tiles';
      case 'spaceship':
        return isZh ? '星际战机' : 'Space Ship';
      case 'soft':
        return isZh ? '软环' : 'Soft';
      case 'minecraft':
        return isZh ? '我的世界' : 'Minecraft';
      case 'towerDefense':
        return isZh ? '塔防' : 'Tower Defense';
      case 'onlyChat':
        return isZh ? '聊天室' : 'Chat';
      default:
        return raw;
    }
  }

  static String netGameName(String raw) {
    switch (raw) {
      case 'onlyChat':
        return isZh ? '聊天室' : 'Chat';
      case 'animalChess':
        return isZh ? '斗兽棋' : 'Animal Chess';
      case 'elementalBattle':
        return isZh ? '五行之战' : 'Elemental Battle';
      case 'gobang':
        return isZh ? '五子棋' : 'Gomoku';
      case 'greedySnake':
        return isZh ? '贪吃蛇' : 'Greedy Snake';
      case 'weiqi':
        return isZh ? '围棋' : 'Go';
      case 'towerDefense':
        return isZh ? '塔防' : 'Tower Defense';
      default:
        return raw;
    }
  }
}
