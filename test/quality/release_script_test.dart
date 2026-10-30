import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 使用真实的临时 Git 仓库模拟推送，所有 GitHub 请求均由本地替身处理。
class _ReleaseFixture {
  final Directory root;
  final String bash;
  late final Directory work = Directory('${root.path}/work');
  late final Directory remote = Directory('${root.path}/remote.git');
  late final Map<String, String> environment = {
    'GIT_CONFIG_NOSYSTEM': '1',
    'GIT_CONFIG_GLOBAL': '${root.path}/global.gitconfig',
    'GIT_TERMINAL_PROMPT': '0',
    'RELEASE_SKIP_CHECK': '0',
  };
  late final String initialCommit;

  _ReleaseFixture(this.root, this.bash);

  static Future<_ReleaseFixture> create() async {
    var bash = 'bash';
    if (Platform.isWindows) {
      final result = await Process.run('where.exe', ['git']);
      final candidates = result.stdout.toString().trim().split(
        RegExp(r'\r?\n'),
      );
      bash = candidates
          .map((path) => '${File(path).parent.parent.path}/bin/bash.exe')
          .firstWhere((path) => File(path).existsSync());
    }
    final fixture = _ReleaseFixture(
      await Directory.systemTemp.createTemp('treasure_release_'),
      bash,
    );
    try {
      await fixture._initialize();
      return fixture;
    } catch (_) {
      await fixture.dispose();
      rethrow;
    }
  }

  Future<ProcessResult> _process(String executable, List<String> arguments) =>
      Process.run(
        executable,
        arguments,
        workingDirectory: work.path,
        environment: environment,
      );

  Future<String> git(List<String> arguments) async {
    final result = await _process('git', arguments);
    if (result.exitCode != 0) {
      throw StateError('git $arguments\n${result.stdout}\n${result.stderr}');
    }
    return result.stdout.toString().trim();
  }

