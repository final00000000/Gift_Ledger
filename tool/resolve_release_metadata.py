#!/usr/bin/env python3
"""解析 pubspec 与发布上下文，生成统一的版本元数据。

版本号规则说明：
- 稳定版：1.3.1 -> 1030199
- 预发布：1.3.1-beta.2 -> 1030102

实现方式：按固定宽度编码 major/minor/patch，并追加两位发布阶段后缀：
- 结构：major * 1_000_000 + minor * 10_000 + patch * 100 + stage
- 正式版 stage 固定为 99，确保同核心版本的 stable 永远高于 beta
- 预发布只支持 beta 通道，beta.2 -> 02，beta -> 01
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from typing import Any

SEMVER_PATTERN = re.compile(
    r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>[0-9A-Za-z.-]+))?$"
)
STABLE_STAGE = 99
MAX_PRERELEASE_STAGE = STABLE_STAGE - 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='解析 Gift Ledger 发布版本元数据')
    parser.add_argument('--pubspec', default='pubspec.yaml', help='pubspec.yaml 路径')
    parser.add_argument('--event-name', default='', help='GitHub event name')
    parser.add_argument('--input-channel', default='', help='workflow dispatch 输入的 channel')
    parser.add_argument('--input-release-tag', default='', help='workflow dispatch 输入的 release tag')
    parser.add_argument('--ref-name', default='', help='Git ref name')
    parser.add_argument(
        '--platform',
        required=True,
        choices=('android', 'windows', 'ios'),
        help='目标平台，用于生成资产名称',
    )
    parser.add_argument('--github-output', help='GitHub Actions 输出文件路径')
    return parser.parse_args()


def parse_pubspec(pubspec_path: pathlib.Path) -> tuple[str, str, str]:
    text = pubspec_path.read_text(encoding='utf-8')
    name_match = re.search(r'^name:\s*([^\s]+)', text, re.M)
    version_match = re.search(r'^version:\s*([^\s]+)', text, re.M)
    if not name_match or not version_match:
        raise ValueError('name/version not found in pubspec.yaml')

    app_name = name_match.group(1).strip()
    full_version = version_match.group(1).strip()
    semver, _, build_number = full_version.partition('+')
    return app_name, semver, build_number


def require_valid_semver(semver: str) -> re.Match[str]:
    match = SEMVER_PATTERN.fullmatch(semver)
    if not match:
        raise ValueError(f'Invalid semantic version: {semver}')
    return match


def has_prerelease(semver: str) -> bool:
    return require_valid_semver(semver).group('prerelease') is not None


def derive_stage_number(prerelease: str | None) -> int:
    if not prerelease:
        return STABLE_STAGE

    normalized = prerelease.lower()
    if not normalized.startswith('beta'):
        raise ValueError(
            'Only beta prerelease versions are supported, e.g. 1.3.1-beta.2'
        )

    segments = [segment for segment in prerelease.split('.') if segment]
    numeric_segment = next(
        (segment for segment in reversed(segments) if segment.isdigit()),
        None,
    )
    stage_number = int(numeric_segment or '1')
    if stage_number <= 0:
        raise ValueError(f'Invalid beta stage number: {stage_number}')
    if stage_number > MAX_PRERELEASE_STAGE:
        raise ValueError(
            f'Beta stage number must be <= {MAX_PRERELEASE_STAGE}, got {stage_number}'
        )
    return stage_number


def derive_build_number(semver: str) -> int:
    match = require_valid_semver(semver)
    major = int(match.group('major'))
    minor = int(match.group('minor'))
    patch = int(match.group('patch'))
    prerelease = match.group('prerelease')

    if minor > 99 or patch > 99:
        raise ValueError(
            'Minor and patch versions must stay below 100 to keep versionCode unique'
        )

    build_number = (
        major * 1_000_000
        + minor * 10_000
        + patch * 100
        + derive_stage_number(prerelease)
    )
    if build_number <= 0:
        raise ValueError(f'Invalid derived build number: {build_number}')
    return build_number


def resolve_channel_and_release_tag(
    *,
    event_name: str,
    input_channel: str,
    input_release_tag: str,
    ref_name: str,
    pubspec_semver: str,
) -> tuple[str, str, str]:
    semver = pubspec_semver
    release_tag = input_release_tag.strip()
    requested_channel = input_channel.strip().lower()

    if release_tag:
        if not release_tag.startswith('v'):
            release_tag = f'v{release_tag}'
        semver = release_tag[1:]
        require_valid_semver(semver)
    elif event_name == 'push' and ref_name:
        release_tag = ref_name if ref_name.startswith('v') else f'v{ref_name}'
        semver = release_tag[1:]
        require_valid_semver(semver)

    if requested_channel and requested_channel not in {'stable', 'beta'}:
        raise ValueError(f'Invalid channel: {requested_channel}')

    is_prerelease = has_prerelease(semver)
    if event_name == 'push' and ref_name.startswith('v'):
        channel = 'beta' if is_prerelease else 'stable'
    elif requested_channel:
        channel = requested_channel
    else:
        channel = 'beta' if is_prerelease else 'stable'

    if channel not in {'stable', 'beta'}:
        raise ValueError(f'Invalid channel: {channel}')

    if channel == 'beta' and not is_prerelease:
        raise ValueError(
            'Beta releases require a prerelease semantic version/tag, '
            'e.g. v1.3.1-beta.1'
        )
    if channel == 'stable' and is_prerelease:
        raise ValueError(
            'Stable releases cannot use prerelease semantic versions/tags'
        )

    if not release_tag:
        release_tag = f'v{semver}'

    return semver, channel, release_tag


def build_asset_names(
    *,
    app_name: str,
    channel: str,
    platform: str,
    semver: str,
    build_number: int,
) -> dict[str, str]:
    if platform == 'android':
        asset_base_name = (
            f'{app_name}-{channel}-android-v{semver}-build{build_number}'
        )
        arm64_asset_name = f'{asset_base_name}-arm64-v8a.apk'
        return {
            'asset_base_name': asset_base_name,
            # 顶层 Android 入口固定指向 arm64 包，split 变体通过独立字段暴露。
            'asset_name': arm64_asset_name,
            'asset_name_armeabi_v7a': f'{asset_base_name}-armeabi-v7a.apk',
            'asset_name_arm64_v8a': arm64_asset_name,
        }

    if platform == 'ios':
        asset_base_name = f'{app_name}-{channel}-ios-v{semver}-build{build_number}'
        return {
            'asset_base_name': asset_base_name,
            'asset_name': f'{asset_base_name}.ipa',
        }

    asset_base_name = f'{app_name}-{channel}-windows-v{semver}-build{build_number}-setup'
    return {
        'asset_base_name': asset_base_name,
        'asset_name': f'{asset_base_name}.exe',
    }


def validate_pubspec_build_number(pubspec_semver: str, pubspec_build_number: str) -> None:
    if not pubspec_build_number:
        raise ValueError('pubspec build number is missing')
    if not pubspec_build_number.isdigit():
        raise ValueError(f'Invalid pubspec build number: {pubspec_build_number}')

    expected_build_number = derive_build_number(pubspec_semver)
    if int(pubspec_build_number) != expected_build_number:
        raise ValueError(
            'pubspec build number does not match version rule: '
            f'{pubspec_semver} should use +{expected_build_number}, got +{pubspec_build_number}'
        )


def emit_github_output(path: pathlib.Path, values: dict[str, Any]) -> None:
    with path.open('a', encoding='utf-8') as stream:
        for key, value in values.items():
            stream.write(f'{key}={value}\n')


def main() -> int:
    args = parse_args()
    pubspec_path = pathlib.Path(args.pubspec)
    app_name, pubspec_semver, pubspec_build_number = parse_pubspec(pubspec_path)
    validate_pubspec_build_number(pubspec_semver, pubspec_build_number)

    semver, channel, release_tag = resolve_channel_and_release_tag(
        event_name=args.event_name.strip(),
        input_channel=args.input_channel,
        input_release_tag=args.input_release_tag,
        ref_name=args.ref_name.strip(),
        pubspec_semver=pubspec_semver,
    )
    build_number = derive_build_number(semver)

    values: dict[str, Any] = {
        'app_name': app_name,
        'semver': semver,
        'build_number': build_number,
        'channel': channel,
        'release_tag': release_tag,
    }
    values.update(
        build_asset_names(
            app_name=app_name,
            channel=channel,
            platform=args.platform,
            semver=semver,
            build_number=build_number,
        )
    )

    if args.github_output:
        emit_github_output(pathlib.Path(args.github_output), values)
    else:
        for key, value in values.items():
            print(f'{key}={value}')

    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f'Error: {exc}', file=sys.stderr)
        raise SystemExit(1)
