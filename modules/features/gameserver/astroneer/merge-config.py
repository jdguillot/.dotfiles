#!/usr/bin/env python3

import argparse
import configparser
import copy
from pathlib import Path

import tomllib


def merge_dicts(target, template):
    merged = copy.deepcopy(target)

    for key, value in template.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge_dicts(merged[key], value)
        else:
            merged[key] = value

    return merged


def merge_toml(template_path: Path, target_path: Path) -> None:
    template = tomllib.loads(template_path.read_text())

    if target_path.exists():
        target = tomllib.loads(target_path.read_text())
    else:
        target = {}

    merged = merge_dicts(target, template)
    target_path.write_text(dump_toml(merged), encoding="utf-8")


def format_toml_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[{}]".format(", ".join(format_toml_value(item) for item in value))
    raise TypeError(f"Unsupported TOML value type: {type(value)!r}")


def dump_toml(data) -> str:
    lines = []

    def write_table(table, prefix=()):
        scalars = []
        subtables = []

        for key, value in table.items():
            if isinstance(value, dict):
                subtables.append((key, value))
            else:
                scalars.append((key, value))

        if prefix:
            lines.append(f"[{'.'.join(prefix)}]")

        for key, value in scalars:
            lines.append(f"{key} = {format_toml_value(value)}")

        if scalars and subtables:
            lines.append("")

        for index, (key, value) in enumerate(subtables):
            write_table(value, prefix + (key,))
            if index != len(subtables) - 1:
                lines.append("")

    write_table(data)
    return "\n".join(lines).rstrip() + "\n"


def new_ini_parser() -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    return parser


def merge_ini(template_path: Path, target_path: Path) -> None:
    template = new_ini_parser()
    template.read(template_path)

    target = new_ini_parser()
    if target_path.exists():
        target.read(target_path)

    for section in template.sections():
        if not target.has_section(section):
            target.add_section(section)

        for key, value in template.items(section):
            target.set(section, key, value)

    with target_path.open("w", encoding="utf-8") as f:
        target.write(f, space_around_delimiters=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("format", choices=("ini", "toml"))
    parser.add_argument("template")
    parser.add_argument("target")
    args = parser.parse_args()

    template_path = Path(args.template)
    target_path = Path(args.target)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if args.format == "ini":
        merge_ini(template_path, target_path)
    else:
        merge_toml(template_path, target_path)


if __name__ == "__main__":
    main()
