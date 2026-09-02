#!/usr/bin/env bash
set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── 帮助 ───────────────────────────────────────────────
usage() {
  cat <<'EOF'
用法: release.sh [--major|--minor|--patch] [选项]

版本类型（不指定时默认 --patch，决定版本递增与提交信息标题前缀）:
  --patch             递增小版本   1.0.3 → 1.0.4   标题前缀 "release:"（默认）
  --minor             递增中版本   1.0.3 → 1.1.0   标题前缀 "Release:"
  --major             递增大版本   1.0.3 → 2.0.0   标题前缀 "RELEASE:"
  提交信息标题（release:/Release:/RELEASE:）由脚本生成，-m 仅提供标题之后的正文，
  故 release.sh 提交的 commit message 开头一定是生成的，不可通过 -m 篡改。

  注：非以上三种前缀的普通改动（feat:/fix:/ci: 等）请直接 git commit，
      由 flutter.yml 处理（push main → CI + 部署 GitHub Pages），不要用本脚本发布。

选项:
  -m, --message MSG       提交信息正文（标题「前缀 vX.Y.Z」之后的内容），不指定则无正文
  -v, --version VERSION   指定版本号 (例: 2.0.0)，覆盖版本递增；标题仍由 --major/--minor/--patch（默认 patch）决定
  -n, --dry-run           预览模式，不实际执行
  -y, --yes               跳过确认提示
  --skip-changelog        跳过 CHANGELOG.md 自动更新
  --skip-wait             不等待 GitHub Actions 结果（默认会等待并校验）
  -h, --help              显示帮助

示例（标题格式固定为「前缀 vX.Y.Z」，-m 内容进正文，不可篡改标题）:
  ./scripts/release.sh -m "修复联机断线"            # patch: 标题 release: vX.Y.Z，正文「修复联机断线」
  ./scripts/release.sh --minor -m "新增贪吃蛇"     # 标题 Release: vX.Y.Z，正文「新增贪吃蛇」
  ./scripts/release.sh --major -m "重构网络层"     # 标题 RELEASE: vX.Y.Z，正文「重构网络层」
  ./scripts/release.sh                               # patch: 标题 release: vX.Y.Z，无正文
  ./scripts/release.sh --major -v 2.0.0 -m "2.0"   # RELEASE: v2.0.0，正文「2.0」（-v 指定版本号）
  ./scripts/release.sh --skip-changelog             # 不更新 CHANGELOG
  ./scripts/release.sh -n                           # 预览，不执行
EOF
  exit 0
}

# ─── 读取当前版本 ──────────────────────────────────────
read_current_version() {
  local ver
  ver=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
  MAJOR=$(echo "$ver" | cut -d. -f1)
  MINOR=$(echo "$ver" | cut -d. -f2)
  PATCH=$(echo "$ver" | cut -d. -f3 | cut -d+ -f1)
  # 提取 build 号；无 + 时 cut 返回整行（等于 $ver），需兜底为 0，否则后续算术运算报错
  BUILD=$(echo "$ver" | cut -d+ -f2)
  if [[ "$BUILD" == "$ver" || -z "$BUILD" ]]; then
    BUILD=0
  fi
  CURRENT="$MAJOR.$MINOR.$PATCH"
  info "当前版本: $CURRENT+$BUILD"
}

# ─── 计算新版本 ────────────────────────────────────────
calc_version() {
  local bump_type="$BUMP"

  if [[ -n "$EXPLICIT_VERSION" ]]; then
    NEW_MAJOR=$(echo "$EXPLICIT_VERSION" | cut -d. -f1)
    NEW_MINOR=$(echo "$EXPLICIT_VERSION" | cut -d. -f2)
    NEW_PATCH=$(echo "$EXPLICIT_VERSION" | cut -d. -f3)
    [[ -z "$NEW_MAJOR" || -z "$NEW_MINOR" || -z "$NEW_PATCH" ]] && error "版本号格式错误，应为 X.Y.Z"
    NEW_VERSION="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
    NEW_BUILD=$((BUILD + 1))
    return
  fi

  NEW_MAJOR=$MAJOR
  NEW_MINOR=$MINOR
  NEW_PATCH=$PATCH
  NEW_BUILD=$((BUILD + 1))

  case "$bump_type" in
    major) NEW_MAJOR=$((MAJOR + 1)); NEW_MINOR=0; NEW_PATCH=0 ;;
    minor) NEW_MINOR=$((MINOR + 1)); NEW_PATCH=0 ;;
    patch) NEW_PATCH=$((PATCH + 1)) ;;
    *)     error "无效的版本递增类型: $bump_type" ;;
  esac

  NEW_VERSION="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
}

