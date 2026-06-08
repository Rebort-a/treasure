import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/03.animal_chess/base.dart';

void main() {
  group('Animal Chess', () {
    group('吃子规则 canEat', () {
      // 辅助方法：创建指定类型的动物
      Animal animal(AnimalType type, [TurnGamerType owner = TurnGamerType.front]) {
        return Animal(type: type, owner: owner, isHidden: false);
      }

      test('大象吃狮子', () {
        expect(animal(AnimalType.elephant).canEat(animal(AnimalType.lion)), isTrue);
      });

      test('狮子吃狗', () {
        expect(animal(AnimalType.lion).canEat(animal(AnimalType.dog)), isTrue);
      });

      test('狗不能吃狮子', () {
        expect(animal(AnimalType.dog).canEat(animal(AnimalType.lion)), isFalse);
      });

      test('老鼠吃大象（特殊规则）', () {
        expect(animal(AnimalType.mouse).canEat(animal(AnimalType.elephant)), isTrue);
      });

      test('大象不能吃老鼠（特殊规则）', () {
        expect(animal(AnimalType.elephant).canEat(animal(AnimalType.mouse)), isFalse);
      });

      test('同类相吃返回 true', () {
        expect(animal(AnimalType.lion).canEat(animal(AnimalType.lion)), isTrue);
      });

      test('吃空位置返回 true', () {
        expect(animal(AnimalType.mouse).canEat(null), isTrue);
      });

      test('完整等级链：象 > 狮 > 虎 > 豹 > 狼 > 狗 > 猫 > 鼠', () {
        final types = AnimalType.values;
        for (int i = 0; i < types.length; i++) {
          for (int j = 0; j < types.length; j++) {
            if (i == j) continue; // 同类跳过
            final a = animal(types[i]);
            final b = animal(types[j]);
            if (i == 0 && j == types.length - 1) {
              // 象 vs 鼠 → 象不能吃鼠
              expect(a.canEat(b), isFalse);
            } else if (i == types.length - 1 && j == 0) {
              // 鼠 vs 象 → 鼠能吃象
              expect(a.canEat(b), isTrue);
            } else if (i < j) {
              expect(a.canEat(b), isTrue, reason: '${types[i].name} should eat ${types[j].name}');
            } else {
              expect(a.canEat(b), isFalse, reason: '${types[i].name} should NOT eat ${types[j].name}');
            }
          }
        }
      });
    });

    group('移动规则 canMoveTo', () {
      Animal animal(AnimalType type) {
        return Animal(type: type, owner: TurnGamerType.front, isHidden: false);
      }

      group('进入河流', () {
        test('大象可以进入河流', () {
          expect(animal(AnimalType.elephant).canMoveTo(GridType.land, GridType.river), isTrue);
        });

        test('狗可以进入河流', () {
          expect(animal(AnimalType.dog).canMoveTo(GridType.land, GridType.river), isTrue);
        });

        test('老鼠可以进入河流', () {
          expect(animal(AnimalType.mouse).canMoveTo(GridType.land, GridType.river), isTrue);
        });

        test('狮子不能进入河流', () {
          expect(animal(AnimalType.lion).canMoveTo(GridType.land, GridType.river), isFalse);
        });

        test('老虎不能进入河流', () {
          expect(animal(AnimalType.tiger).canMoveTo(GridType.land, GridType.river), isFalse);
        });

        test('豹不能进入河流', () {
          expect(animal(AnimalType.leopard).canMoveTo(GridType.land, GridType.river), isFalse);
        });

        test('狼不能进入河流', () {
          expect(animal(AnimalType.wolf).canMoveTo(GridType.land, GridType.river), isFalse);
        });

        test('猫不能进入河流', () {
          expect(animal(AnimalType.cat).canMoveTo(GridType.land, GridType.river), isFalse);
        });
      });

      group('使用桥梁', () {
        test('地面上的非大象动物可以过桥', () {
          expect(animal(AnimalType.lion).canMoveTo(GridType.land, GridType.bridge), isTrue);
          expect(animal(AnimalType.tiger).canMoveTo(GridType.land, GridType.bridge), isTrue);
          expect(animal(AnimalType.mouse).canMoveTo(GridType.land, GridType.bridge), isTrue);
        });

        test('大象不能过桥', () {
          expect(animal(AnimalType.elephant).canMoveTo(GridType.land, GridType.bridge), isFalse);
        });

        test('水中的老鼠可以过桥', () {
          expect(animal(AnimalType.mouse).canMoveTo(GridType.river, GridType.bridge), isTrue);
        });

        test('水中的非老鼠动物不能过桥', () {
          expect(animal(AnimalType.dog).canMoveTo(GridType.river, GridType.bridge), isFalse);
          expect(animal(AnimalType.elephant).canMoveTo(GridType.river, GridType.bridge), isFalse);
        });
      });

      group('攀爬树木', () {
        test('豹可以爬树', () {
          expect(animal(AnimalType.leopard).canMoveTo(GridType.land, GridType.tree), isTrue);
        });

        test('猫可以爬树', () {
          expect(animal(AnimalType.cat).canMoveTo(GridType.land, GridType.tree), isTrue);
        });

        test('老鼠可以爬树', () {
          expect(animal(AnimalType.mouse).canMoveTo(GridType.land, GridType.tree), isTrue);
        });

        test('狮子不能爬树', () {
          expect(animal(AnimalType.lion).canMoveTo(GridType.land, GridType.tree), isFalse);
        });

        test('大象不能爬树', () {
          expect(animal(AnimalType.elephant).canMoveTo(GridType.land, GridType.tree), isFalse);
        });
      });

      group('普通地面移动', () {
        test('所有动物都可以在地面上移动', () {
          for (final type in AnimalType.values) {
            expect(animal(type).canMoveTo(GridType.land, GridType.land), isTrue);
          }
        });

        test('所有动物都可以走上道路', () {
          for (final type in AnimalType.values) {
            expect(animal(type).canMoveTo(GridType.land, GridType.road), isTrue);
          }
        });
      });
    });

    group('Animal 基本属性', () {
      test('默认 isHidden 为 true', () {
        final a = Animal(type: AnimalType.lion, owner: TurnGamerType.front);
        expect(a.isHidden, isTrue);
      });

      test('isSelected 默认为 false', () {
        final a = Animal(type: AnimalType.lion, owner: TurnGamerType.front);
        expect(a.isSelected, isFalse);
      });

      test('owner 属性正确', () {
        final red = Animal(type: AnimalType.lion, owner: TurnGamerType.front);
        final blue = Animal(type: AnimalType.lion, owner: TurnGamerType.rear);
        expect(red.owner, TurnGamerType.front);
        expect(blue.owner, TurnGamerType.rear);
      });
    });

    group('Grid 基本属性', () {
      test('hasAnimal 正确判断', () {
        final emptyGrid = Grid(coordinate: 0, type: GridType.land);
        expect(emptyGrid.hasAnimal, isFalse);

        final occupiedGrid = Grid(
          coordinate: 1,
          type: GridType.land,
          animal: Animal(type: AnimalType.lion, owner: TurnGamerType.front),
        );
        expect(occupiedGrid.hasAnimal, isTrue);
      });
    });
  });
}
