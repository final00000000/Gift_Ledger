#!/usr/bin/env python3
"""根据 release matrix 生成客户端可消费的 update manifest。"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ALLOWED_CHANNELS = ("stable", "beta")
ALLOWED_PLATFORMS = ("android", "windows")
ALLOWED_PACKAGE_TYPES = ("apk", "exe", "msix")
ALLOWED_ANDROID_ABIS = ("armeabi-v7a", "arm64-v8a")
REQUIRED_ENTRY_FIELDS = (
    "channel",
    "platform",
    "version",
    "buildNumber",
    "packageType",
    "downloadUrl",
    "sha256",
    "notes",
)
REQUIRED_VARIANT_FIELDS = (
    "packageType",
    "downloadUrl",
    "sha256",
)


class ManifestGenerationError(ValueError):
    """manifest 生成失败时抛出的业务异常。"""


def _require_object(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ManifestGenerationError(f'"{path}" 必须是对象。')
    return value


def _require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise ManifestGenerationError(f'"{path}" 必须是数组。')
    return value


def _require_non_empty_string(value: Any, path: str) -> str:
    if not isinstance(value, str):
        raise ManifestGenerationError(f'"{path}" 必须是非空字符串。')

    trimmed = value.strip()
    if not trimmed:
        raise ManifestGenerationError(f'"{path}" 必须是非空字符串。')
    return trimmed


def _require_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ManifestGenerationError(f'"{path}" 必须是整数。')
    return value


def _validate_package_type(value: Any, path: str) -> str:
    package_type = _require_non_empty_string(value, path).lower()
    if package_type not in ALLOWED_PACKAGE_TYPES:
        raise ManifestGenerationError(
            f'"{path}" 仅支持: {", ".join(ALLOWED_PACKAGE_TYPES)}。'
        )
    return package_type


def _validate_sha256(value: Any, path: str) -> str:
    sha256 = _require_non_empty_string(value, path).lower()
    if len(sha256) != 64 or any(ch not in "0123456789abcdef" for ch in sha256):
        raise ManifestGenerationError(
            f'"{path}" 必须是 64 位十六进制字符串。'
        )
    return sha256


def _validate_download_url(
    value: Any,
    *,
    version: str,
    build_number: int,
    path: str,
) -> str:
    download_url = _require_non_empty_string(value, path)
    if "://" not in download_url:
        raise ManifestGenerationError(f'"{path}" 必须是绝对 URL。')

    _validate_download_url_metadata(
        version=version,
        build_number=build_number,
        download_url=download_url,
        path=path,
    )
    return download_url


def _normalize_android_abi(value: str) -> str:
    normalized = value.strip().lower().replace("_", "-")
    mapping = {
        "arm64": "arm64-v8a",
        "arm64v8a": "arm64-v8a",
        "arm64-v8a": "arm64-v8a",
        "aarch64": "arm64-v8a",
        "armeabi": "armeabi-v7a",
        "armeabi-v7a": "armeabi-v7a",
        "arm-v7a": "armeabi-v7a",
        "armv7": "armeabi-v7a",
        "android-arm": "armeabi-v7a",
    }
    return mapping.get(normalized, normalized)


def _validate_variants(
    value: Any,
    *,
    version: str,
    build_number: int,
    path: str,
) -> dict[str, dict[str, Any]]:
    if value is None:
        return {}

    variants = _require_object(value, f"{path}.variants")
    normalized_variants: dict[str, dict[str, Any]] = {}
    for raw_abi, raw_variant in variants.items():
        if not isinstance(raw_abi, str):
            raise ManifestGenerationError(
                f'"{path}.variants" 的键必须是字符串。'
            )

        normalized_abi = _normalize_android_abi(raw_abi)
        if normalized_abi not in ALLOWED_ANDROID_ABIS:
            raise ManifestGenerationError(
                f'"{path}.variants.{raw_abi}" 仅支持: '
                f'{", ".join(ALLOWED_ANDROID_ABIS)}。'
            )
        if normalized_abi in normalized_variants:
            raise ManifestGenerationError(
                f'"{path}.variants.{normalized_abi}" 重复。'
            )

        variant = _require_object(raw_variant, f"{path}.variants.{normalized_abi}")
        for field in REQUIRED_VARIANT_FIELDS:
            if field not in variant:
                raise ManifestGenerationError(
                    f'"{path}.variants.{normalized_abi}.{field}" 缺失。'
                )

        normalized_variants[normalized_abi] = {
            "packageType": _validate_package_type(
                variant["packageType"],
                f"{path}.variants.{normalized_abi}.packageType",
            ),
            "downloadUrl": _validate_download_url(
                variant["downloadUrl"],
                version=version,
                build_number=build_number,
                path=f"{path}.variants.{normalized_abi}.downloadUrl",
            ),
            "sha256": _validate_sha256(
                variant["sha256"],
                f"{path}.variants.{normalized_abi}.sha256",
            ),
        }

    return normalized_variants


def _validate_entry(entry: dict[str, Any], index: int) -> dict[str, Any]:
    path = f"entries[{index}]"

    for field in REQUIRED_ENTRY_FIELDS:
        if field not in entry:
            raise ManifestGenerationError(f'"{path}.{field}" 缺失。')

    channel = _require_non_empty_string(entry["channel"], f"{path}.channel").lower()
    if channel not in ALLOWED_CHANNELS:
        raise ManifestGenerationError(
            f'"{path}.channel" 仅支持: {", ".join(ALLOWED_CHANNELS)}。'
        )

    platform = _require_non_empty_string(entry["platform"], f"{path}.platform").lower()
    if platform not in ALLOWED_PLATFORMS:
        raise ManifestGenerationError(
            f'"{path}.platform" 仅支持: {", ".join(ALLOWED_PLATFORMS)}。'
        )

    version = _require_non_empty_string(entry["version"], f"{path}.version")
    build_number = _require_int(entry["buildNumber"], f"{path}.buildNumber")

    validated_entry = {
        "channel": channel,
        "platform": platform,
        "version": version,
        "buildNumber": build_number,
        "packageType": _validate_package_type(
            entry["packageType"],
            f"{path}.packageType",
        ),
        "downloadUrl": _validate_download_url(
            entry["downloadUrl"],
            version=version,
            build_number=build_number,
            path=f"{path}.downloadUrl",
        ),
        "sha256": _validate_sha256(entry["sha256"], f"{path}.sha256"),
        "notes": _require_non_empty_string(entry["notes"], f"{path}.notes"),
    }

    variants = _validate_variants(
        entry.get("variants"),
        version=version,
        build_number=build_number,
        path=path,
    )
    if variants:
        validated_entry["variants"] = variants

    return validated_entry


def _validate_download_url_metadata(
    *,
    version: str,
    build_number: int,
    download_url: str,
    path: str,
) -> None:
    version_match = re.search(
        r"v(\d+\.\d+\.\d+(?:-(?!build)[0-9A-Za-z.]+)?)(?=-build|[^0-9A-Za-z.]|$)",
        download_url,
        re.IGNORECASE,
    )
    if version_match and version_match.group(1) != version:
        raise ManifestGenerationError(
            f'"{path}" 中的版本号与目标版本不一致。'
        )

    build_match = re.search(r"build[_-]?(\d+)", download_url, re.IGNORECASE)
    if build_match and int(build_match.group(1)) != build_number:
        raise ManifestGenerationError(
            f'"{path}" 中的 build 号与目标 build 不一致。'
        )


def build_manifest(input_data: dict[str, Any]) -> dict[str, Any]:
    payload = _require_object(input_data, "root")
    schema_version = payload.get("schemaVersion", 1)
    schema_version = _require_int(schema_version, "schemaVersion")
    entries = _require_list(payload.get("entries"), "entries")

    channels: dict[str, dict[str, dict[str, Any]]] = {
        channel: {} for channel in ALLOWED_CHANNELS
    }
    seen_targets: set[tuple[str, str]] = set()

    for index, raw_entry in enumerate(entries):
        entry = _validate_entry(_require_object(raw_entry, f"entries[{index}]"), index)
        target_key = (entry["channel"], entry["platform"])
        if target_key in seen_targets:
            raise ManifestGenerationError(
                "检测到重复的 channel/platform 条目："
                f" {entry['channel']}/{entry['platform']}。"
            )
        seen_targets.add(target_key)

        manifest_entry = {
            "version": entry["version"],
            "buildNumber": entry["buildNumber"],
            "packageType": entry["packageType"],
            "downloadUrl": entry["downloadUrl"],
            "sha256": entry["sha256"],
            "notes": entry["notes"],
        }
        if "variants" in entry:
            manifest_entry["variants"] = entry["variants"]

        channels[entry["channel"]][entry["platform"]] = manifest_entry

    return {
        "schemaVersion": schema_version,
        "generatedAt": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
        "channels": channels,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="生成 Gift Ledger 更新 manifest")
    parser.add_argument("--input", required=True, help="release matrix 输入 JSON")
    parser.add_argument("--output", required=True, help="manifest 输出路径")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    try:
        input_data = json.loads(input_path.read_text(encoding="utf-8"))
        manifest = build_manifest(input_data)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except FileNotFoundError as exc:
        print(f"Error: 文件不存在：{exc.filename}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Error: 输入 JSON 非法：{exc}", file=sys.stderr)
        return 1
    except ManifestGenerationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Manifest generated successfully: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