# ─── 更新 pubspec.yaml ─────────────────────────────────
update_pubspec() {
  local new_ver="$1+$2"
  # 用 perl -i 替代 sed -i：GNU sed（Linux/Git Bash）与 BSD sed（macOS）的 -i 行为不同，perl 跨平台一致
  # 用 [^\r\n]* 只匹配版本号内容、不触碰 CR/LF，避免把 CRLF 文件的 version 行打成 LF，造成行尾混用
  perl -i -pe "s/^version: [^\r\n]*/version: $new_ver/" pubspec.yaml
  info "pubspec.yaml → version: $new_ver"
}

# ─── 更新 CHANGELOG.md ────────────────────────────────
update_changelog() {
  local new_ver="$1"
  local msg="$2"
  local today
  today=$(date +%Y-%m-%d)

  if [[ ! -f "CHANGELOG.md" ]]; then
    warn "CHANGELOG.md 不存在，跳过更新"
    return
  fi

  # 取上一个版本 tag 到 HEAD 的提交（release commit 此时尚未创建，HEAD 即自上次发布以来的累积提交）
  local prev_tag log_range
  prev_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
  if [[ -n "$prev_tag" ]]; then
    log_range="${prev_tag}..HEAD"
  else
    log_range="HEAD"
  fi

  # 按 Conventional Commits 类型分类收集提交（feat→Added, fix→Fixed, perf/refactor/ci/chore/build→Changed, 其余→Other）
  # 兼容带 scope 的写法，如 feat(tower_defense): xxx
  local added=() fixed=() changed=() other=()
  local subject type desc
  # 正则存入变量再用 =~ $var，规避 shell 对括号的解析（兼容 bash 3.2+/macOS）
  local cc_re='^([a-z]+)(\([^)]+\))?:[[:space:]]*(.+)'
  while IFS= read -r subject; do
    [[ -z "$subject" ]] && continue
    if [[ "$subject" =~ $cc_re ]]; then
      type="${BASH_REMATCH[1]}"
      desc="${BASH_REMATCH[3]}"
    else
      type="other"; desc="$subject"
    fi
    case "$type" in
      feat)     added+=("- $desc") ;;
      fix)      fixed+=("- $desc") ;;
      perf|refactor|ci|chore|build) changed+=("- $desc") ;;
      *)        other+=("- $subject") ;;
    esac
  done < <(git log --pretty=format:"%s" --no-merges "$log_range" 2>/dev/null)

  # 组装条目正文：顶部放发布说明，下方按类型分段（保持最新版本在顶部）
  local body=""
  [[ -n "$msg" ]] && body+=$'\n'"$msg"$'\n'

  local entry title varname items item
  for entry in "Added:added" "Fixed:fixed" "Changed:changed" "Other:other"; do
    title="${entry%%:*}"
    varname="${entry#*:}"
    items=()
    eval "items=(\"\${${varname}[@]}\")"
    if (( ${#items[@]} > 0 )); then
      body+=$'\n'"### ${title}"$'\n'
      for item in "${items[@]}"; do
        body+="${item}"$'\n'
      done
    fi
  done

  local changelog_entry
  changelog_entry=$'\n'"## [${new_ver}] - ${today}${body}"

  local original
  original=$(cat CHANGELOG.md)

  # 新条目应插到标题块之后（第一个 "## [" 版本条目之前），而非文件最顶，
  # 否则每次发布会把 "# Changelog" 标题不断向下挤压。无版本条目时退回原逻辑。
  if grep -q '^## \[' CHANGELOG.md; then
    awk -v entry="$changelog_entry" '
      !inserted && /^## \[/ { printf "%s\n", entry; inserted=1 }
      { print }
    ' CHANGELOG.md > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
  else
    printf '%s%s\n' "${changelog_entry}" "${original}" > CHANGELOG.md
  fi
  info "CHANGELOG.md → 已添加 [${new_ver}] 条目（基于 ${log_range} 提交自动分类）"
}

# ─── 等待并校验 GitHub Actions ─────────────────────────
wait_for_ci() {
  local tag="$1"

  if $SKIP_WAIT; then
    warn "已跳过 CI 等待（--skip-wait）"
    return 0
  fi

  # 从 remote URL 解析 owner/repo（兼容 https 与 ssh 两种格式），用于拼装 Actions 链接
  local remote_url repo_slug actions_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  # 兼容 https(https://github.com/o/r[.git]) 与 ssh(git@github.com:o/r[.git]) 两种 remote 格式
  repo_slug=$(echo "$remote_url" | sed -E 's#(https?://|git@)github\.com[:/]##; s#\.git$##')
  actions_url="https://github.com/${repo_slug}/actions"

  if [[ -z "$repo_slug" ]]; then
    warn "无法解析仓库地址，请手动前往 GitHub Actions 确认构建状态"
    return 0
  fi

  # 无 gh CLI 时降级为打印链接，不强制安装、不阻塞
  if ! command -v gh >/dev/null 2>&1; then
    echo ""
    warn "未安装 gh CLI，无法自动等待构建结果"
    info "请手动确认 Release 构建状态："
    echo -e "  ${CYAN}${actions_url}${NC}"
    return 0
  fi

  echo ""
  info "等待 GitHub Actions (Release) 完成构建..."
  # tag 触发的 run 需数秒注册，轮询等待其出现
  local run_id="" tries=0
  while [[ -z "$run_id" && $tries -lt 20 ]]; do
    sleep 3
    run_id=$(gh run list --workflow release.yml --branch "$tag" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
    tries=$((tries + 1))
  done

  if [[ -z "$run_id" ]]; then
    warn "未找到对应 Release run（可能尚未注册），请手动查看："
    echo -e "  ${CYAN}${actions_url}${NC}"
    return 0
  fi

  info "找到 Release run: $run_id，开始监听（多平台构建可能耗时 10-20 分钟，可 Ctrl+C 跳过）..."
  if gh run watch "$run_id" --exit-status 2>/dev/null; then
    echo ""
    info "✅ Release 构建通过"
    CI_VERIFIED=true
  else
    echo ""
    error "❌ Release 构建失败，请查看：gh run view $run_id --log-failed"
  fi
}

# ─── 参数解析 ──────────────────────────────────────────
EXPLICIT_VERSION=""
COMMIT_MSG=""
BUMP=""
DRY_RUN=false
AUTO_YES=false
SKIP_CHANGELOG=false
SKIP_WAIT=false
CI_VERIFIED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)       EXPLICIT_VERSION="$2"; shift 2 ;;
    -m|--message)       COMMIT_MSG="$2"; shift 2 ;;
    --major)            BUMP="major"; shift ;;
    --minor)            BUMP="minor"; shift ;;
    --patch)            BUMP="patch"; shift ;;
    -n|--dry-run)       DRY_RUN=true; shift ;;
    -y|--yes)           AUTO_YES=true; shift ;;
    --skip-changelog)   SKIP_CHANGELOG=true; shift ;;
    --skip-wait)         SKIP_WAIT=true; shift ;;
    -h|--help)          usage ;;
    *)                  error "未知参数: $1" ;;
  esac
