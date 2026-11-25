"""Draft generic insight wording using Say Ring's configured content model.

Run in a release environment with SAY_RING_EDITOR_TOKEN for a dedicated editorial
test account. Review the draft before promoting it into assets/cardiovascular.
The command accepts no health data, account details, prompts or external URLs.
"""
import argparse
import json
import os
import re
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

APP = Path(__file__).resolve().parents[1]
CATALOG = APP / "assets/cardiovascular/insights.json"
API = "https://app.saydian.cn/global/api/saydian-app/v2/ai/messages"
FIELDS = {
    "bpChange": {"upper", "lower"},
    "sparseBp": {"span", "previousSpan"},
    "noBp": set(),
    "pairedAlignedChange": {"metric", "prior", "value", "span", "previousSpan"},
    "pairedChange": {"metric", "upper", "prior", "value", "span", "previousSpan"},
    "pairedDay": {"date", "bp", "metric", "value"},
    "pairedDays": {"days", "bp", "metric", "value"},
    "contextChange": {"metric", "prior", "value"},
    "contextOnly": {"span", "metric", "value"},
    "differentDates": set(),
}


def validate(catalog):
    if catalog.keys() != {"version", "zh", "en"} or catalog["version"] != 1:
        raise ValueError("Invalid catalog version or languages")
    for lang in ("zh", "en"):
        messages = catalog[lang]
        if messages.keys() != FIELDS.keys():
            raise ValueError(f"Unexpected scenarios for {lang}")
        for key, fields in FIELDS.items():
            text = messages[key]
            if not isinstance(text, str) or not text.strip() or len(text) > 360:
                raise ValueError(f"Invalid message in {lang}/{key}")
            tokens = set(re.findall(r"\{([a-zA-Z]+)\}", text))
            remainder = re.sub(r"\{[a-zA-Z]+\}", "", text)
            if tokens != fields or "{" in remainder or "}" in remainder:
                raise ValueError(f"Invalid placeholders in {lang}/{key}")


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="Validate the release asset offline")
    group.add_argument("--draft", type=Path, metavar="NEW_FILE", help="Write an editorial candidate")
    args = parser.parse_args()
    catalog = json.loads(CATALOG.read_text())
    validate(catalog)
    if args.check:
        print("Validated both languages and all cardiovascular insight placeholders.")
        return
    if args.draft.exists():
        parser.error("Choose a new draft file.")
    token = os.environ.get("SAY_RING_EDITOR_TOKEN")
    if not token:
        parser.error("A dedicated SAY_RING_EDITOR_TOKEN is required.")
    prompt = (
        "为 Say Ring 编辑手机离线显示的心血管趋势通用中英文文案。仅改进以下目录的表述，保留 JSON 结构、"
        "每条占位符及其含义。血压对比需要两期同一来源各满三个记录日，同期观察仅比较同一日。"
        "不推断风险、成因或治疗，不填入示例读数。仅返回完整 JSON。\n"
        + json.dumps(catalog, ensure_ascii=False)
    )
    body = {"content": prompt, "locale": "zh-Hans", "sessionId": "say-ring-editorial-cardio-v1"}
    req = Request(API, data=json.dumps(body).encode(), headers={
        "Authorization": f"Bearer {token}", "Content-Type": "application/json", "Accept-Language": "zh-Hans",
    })
    try:
        with build_opener(NoRedirect()).open(req, timeout=75) as response:
            envelope = json.load(response)
    except HTTPError as error:
        raise SystemExit(f"Editorial request returned HTTP {error.code}.") from None
    content = envelope.get("data", envelope)["content"].strip()
    if content.startswith("```") and content.endswith("```"):
        content = content.split("\n", 1)[1][:-3].strip()
    draft = json.loads(content)
    validate(draft)
    with args.draft.open("x", encoding="utf-8") as out:
        out.write(json.dumps(draft, ensure_ascii=False, indent=2) + "\n")
    print("Draft saved for editorial review.")


if __name__ == "__main__":
    main()
