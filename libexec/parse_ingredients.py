#!/usr/bin/env python3
import json
import re
import sys
from contextlib import redirect_stdout
from dataclasses import asdict, is_dataclass
from enum import Enum
from fractions import Fraction


_parse_ingredient = None


def normalized_text(value):
    return re.sub(r"\s+", " ", str(value)).strip().lower()


def json_ready(value):
    if is_dataclass(value):
        return {key: json_ready(item) for key, item in asdict(value).items()}

    if isinstance(value, Enum):
        return value.value

    if isinstance(value, Fraction):
        return str(value)

    if isinstance(value, list):
        return [json_ready(item) for item in value]

    if isinstance(value, tuple):
        return [json_ready(item) for item in value]

    if isinstance(value, dict):
        return {key: json_ready(item) for key, item in value.items()}

    if value is None or isinstance(value, (str, int, float, bool)):
        return value

    return str(value)


def parsed_name_values(value):
    if value is None:
        return []

    if isinstance(value, str):
        return [value]

    if isinstance(value, (list, tuple)):
        return [getattr(item, "text", str(item)) for item in value]

    return [getattr(value, "text", str(value))]


def normalized_parser_payload(value):
    parser = json_ready(value)
    for name in parser.get("name") or []:
        if isinstance(name, dict) and "text" in name:
            name["text"] = normalized_text(name["text"])
    return parser


def parse_sentence(sentence):
    global _parse_ingredient

    if _parse_ingredient is None:
        with redirect_stdout(sys.stderr):
            from ingredient_parser import parse_ingredient

        _parse_ingredient = parse_ingredient

    with redirect_stdout(sys.stderr):
        return _parse_ingredient(sentence)


def parsed_entry(sentence):
    parsed = parse_sentence(sentence)
    return {
        "input": sentence,
        "parser": normalized_parser_payload(parsed),
    }, parsed_name_values(parsed.name)


def failed_entry(sentence, error):
    return {
        "input": sentence,
        "parser": None,
        "error": {
            "class": error.__class__.__name__,
            "message": str(error),
        },
    }, [sentence]


def parse_ingredient_list(lines):
    names = []
    parse_data = []
    seen = set()

    for line in lines:
        sentence = str(line).strip()
        if not sentence:
            continue

        try:
            entry, parsed_names = parsed_entry(sentence)
        except Exception as error:
            entry, parsed_names = failed_entry(sentence, error)

        parse_data.append(entry)

        for parsed_name in parsed_names:
            normalized_name = normalized_text(parsed_name)
            if normalized_name and normalized_name not in seen:
                seen.add(normalized_name)
                names.append(normalized_name)

    return names, parse_data


def ingredient_lines(value):
    if isinstance(value, list):
        return [item for item in value if item is not None]

    if value is None:
        return []

    return [value]


def main():
    payload = json.load(sys.stdin)
    ingredient_lists = payload.get("ingredient_lists")

    if not isinstance(ingredient_lists, list):
        raise ValueError("ingredient_lists must be an array")

    parsed_lists = [
        parse_ingredient_list(ingredient_lines(ingredient_list))
        for ingredient_list in ingredient_lists
    ]

    json.dump(
        {
            "ingredient_names": [names for names, _parse_data in parsed_lists],
            "ingredient_parse_data": [parse_data for _names, parse_data in parsed_lists],
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