done

# ─── 检查环境 ──────────────────────────────────────────
# #1: 确认在项目根目录
[[ -f "pubspec.yaml" ]] || error "请在项目根目录执行此脚本"

# #2: 检查分支
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  error "当前不在 main 分支 (当前: $CURRENT_BRANCH)，请先切换到 main"
fi

# #3: 检查所有未提交修改（RELEASE_SKIP_CHECK=1 可跳过，便于测试/预览）
if [[ "${RELEASE_SKIP_CHECK:-}" != "1" ]]; then
  if ! git diff --quiet HEAD 2>/dev/null; then
    error "工作区有未提交的修改，请先 commit 或 stash"
  fi
  if ! git diff --quiet --cached HEAD 2>/dev/null; then
    error "暂存区有未提交的修改，请先 commit 或 stash"
  fi
fi

read_current_version

# 未指定 --major/--minor/--patch 时默认 patch
[[ -z "$BUMP" ]] && BUMP="patch"

# 提交信息标题前缀由版本类型生成（用户不可通过 -m 篡改）
case "$BUMP" in
  major) PREFIX="RELEASE:" ;;
  minor) PREFIX="Release:" ;;
  patch) PREFIX="release:" ;;
esac

calc_version

TAG="v$NEW_VERSION"
# 标题由脚本固定生成「前缀 + 版本号」，-m 内容仅作为正文，不可篡改标题
TITLE="$PREFIX $TAG"
# 正文：-m 内容（未指定则无正文）
BODY="$COMMIT_MSG"
# 完整 commit message：标题 + 空行 + 正文
if [[ -n "$BODY" ]]; then
  COMMIT_MSG="$TITLE"$'\n\n'"$BODY"
