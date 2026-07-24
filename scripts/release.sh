#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PUBSPEC_PATH="${REPO_ROOT}/pubspec.yaml"

usage() {
  cat <<'EOF'
用法：
  ./scripts/release.sh <版本号> [--yes]

示例：
  ./scripts/release.sh 1.0.4
  ./scripts/release.sh v1.0.4 --yes

同版本发布会递增 pubspec.yaml 的构建号，新版本从 +1 开始。
脚本随后执行发布检查、提交并推送 main，再创建和推送对应的 Tag。
EOF
}

fail() {
  echo "错误：$*" >&2
  exit 1
}

TARGET_VERSION=""
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --yes)
      ASSUME_YES=true
      ;;
    -* )
      fail "未知参数：$1"
      ;;
    *)
      [[ -z "${TARGET_VERSION}" ]] || fail "只能指定一个版本号"
      TARGET_VERSION="${1#v}"
      ;;
  esac
  shift
done

[[ -n "${TARGET_VERSION}" ]] || {
  usage >&2
  exit 2
}
[[ "${TARGET_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  fail "版本号必须是 x.y.z 格式，例如 1.0.4"

for command_name in git make ruby; do
  command -v "${command_name}" >/dev/null 2>&1 ||
    fail "缺少必需命令：${command_name}"
done

cd "${REPO_ROOT}"

[[ "$(git branch --show-current)" == "main" ]] || fail "只能在 main 分支发布"
[[ -z "$(git status --porcelain)" ]] || fail "工作区不干净，请先提交或处理现有改动"
git remote get-url origin >/dev/null 2>&1 || fail "未配置 origin 远端"

echo "正在刷新 origin/main 和远端 Tag..."
git fetch origin main --tags
git rev-parse --verify origin/main >/dev/null 2>&1 || fail "找不到 origin/main"
git merge-base --is-ancestor origin/main HEAD ||
  fail "本地 main 落后于或已偏离 origin/main，请先同步分支"

readonly TAG_NAME="v${TARGET_VERSION}"
REMOTE_TAGS="$(git ls-remote --refs --tags origin 'refs/tags/v*')" ||
  fail "无法读取远端 Tag"
readonly REMOTE_TAGS

REMOTE_TARGET_TAG_EXISTS=false
REMOTE_RELEASE_VERSIONS=()
while IFS=$'\t' read -r _ tag_ref; do
  [[ -n "${tag_ref}" ]] || continue
  if [[ "${tag_ref}" == "refs/tags/${TAG_NAME}" ]]; then
    REMOTE_TARGET_TAG_EXISTS=true
  fi

  remote_version="${tag_ref#refs/tags/v}"
  if [[ "${remote_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    REMOTE_RELEASE_VERSIONS+=("${remote_version}")
  fi
done <<<"${REMOTE_TAGS}"

if [[ "${REMOTE_TARGET_TAG_EXISTS}" == true ]]; then
  fail "远端 Tag ${TAG_NAME} 仍然存在，请先删除对应的 GitHub Release 和远端 Tag"
fi

LATEST_REMOTE_VERSION=""
if [[ "${#REMOTE_RELEASE_VERSIONS[@]}" -gt 0 ]]; then
  LATEST_REMOTE_VERSION="$(
    ruby -e \
      'require "rubygems"; puts ARGV.max_by { |version| Gem::Version.new(version) }' \
      "${REMOTE_RELEASE_VERSIONS[@]}"
  )"
fi
readonly LATEST_REMOTE_VERSION

CURRENT_PUBSPEC_VERSION="$(
  ruby -r yaml -e \
    'print YAML.safe_load(File.read(ARGV.fetch(0))).fetch("version")' \
    "${PUBSPEC_PATH}"
)"
if [[ ! "${CURRENT_PUBSPEC_VERSION}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  fail "pubspec.yaml 版本格式无效：${CURRENT_PUBSPEC_VERSION}"
fi

readonly CURRENT_APP_VERSION="${BASH_REMATCH[1]}"
readonly CURRENT_BUILD_NUMBER="${BASH_REMATCH[2]}"
version_is_lower() {
  ruby -e \
    'require "rubygems"; exit(Gem::Version.new(ARGV[0]) < Gem::Version.new(ARGV[1]) ? 0 : 1)' \
    "$1" "$2"
}

if version_is_lower "${TARGET_VERSION}" "${CURRENT_APP_VERSION}"; then
  fail "目标版本 ${TARGET_VERSION} 不能低于当前版本 ${CURRENT_APP_VERSION}"
fi
if [[ -n "${LATEST_REMOTE_VERSION}" ]] &&
  version_is_lower "${TARGET_VERSION}" "${LATEST_REMOTE_VERSION}"; then
  fail "目标版本 ${TARGET_VERSION} 不能低于远端最高版本 ${LATEST_REMOTE_VERSION}"
fi

if [[ "${TARGET_VERSION}" == "${CURRENT_APP_VERSION}" ]]; then
  NEXT_BUILD_NUMBER="$((10#${CURRENT_BUILD_NUMBER} + 1))"
else
  NEXT_BUILD_NUMBER=1
fi

readonly NEXT_BUILD_NUMBER
readonly TARGET_PUBSPEC_VERSION="${TARGET_VERSION}+${NEXT_BUILD_NUMBER}"
readonly AHEAD_COUNT="$(git rev-list --count origin/main..HEAD)"
LOCAL_TAG_EXISTS=false
if git show-ref --verify --quiet "refs/tags/${TAG_NAME}"; then
  LOCAL_TAG_EXISTS=true
fi

echo
echo "发布计划："
echo "  应用版本：${CURRENT_PUBSPEC_VERSION} -> ${TARGET_PUBSPEC_VERSION}"
echo "  Git Tag： ${TAG_NAME}"
if [[ -n "${LATEST_REMOTE_VERSION}" ]]; then
  echo "  远端最高版本：v${LATEST_REMOTE_VERSION}"
fi
echo "  待推送提交：${AHEAD_COUNT} 个（不含即将生成的版本提交）"
if [[ "${LOCAL_TAG_EXISTS}" == true ]]; then
  echo "  本地 Tag：将删除并重新指向最新发布提交"
fi
if [[ "${AHEAD_COUNT}" -gt 0 ]]; then
  git log --oneline origin/main..HEAD
fi
echo

if [[ "${ASSUME_YES}" != true ]]; then
  [[ -t 0 ]] || fail "非交互环境必须显式传入 --yes"
  read -r -p "确认执行检查、提交、推送并创建 Tag？[y/N] " confirmation
  case "${confirmation}" in
    y | Y | yes | YES) ;;
    *)
      echo "已取消发布"
      exit 0
      ;;
  esac
fi

echo "正在执行发布前检查..."
make release-check

# 发布检查通过后才修改版本，避免失败时污染工作区。
env TARGET_PUBSPEC_VERSION="${TARGET_PUBSPEC_VERSION}" ruby -e '
  path = ARGV.fetch(0)
  content = File.read(path)
  matches = content.scan(/^version:\s*.*$/)
  abort "pubspec.yaml 必须且只能包含一个 version 字段" unless matches.length == 1
  File.write(path, content.sub(/^version:\s*.*$/, "version: #{ENV.fetch("TARGET_PUBSPEC_VERSION")}"))
' "${PUBSPEC_PATH}"

git diff --check
git add pubspec.yaml
git commit -m "chore(release): bump version to ${TARGET_PUBSPEC_VERSION}"
git push origin main
if [[ "${LOCAL_TAG_EXISTS}" == true ]]; then
  git tag -d "${TAG_NAME}"
fi
git tag -a "${TAG_NAME}" -m "Release ${TAG_NAME}"
git push origin "${TAG_NAME}"

echo
echo "${TAG_NAME} 已推送，GitHub Actions 将继续构建并创建 Release。"