  Future<void> _initialize() async {
    await work.create();
    await Directory('${root.path}/bin').create();
    await File('${root.path}/global.gitconfig').writeAsString('');
    await git(['init', '--bare', remote.path]);
    await git(['init', '-b', 'main']);
    await git(['config', 'user.name', 'Release Test']);
    await git(['config', 'user.email', 'release@example.com']);
    await Directory('${work.path}/scripts').create();
    await File('scripts/release.sh').copy('${work.path}/scripts/release.sh');
    await File('${work.path}/pubspec.yaml').writeAsString('version: 1.2.3+4\n');
    await File('${work.path}/CHANGELOG.md').writeAsString(
      '# Changelog\n\n## [1.2.3] - 2026-01-01\n\n- Initial fixture\n',
    );
    await File('${root.path}/bin/gh').writeAsString(r'''#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> ../gh-calls.log
case "$1 $2" in
  "auth status")
    [[ "${RELEASE_TEST_MODE:-}" != unauthenticated ]]
    ;;
  "run list")
    workflow="" branch="" commit="" event=""
    shift 2
    while (( $# > 0 )); do
      case "$1" in
        --workflow) workflow="$2"; shift 2 ;;
        --branch) branch="$2"; shift 2 ;;
        --commit) commit="$2"; shift 2 ;;
        --event) event="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ "$workflow" == release.yml ]] || exit 1
    if [[ -z "$branch" ]]; then
      [[ "${RELEASE_TEST_MODE:-}" != unreadable ]] || exit 1
      echo '[]'
    elif [[ "${RELEASE_TEST_MODE:-}" == query-failure ]]; then
      exit 1
    elif [[ "${RELEASE_TEST_MODE:-}" != missing-run &&
            "$branch" == "$(git describe --tags --exact-match HEAD)" &&
            "$commit" == "$(git rev-parse HEAD)" && "$event" == push ]]; then
      if [[ "${RELEASE_TEST_MODE:-}" == delayed-run && ! -f ../queried ]]; then
        touch ../queried
      else
        echo 12345
      fi
    fi
    ;;
  "run watch")
    [[ "${RELEASE_TEST_MODE:-}" != failed-build ]]
    ;;
  *) exit 1 ;;
esac
''');
    await File('${root.path}/bin/sleep')
        .writeAsString('#!/usr/bin/env bash\nexit 0\n');
    final chmod = await _process(bash, [
      '-c',
      'chmod +x ../bin/gh ../bin/sleep',
    ]);
    if (chmod.exitCode != 0) throw StateError('${chmod.stderr}');
    await git(['add', '.']);
    await git([
      'commit',
      '-m',
      'chore: initialize release fixture',
      '-m',
      '- Create an isolated repository for release verification',
    ]);
    initialCommit = await git(['rev-parse', 'HEAD']);
    const url = 'https://github.com/release-fixture/treasure.git';
    await git(['remote', 'add', 'origin', url]);
    final remotePath = remote.path.replaceAll(r'\', '/');
    await git(['config', 'url.$remotePath.insteadOf', url]);
    // 在任何推送前验证地址重写，测试绝不能访问真实 GitHub 仓库。
    expect(await git(['remote', 'get-url', 'origin']), remotePath);
    await git(['push', 'origin', 'main']);
  }

  Future<void> hook(String name, String contents) async {
    await File('${remote.path}/hooks/$name')
        .writeAsString('#!/usr/bin/env bash\nset -eu\n$contents\n');
    final result = await _process(bash, [
      '-c',
      'chmod +x ../remote.git/hooks/$name',
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<ProcessResult> release({
    String mode = '',
    List<String> arguments = const [],
    String? message = '- Verify the release workflow',
  }) {
    environment['RELEASE_TEST_MODE'] = mode;
    return _process(bash, [
      '-c',
      r'export PATH="$PWD/../bin:$PATH"; exec bash scripts/release.sh "$@"',
      '--',
      '--yes',
      ...arguments,
      if (message != null) ...['--message', message],
    ]);
  }

  Future<String> remoteRef(String ref) =>
      git(['--git-dir=${remote.path}', 'rev-parse', ref]);

  Future<String> calls() => File('${root.path}/gh-calls.log').readAsString();

  Future<void> dispose() => root.delete(recursive: true);
}

void main() {
  late _ReleaseFixture fixture;
  setUp(() async => fixture = await _ReleaseFixture.create());
  tearDown(() async => fixture.dispose());

  test('缺省发布正文为英文列表，非法列表在修改前拒绝', () async {
    for (final message in ['No list marker', '- ']) {
      final invalid = await fixture.release(message: message);
      expect(invalid.exitCode, isNot(0));
      expect(await fixture.git(['rev-parse', 'HEAD']), fixture.initialCommit);
      expect(await fixture.git(['status', '--porcelain']), isEmpty);
      expect(await fixture.git(['tag', '--list']), isEmpty);
    }
    final result = await fixture.release(
      message: null,
      arguments: ['--skip-wait'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      await fixture.git(['log', '-1', '--format=%b']),
      '- Prepare release v1.2.4',
    );
  });

  for (final (type, tag, title) in [
    ('patch', 'v1.2.4', 'release: v1.2.4'),
    ('minor', 'v1.3.0', 'Release: v1.3.0'),
    ('major', 'v2.0.0', 'RELEASE: v2.0.0'),
  ]) {
    test('发布 $type 时远程提交与标签一致，并确认对应运行及构建结果', () async {
      final result = await fixture.release(arguments: ['--$type']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final commit = await fixture.git(['rev-parse', 'HEAD']);
      expect(await fixture.remoteRef('refs/heads/main'), commit);
      expect(await fixture.remoteRef('refs/tags/$tag^{commit}'), commit);
      expect(await fixture.git(['log', '-1', '--format=%s']), title);
      expect(await fixture.calls(), contains('run watch 12345'));
      expect(await fixture.git(['status', '--porcelain']), isEmpty);
    });
  }

  test('跳过等待仍确认运行已创建，并允许注册延迟，但不等待构建结束', () async {
    final result = await fixture.release(
      mode: 'delayed-run',
      arguments: ['--skip-wait'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final commit = await fixture.git(['rev-parse', 'HEAD']);
    expect(await fixture.remoteRef('refs/tags/v1.2.4^{commit}'), commit);
    final calls = await fixture.calls();
    expect(calls, contains('--branch v1.2.4'));
    expect(calls, contains('--commit $commit'));
    expect(calls, contains('--event push'));
    expect(calls, isNot(contains('run watch')));
    expect(File('${fixture.root.path}/queried').existsSync(), isTrue);
  });

  for (final mode in ['unauthenticated', 'unreadable']) {
    test('发布前 $mode 时不修改版本、不创建提交或推送', () async {
      final result = await fixture.release(mode: mode);
      expect(result.exitCode, isNot(0));
      expect(await fixture.git(['rev-parse', 'HEAD']), fixture.initialCommit);
      expect(await fixture.git(['tag', '--list']), isEmpty);
      expect(await fixture.git(['status', '--porcelain']), isEmpty);
      expect(await fixture.remoteRef('refs/heads/main'), fixture.initialCommit);
    });
  }

  test('预览不需要 GitHub 登录，且不修改版本、提交或远程引用', () async {
    final result = await fixture.release(
      mode: 'unauthenticated',
      arguments: ['--dry-run'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await fixture.git(['rev-parse', 'HEAD']), fixture.initialCommit);
    expect(await fixture.git(['status', '--porcelain']), isEmpty);
    expect(await fixture.remoteRef('refs/heads/main'), fixture.initialCommit);
    expect(File('${fixture.root.path}/gh-calls.log').existsSync(), isFalse);
  });

  test('只有远程存在同名标签时，也必须在改版本和创建提交之前拒绝发布', () async {
    await fixture.git([
      '--git-dir=${fixture.remote.path}',
      'update-ref',
      'refs/tags/v1.2.4',
      fixture.initialCommit,
    ]);
    final result = await fixture.release();
    expect(result.exitCode, isNot(0));
    expect(await fixture.git(['rev-parse', 'HEAD']), fixture.initialCommit);
    expect(await fixture.git(['status', '--porcelain']), isEmpty);
    expect(await fixture.remoteRef('refs/tags/v1.2.4'), fixture.initialCommit);
    expect(await fixture.remoteRef('refs/heads/main'), fixture.initialCommit);
  });

  test('远程拒绝标签时原子推送不能单独更新主分支', () async {
    await fixture.hook('pre-receive', r'''
while read -r old new ref; do
  if [[ "$ref" == refs/tags/* ]]; then exit 1; fi
done
''');
    final result = await fixture.release();
    expect(result.exitCode, isNot(0));
    expect(await fixture.remoteRef('refs/heads/main'), fixture.initialCommit);
    expect(
      await fixture.git(['--git-dir=${fixture.remote.path}', 'tag', '--list']),
      isEmpty,
    );
    expect(await fixture.calls(), isNot(contains('run watch')));
  });

  for (final mismatch in ['missing', 'wrong-commit']) {
    test('推送后远程标签 $mismatch 时必须失败，不查询或等待构建', () async {
      await fixture.hook('post-receive', '''
while read -r old new ref; do
  if [[ "\$ref" == refs/tags/* ]]; then
    ${mismatch == 'missing' ? 'git update-ref -d "\$ref"' : 'git update-ref "\$ref" ${fixture.initialCommit}'}
  fi
done
''');
      final result = await fixture.release(arguments: ['--skip-wait']);
      expect(result.exitCode, isNot(0));
      expect(await fixture.calls(), isNot(contains('--branch')));
    });
  }

  for (final mode in ['missing-run', 'query-failure', 'failed-build']) {
    test('发布后 $mode 时返回失败，不能误报发布完成', () async {
      final result = await fixture.release(
        mode: mode,
        arguments: mode == 'failed-build' ? [] : ['--skip-wait'],
      );
      expect(result.exitCode, isNot(0));
      expect(
        await fixture.remoteRef('refs/tags/v1.2.4^{commit}'),
        await fixture.git(['rev-parse', 'HEAD']),
      );
      final calls = await fixture.calls();
      expect(calls, contains('--branch v1.2.4'));
      expect(calls.contains('run watch'), mode == 'failed-build');
    });
  }
}