else
  COMMIT_MSG="$TITLE"
fi

# #4: 检查 tag 是否已存在
if git rev-parse "$TAG" >/dev/null 2>&1; then
  error "标签 $TAG 已存在，请检查版本号或删除已有标签"
fi

# ─── 输出预览 ──────────────────────────────────────────
echo ""
info "========== Release 预览 =========="
info "当前版本:   $CURRENT+$BUILD"
info "新版本:     $NEW_VERSION+$NEW_BUILD"
info "Git 标签:   $TAG"
info "提交标题:   $TITLE"
if [[ -n "$BODY" ]]; then
  info "提交正文:   $BODY"
else
  info "提交正文:   (无)"
fi
if $SKIP_CHANGELOG; then
  warn "CHANGELOG:  跳过（--skip-changelog）"
else
  info "CHANGELOG:  将自动更新"
fi
info "=================================="
echo ""

if $DRY_RUN; then
  warn "预览模式，未执行任何操作"
  exit 0
fi

# #5: 确认提示
if ! $AUTO_YES; then
  echo -en "${CYAN}确认发布？[y/N] ${NC}"
  read -r REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    info "已取消"
    exit 0
  fi
fi

# ─── 执行 ──────────────────────────────────────────────
info "更新版本号..."
update_pubspec "$NEW_VERSION" "$NEW_BUILD"

if ! $SKIP_CHANGELOG; then
  info "更新 CHANGELOG..."
  update_changelog "$NEW_VERSION" "$BODY"
fi

info "创建提交..."
git add pubspec.yaml CHANGELOG.md
if [[ -n "$BODY" ]]; then
  git commit -m "$TITLE" -m "$BODY"
else
  git commit -m "$TITLE"
fi

info "创建标签 $TAG..."
git tag -a "$TAG" -m "$COMMIT_MSG"

info "推送到远程..."
git push origin HEAD
git push origin "$TAG"

# 校验 CI 结果，避免「半发布」（可用 --skip-wait 跳过）
wait_for_ci "$TAG"

echo ""
info "✅ 发布完成！"
info "   版本: $NEW_VERSION"
info "   标签: $TAG"
if $CI_VERIFIED; then
  info "   GitHub Actions 已构建并通过，各平台产物已发布"
else
  warn "   GitHub Actions 已触发但未自动校验，请手动确认构建结果"
fi

echo ""
info "如需回滚，执行以下命令："
echo -e "  ${YELLOW}git tag -d $TAG${NC}"
echo -e "  ${YELLOW}git push origin :refs/tags/$TAG${NC}"
echo -e "  ${YELLOW}git revert HEAD${NC}"
