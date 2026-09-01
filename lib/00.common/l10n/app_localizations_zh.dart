// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get ok => '确定';

  @override
  String get clear => '清除';

  @override
  String get exit => '退出';

  @override
  String get restart => '重开';

  @override
  String get create => '创建';

  @override
  String get join => '加入';

  @override
  String get stop => '停止';

  @override
  String get stopAll => '全部停止';

  @override
  String get gameOver => '游戏结束';

  @override
  String get selectOption => '选择选项';

  @override
  String currentValue(String v) {
    return '当前值: $v';
  }

  @override
  String get roomList => '房间列表';

  @override
  String get local => '本地';

  @override
  String get createdRooms => '你创建的房间';

  @override
  String get otherRooms => '其他房间';

  @override
  String get createRoom => '创建房间';

  @override
  String get enterRoomName => '输入房间名';

  @override
  String get joinRoom => '加入房间';

  @override
  String get joinByIp => '手动加入';

  @override
  String get enterUserName => '输入用户名';

  @override
  String get userName => '用户名';

  @override
  String get hostIp => '主机IP';

  @override
  String get port => '端口';

  @override
  String get game => '游戏';

  @override
  String get type => '类型';

  @override
  String get leave => '离开';

  @override
  String get leaveRoom => '即将退出房间';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get disconnected => '连接断开';

  @override
  String get roomClosed => '房间已关闭';

  @override
  String get cannotReconnect => '无法重新连接到服务器';

  @override
  String reconnecting(int cur, int max) {
    return '正在尝试重新连接... ($cur/$max)';
  }

  @override
  String get competitorsWithdraw => '对手退出';

  @override
  String get opponentWithdrawn => '对手已退出';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get wait => '等待中';

  @override
  String get youSurrendered => '你认输了';

  @override
  String get opponentSurrendered => '对方投降';

  @override
  String get chatRoom => '聊天室';

  @override
  String get online => '在线';

  @override
  String get connecting => '连接中...';

  @override
  String get members => '成员列表';

  @override
  String get chatSettings => '聊天设置';

  @override
  String get clearHistory => '清空聊天记录';

  @override
  String get clearHistoryConfirm => '确定要清空所有聊天记录吗？此操作不可撤销。';

  @override
  String get darkMode => '深色模式';

  @override
  String get messageNotification => '消息通知';

  @override
  String get attachment => '附件';

  @override
  String get album => '相册';

  @override
  String get camera => '拍照';

  @override
  String get file => '文件';

  @override
  String get location => '位置';

  @override
  String get imageLoadFailed => '图片加载失败';

  @override
  String get unknownFile => '未知文件';

  @override
  String get selectImageFailed => '选择图片失败';

  @override
  String get takePhotoFailed => '拍照失败';

  @override
  String get sendImageFailed => '发送图片失败';

  @override
  String get selectFileFailed => '选择文件失败';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get saveSuccess => '文件已保存';

  @override
  String get saveFailed => '保存失败';

  @override
  String get savedTo => '已保存到';

  @override
  String get downloading => '正在保存...';

  @override
  String get emojiCommon => '常用';

  @override
  String get emojiGesture => '手势';

  @override
  String get emojiHeart => '心形';

  @override
  String get emojiAnimal => '动物';

  @override
  String get emojiFood => '食物';

  @override
  String get emojiSport => '运动';

  @override
  String get emojiTravel => '旅行';

  @override
  String get emojiSymbol => '符号';

  @override
  String get stepDisconnect => '等待连接';

  @override
  String get stepConnected => '已连接，等待对手加入...';

  @override
  String get stepFrontConfig => '请配置';

  @override
  String get stepRearWait => '等待先手配置';

  @override
  String get stepFrontWait => '等待后手配置';

  @override
  String get stepRearConfig => '请配置或查看对方配置';

  @override
  String get stepAction => '进行中';

  @override
  String get stepGameOver => '游戏结束';

  @override
  String get animalChess => '斗兽棋';

  @override
  String get netAnimalChess => '联机斗兽棋';

  @override
  String get setBoardSize => '设置棋盘大小';

  @override
  String get redTurn => '红方回合';

  @override
  String get blueTurn => '蓝方回合';

  @override
  String get yourTurn => '你的回合';

  @override
  String get opponentTurn => '对方回合';

  @override
  String get redWin => '红方获胜！';

  @override
  String get blueWin => '蓝方获胜！';

  @override
  String get gobang => '五子棋';

  @override
  String get netGobang => '联机五子棋';

  @override
  String get blackSide => '黑方';

  @override
  String get whiteSide => '白方';

  @override
  String currentTurn(String side) {
    return '当前回合: $side';
  }

  @override
  String sideWin(String side) {
    return '$side获胜!';
  }

  @override
  String yourSideTurn(String side) {
    return '你的回合 $side';
  }

  @override
  String opponentSideTurn(String side) {
    return '对方回合 $side';
  }

  @override
  String get aiLabel => 'AI';

  @override
  String get aiThinking => 'AI 思考中…';

  @override
  String get undo => '悔棋';

  @override
  String get weiqi => '围棋';

  @override
  String get finalLength => '最终长度';

  @override
  String get sudoku => '数独';

  @override
  String get setDifficulty => '设置难度';

  @override
  String get pleaseConfirm => '请确认';

  @override
  String get leaveRoomLoseProgress => '离开房间将丢失进度';

  @override
  String get congratulations => '恭喜完成！';

  @override
  String difficultyTime(String d, String t) {
    return '难度: $d 用时: $t';
  }

  @override
  String get startNewGame => '开始新游戏';

  @override
  String get importPuzzle => '导入棋局';

  @override
  String get importFailConflict => '棋盘中存在冲突，请检查行、列或宫格中是否有重复数字';

  @override
  String get importFailEmpty => '请至少填写一个数字';

  @override
  String get importFailNotUnique => '该棋局没有唯一解，请调整数字';

  @override
  String get confirmImport => '确认导入';

  @override
  String get cancelImport => '取消';

  @override
  String get guess => '猜枚';

  @override
  String timeTaken(int s) {
    return '用时: $s 秒';
  }

  @override
  String correctCount(int c) {
    return '正确次数: $c';
  }

  @override
  String get memoryCard => '记忆翻牌';

  @override
  String remainingPairs(int v) {
    return '剩余 $v 对';
  }

  @override
  String get bestTimeLabel => '最佳用时';

  @override
  String get schulte => '舒尔特';

  @override
  String nextNumber(int v) {
    return '下一个: $v';
  }

  @override
  String get threeTiles => '羊了个羊';

  @override
  String timeSeconds(int v) {
    return '时间: $v 秒';
  }

  @override
  String remaining(int v) {
    return '剩余: $v';
  }

  @override
  String get youLost => '你输了';

  @override
  String get chooseDifficulty => '选择难度';

  @override
  String get easy => '简单';

  @override
  String get medium => '中等';

  @override
  String get hard => '困难';

  @override
  String difficultyTimeSeconds(String d, int t) {
    return '难度: $d 用时: $t 秒';
  }

  @override
  String get spaceship => '星际战机';

  @override
  String lives(double v) {
    return '生命: $v';
  }

  @override
  String score(int v) {
    return '分数: $v';
  }

  @override
  String level(int v) {
    return '等级: $v';
  }

  @override
  String get startGame => '开始游戏';

  @override
  String get gamePaused => '游戏暂停';

  @override
  String get continueGame => '继续游戏';

  @override
  String get settings => '设置';

  @override
  String get general => '通用';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get restartGame => '重新开始';

  @override
  String get exitGame => '退出游戏';

  @override
  String get levelUp => '等级提升';

  @override
  String currentLevel(int v) {
    return '当前等级: $v';
  }

  @override
  String get harderChallenge => '准备迎接更难的挑战!';

  @override
  String get finalScore => '最终得分';

  @override
  String get reachedLevel => '达到等级';

  @override
  String get unlockedAchievement => '解锁成就';

  @override
  String get playAgain => '再玩一次';

  @override
  String get backToHome => '返回主页';

  @override
  String get noAchievements => '没有解锁任何成就';

  @override
  String get enemyEscaped => '敌人逃脱！';

  @override
  String get bossAppear => 'Boss出现！';

  @override
  String get sensitivitySetting => '灵敏度设置';

  @override
  String get mapDataEmpty => '地图数据为空';

  @override
  String get boardDataEmpty => '棋盘数据为空';

  @override
  String get achFirstKill => '初露锋芒';

  @override
  String get achFirstKillDesc => '首次击败敌人';

  @override
  String get achScore100 => '百炼成钢';

  @override
  String get achScore100Desc => '得分达到100分';

  @override
  String get achScore500 => '半壁江山';

  @override
  String get achScore500Desc => '得分达到500分';

  @override
  String get achScore1000 => '千锤百炼';

  @override
  String get achScore1000Desc => '得分达到1000分';

  @override
  String get achLevel5 => '五级挑战';

  @override
  String get achLevel5Desc => '达到5级';

  @override
  String get achLevel10 => '十级大师';

  @override
  String get achLevel10Desc => '达到10级';

  @override
  String get achBossHunter => 'Boss猎手';

  @override
  String get achBossHunterDesc => '首次击败BOSS';

  @override
  String get achEightKills => '八连杀';

  @override
  String get achEightKillsDesc => '连续击败八个敌人';

  @override
  String get towerDefense => '塔防';

  @override
  String get surrender => '投降';

  @override
  String get startWave => '开始波次';

  @override
  String get netTowerDefense => '联机塔防';

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
  String get attack => '攻击';

  @override
  String get parry => '格挡';

  @override
  String get skill => '技能';

  @override
  String get escape => '逃跑';

  @override
  String get pursuit => '追击';

  @override
  String get victory => '胜利';

  @override
  String get defeat => '失败';

  @override
  String get win => '胜利';

  @override
  String get youWon => '你获得了胜利！';

  @override
  String get youLost2 => '很遗憾，你输了...';

  @override
  String get youEscaped => '你成功逃脱了战斗';

  @override
  String get opponentEscaped => '对方逃跑了';

  @override
  String get yourTurnAct => '你的回合，请行动';

  @override
  String get enemyTurnWait => '敌人的回合，请等待';

  @override
  String choseAttack(String name) {
    return '$name 选择了 攻击';
  }

  @override
  String castSkill(String src, String skill, String tgt, String desc) {
    return '$src 施放了技能 $skill\n$tgt 获得效果 $desc';
  }

  @override
  String switchIn(String name) {
    return '$name 上场';
  }

  @override
  String switchTo(String from, String to) {
    return '$from 切换为 $to';
  }

  @override
  String get levelLabel => '等级';

  @override
  String get healthLabel => '生命值';

  @override
  String get attackLabel => '攻击力';

  @override
  String get defenceLabel => '防御力';

  @override
  String get selectEnergy => '选择一个灵根';

  @override
  String get selectSkill => '选择一个技能';

  @override
  String get chooseEnergy => '选择灵根:';

  @override
  String get chooseAttribute => '选择属性:';

  @override
  String get enemyImp => '小鬼';

  @override
  String get enemyClown => '小丑';

  @override
  String get enemyDemon => '恶魔';

  @override
  String get enemyKing => '鬼王';

  @override
  String get dummy => '假人';

  @override
  String get traveler => '旅行者';

  @override
  String floorName(int v) {
    return '地下$v层';
  }

  @override
  String get mainCity => '主城';

  @override
  String get returnedToCity => '你回到了主城';

  @override
  String get notice => '提示';

  @override
  String get slept => '你睡了一觉，恢复了状态';

  @override
  String get gotMedicine => '你得到了一个药';

  @override
  String get gotWeapon => '你得到了一个武器';

  @override
  String get gotArmor => '你得到了一个防具';

  @override
  String gotMoneyBag(int m) {
    return '你得到了一个钱袋，获得了$m枚金币';
  }

  @override
  String get cannotContinue => '无法继续冒险';

  @override
  String get levelUpSuccess => '升级成功！';

  @override
  String get notEnoughExp => '经验不足！';

  @override
  String get backpack => '背包';

  @override
  String get status => '状态';

  @override
  String get switchElement => '切换';

  @override
  String get store => '商店';

  @override
  String get buy => '购买';

  @override
  String get use => '使用';

  @override
  String get learn => '学习';

  @override
  String get forget => '遗忘';

  @override
  String get active => '主动';

  @override
  String get passive => '被动';

  @override
  String get preparing => '准备中';

  @override
  String get configCharacter => '配置角色';

  @override
  String get viewOpponent => '查看对手信息';

  @override
  String get characterConfig => '角色配置';

  @override
  String remainingPoints(int v) {
    return '剩余点数: $v';
  }

  @override
  String coinCount(int v) {
    return '金币数量: $v';
  }

  @override
  String itemName(String n) {
    return '名称:$n';
  }

  @override
  String get buySuccess => '购买成功';

  @override
  String get notEnoughCoins => '金币不足';

  @override
  String get learnSuccess => '学习成功！';

  @override
  String skillTarget(String t) {
    return '目标: $t';
  }

  @override
  String skillEffect(String d) {
    return '效果: $d';
  }

  @override
  String get notYourTurn => '不是你的回合';

  @override
  String get serverNotYourTurn => '\n服务器：不是你的回合\n';

  @override
  String exp(int v) {
    return '经验: $v';
  }

  @override
  String lv(int v) {
    return '等级: $v';
  }

  @override
  String hpCap(int v) {
    return '生命值上限: $v';
  }

  @override
  String baseAtk(int v) {
    return '初始攻击力: $v';
  }

  @override
  String baseDef(int v) {
    return '初始防御力: $v';
  }

  @override
  String curHp(int v) {
    return '当前生命值: $v';
  }

  @override
  String curAtk(int v) {
    return '当前攻击力: $v';
  }

  @override
  String curDef(int v) {
    return '当前防御力: $v';
  }

  @override
  String get masteredSkills => '掌握技能:';

  @override
  String get activeEffects => '获得影响:';

  @override
  String get potion => '药';

  @override
  String get potionDesc => '生命值+32';

  @override
  String get sword => '剑';

  @override
  String get swordDesc => '攻击力+8';

  @override
  String get shield => '盾';

  @override
  String get shieldDesc => '防御力+8';

  @override
  String get scroll => '回城卷轴';

  @override
  String get scrollDesc => '随时随地可以回家';

  @override
  String get targetSelfFront => '所属灵根';

  @override
  String get targetSelfAny => '任一灵根';

  @override
  String get targetEnemyFront => '敌方当前灵根';

  @override
  String get targetEnemyAny => '敌方任一灵根';

  @override
  String get skParry => '格挡';

  @override
  String get skParryDesc => '防守时，减少75%受到的伤害，生效一次。';

  @override
  String get skMetalP0 => '攻防兼备';

  @override
  String get skMetalP0Desc => '战斗时，获得50%额外的攻击力和防御力。';

  @override
  String get skWoodP0 => '叶落归根';

  @override
  String get skWoodP0Desc => '造成伤害后，根据伤害量的25%，回复生命。';

  @override
  String get skWaterP0 => '水无常形';

  @override
  String get skWaterP0Desc =>
      '受到伤害后，防御力减少，根据减少量的75%，提高攻击力，如果是法术伤害，还会因此附魔。\n\n兵无常势，水无常形。';

  @override
  String get skFireP0 => '燃烧吧';

  @override
  String get skFireP0Desc => '攻击时，获得100%附魔，所有伤害均为无视防御的法术伤害。\n\n燃起来了。';

  @override
  String get skEarthP0 => '厚积薄发';

  @override
  String get skEarthP0Desc =>
      '受到伤害后，将物理伤害的50%和法术伤害的15%作为加成，提高下次攻击的攻击力。\n\n大地会记住一切。';

  @override
  String get skMetalA0 => '以退为进';

  @override
  String get skMetalA0Desc => '下次攻击时，额外进行一次，生效一次。';

  @override
  String get skWoodA0 => '根深蒂固';

  @override
  String get skWoodA0Desc => '根据自身生命上限的12.5%回复生命，生效一次。';

  @override
  String get skWaterA0 => '拖泥带水';

  @override
  String get skWaterA0Desc => '下次攻击时，减少50%的攻击力，生效两次。';

  @override
  String get skFireA0 => '爆裂魔法';

  @override
  String get skFireA0Desc => '生命值降为1，根据降低的比例，提高伤害系数，并进行一次攻击。\n\n Explosion！';

  @override
  String get skEarthA0 => '不动如山';

  @override
  String get skEarthA0Desc => '下次受到伤害时，进行一次攻击。\n力的作用是相互的。';

  @override
  String get skMetalAdv0 => '以逸待劳';

  @override
  String get skMetalAdv0Desc => '以退为进可以施加给己方任一灵根，使其下次攻击时，额外进行一次。';

  @override
  String get skWoodAdv0 => '开枝散叶';

  @override
  String get skWoodAdv0Desc => '根深蒂固可以施加给己方任一灵根，根据自身生命上限的12.5%回复其生命。';

  @override
  String get skWaterAdv0 => '水泄不通';

  @override
  String get skWaterAdv0Desc => '拖泥带水可以施加给敌方任一灵根，使其下次攻击时，减少50%的攻击力，生效两次。';

  @override
  String get skFireAdv0 => '薪火相传';

  @override
  String get skFireAdv0Desc =>
      '爆裂魔法可以施加给己方任一灵根，使其生命值降为1，根据降低的比例，提高伤害系数，并上场进行一次攻击。';

  @override
  String get skEarthAdv0 => '玉石俱焚';

  @override
  String get skEarthAdv0Desc => '不动如山可以施加给己方任一灵根，使其下次受到伤害时，进行一次攻击。';

  @override
  String get skMetalAux0 => '全副武装';

  @override
  String get skMetalAux0Desc => '战斗时，额外获得50%的攻击力和防御力，生效两次。';

  @override
  String get skWoodAux0 => '移花接木';

  @override
  String get skWoodAux0Desc => '造成伤害时，根据伤害量的25%，回复生命，生效两次。';

  @override
  String get skWaterAux0 => '因地制流';

  @override
  String get skWaterAux0Desc =>
      '受到伤害后，防御力减少，根据减少量的75%，提高攻击力，生效两次。\n\n水因地制流，兵因敌制胜。';

  @override
  String get skFireAux0 => '火力全开';

  @override
  String get skFireAux0Desc => '攻击时，获得100%附魔比例，造成无视防御的法术伤害，生效两次。\n\n对他使用炎拳吧！';

  @override
  String get skEarthAux0 => '卷土重来';

  @override
  String get skEarthAux0Desc => '受到伤害后，将物理伤害的50%和法术伤害的15%作为加成，提高下次攻击的攻击力，生效两次。';

  @override
  String get skMetalF0 => '屠龙';

  @override
  String get skMetalF0Desc => '攻击时，基于敌方当前生命值的25%，提高自身攻击力，生效一次。';

  @override
  String get skWoodF0 => '桎梏';

  @override
  String get skWoodF0Desc => '回复生命时，溢出的治疗量会提高生命值上限。';

  @override
  String get skWaterF0 => '止水';

  @override
  String get skWaterF0Desc => '受到致命伤害时，生命值回复到1，生效一次。\n\n区区致命伤。';

  @override
  String get skFireF0 => '灼烧';

  @override
  String get skFireF0Desc =>
      '造成的法术伤害，会使敌人烧伤，使其再次受到伤害时，追加本次伤害值25%的伤害，生效两次。\n\n阿玛忒拉斯。';

  @override
  String get skEarthF0 => '砥砺';

  @override
  String get skEarthF0Desc => '受到伤害时，将已损失生命值的25%作为攻击力，造成一次伤害系数为25%的物理伤害，生效两次。';

  @override
  String healLog(String name, int actual, int hp) {
    return '$name 回复了 $actual 生命值，当前生命值 $hp';
  }

  @override
  String selfDamageLog(String name, int dmg) {
    return '$name 对自身造成 $dmg 伤害，伤害系数提高';
  }

  @override
  String damageLogPhysical(String name, int dmg, int hp) {
    return '$name 受到 $dmg 物理 伤害, 生命值 $hp';
  }

  @override
  String damageLogMagic(String name, int dmg, int hp) {
    return '$name 受到 $dmg 法术 伤害, 生命值 $hp';
  }

  @override
  String get mapDataEmpty2 => '地图数据为空';

  @override
  String get boardDataEmpty2 => '棋盘数据为空';

  @override
  String get roomTypeChat => '聊天室';

  @override
  String get elementalBattle => '五行之战';

  @override
  String get greedySnake => '贪吃蛇';

  @override
  String get soft => '软环';

  @override
  String get minecraft => '我的世界';
}
