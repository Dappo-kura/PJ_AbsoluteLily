# -*- coding: utf-8 -*-
"""scenario/*.txt (台本形式) → godot_project/data/scenario.json 変換ツール

台本の構造:
  【場面①】ヘッダ           … シーン区切り
  話者：「セリフ」            … 台詞（複数行は行頭全角スペースで継続）
  話者：（心の声）            … 思考台詞
  （ト書き）                 … ナレーション
  テキスト：「…」            … ナレーション
  ★★★　QTE発生　★★★      … QTE。直後の │▶ label（成功ルート）│ 箱で選択肢定義
  【 QTE：成功ルート 】       … ルート別シーン
  ──成功ルート・クリア──     … ルート終端（クリア=合流 / 死亡エンド=バッドエンド）
  （全ルート合流→…）         … 合流点。次の【場面】に接続

使い方:
  python tools/scenario_converter.py
生成物:
  godot_project/data/scenario.json
  tools/conversion_report.md      … 変換時の警告・手動確認ポイント
tools/scenario_overrides.json があれば、生成後にシーン単位で上書きを適用する。
"""
import json
import os
import re
import sys
from datetime import datetime

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENARIO_DIR = os.path.join(BASE, "scenario")
OUTPUT_PATH = os.path.join(BASE, "godot_project", "data", "scenario.json")
OVERRIDES_PATH = os.path.join(BASE, "tools", "scenario_overrides.json")
REPORT_PATH = os.path.join(BASE, "tools", "conversion_report.md")

# 章ファイルの読み込み順と章ID
CHAPTER_FILES = [
    ("序章.txt", "C0", "序章 噂のプリクラ"),
    ("第2章_異世界へ行く.txt", "C2", "第2章 異世界へ行く"),
    ("第3章_暗い本屋とテケテケ.txt", "C3", "第3章 暗い本屋とテケテケ"),
    ("第4章_生きた人形の回廊.txt", "C4", "第4章 生きた人形の回廊"),
    ("第5章_八尺様の領域.txt", "C5", "第5章 八尺様の領域"),
    ("第6章_のっぺらぼうと改札の向こう.txt", "C6", "第6章 のっぺらぼうと改札の向こう"),
    ("第7章_帰還列車と願いの行方.txt", "C7", "第7章 帰還列車と願いの行方"),
]

# 話者 → 立ち絵（ベース名で照合。「結（心の声）」→「結」）
CHARACTER_IMAGES = {
    "舞": "mai-hinata.png",
    "結": "yui-shitsuki.png",
    "口裂け女": "Slit-MouthWoman.png",
}

# 場面ヘッダのキーワード → 背景画像
BG_KEYWORDS = [
    # 具体的な複合ロケーションを先に判定する（先頭一致採用）
    ("迷界駅", "bg-meikai-station.png"),
    ("満員電車", "bg-meikai-station.png"),
    ("電車内", "bg-meikai-station.png"),
    ("プリクラ", "bg-liminal-arcade.png"),
    ("ゲームセンター", "bg-liminal-arcade.png"),
    ("奥書庫", "bg-dark-bookstore.png"),
    ("書店", "bg-dark-bookstore.png"),
    ("アパレル", "bg-mannequin-mall.png"),
    ("中央フロア", "bg-mannequin-mall.png"),
    ("B1", "bg-mannequin-mall.png"),
    ("地下通路", "bg-mannequin-mall.png"),
    ("モール前", "On-the-way-home.png"),
    ("教室", "classroom-evening.png"),
    ("廊下", "school hallway01.png"),
    ("下校", "On-the-way-home.png"),
    ("帰り道", "On-the-way-home.png"),
]

ROUTE_KEYS = {"成功": "success", "失敗": "fail", "ハーレム": "harem"}

RE_SCENE_HEADER = re.compile(r"^【(場面[^】]*|移動シーン)】(.*)$")
RE_QTE_MARKER = re.compile(r"★+\s*QTE発生([①-⑨\d]?)\s*★+")
RE_OPTION = re.compile(r"▶\s*(.+?)（(成功|失敗|ハーレム)ルート）")
RE_OPTION_WRONG = re.compile(r"▶\s*(.+?)\s*（×）")
RE_OPTION_PLAIN = re.compile(r"▶\s*(.+?)\s*$")
RE_ROUTE_HEADER = re.compile(r"^【\s*QTE[^：】]*：\s*(成功|失敗|ハーレム)ルート[^】]*】")
RE_ROUTE_END = re.compile(r"^──.*(クリア|死亡エンド|死亡END).*──")
RE_MERGE = re.compile(r"全ルート合流")
RE_DIALOGUE = re.compile(r"^([^\s：「（★│▶※].{0,20}?)：(.+)$")
RE_DECOR = re.compile(r"^[━─│┌┐└┘├┤=＝\s]*$")
# エンディング分岐マーカー（第7章終盤）: シーン分割を発生させる
RE_SPLIT_MARKER = re.compile(r"^[（(]\s*(QTE成功ルート|ハーレムルート)\s*[）)]$")
RE_CONTINUE_MARKER = re.compile(r"^[（(]\s*成功ルート続き\s*[）)]$")
# 章末マーカー等、本文として出力しない行
RE_CHAPTER_END = re.compile(r"^(序?章?\s*第?[0-9０-９]*章?\s*了|全章\s*完|完\s*[―ー-].*|──.*了.*──)$")

warnings = []


def warn(chapter, message):
    warnings.append((chapter, message))


def strip_decoration(text):
    return text.replace("│", " ").strip()


def is_balanced(text):
    """「」と（）の対応が閉じているか（複数行台詞の継続判定用）"""
    return (text.count("「") <= text.count("」")) and (text.count("（") <= text.count("）"))


def clean_text(text):
    """外側の「」を剥がし、継続行の字下げを除去した本文にする"""
    text = text.strip()
    if text.startswith("「") and text.endswith("」") and text.count("「") == 1:
        text = text[1:-1]
    return text


def guess_bg(header):
    for keyword, image in BG_KEYWORDS:
        if keyword in header:
            return image
    return None


def character_for(speaker):
    base = re.split(r"[（(]", speaker)[0].strip()
    return CHARACTER_IMAGES.get(base)


class Scene:
    def __init__(self, scene_id, title=""):
        self.id = scene_id
        self.title = title
        self.bg = None
        self.events = []
        self.next = None
        self.qte = None          # QTE定義（rootレベル）
        self.is_ending = False
        self.ending_id = None
        self.ending_label = None

    def to_dict(self):
        d = {"id": self.id}
        if self.title:
            d["title"] = self.title
        if self.bg:
            d["bg"] = self.bg
        d["events"] = self.events
        if self.qte:
            d["qte"] = self.qte
        if self.is_ending:
            d["isEnding"] = True
            d["endingId"] = self.ending_id or self.id
            if self.ending_label:
                d["ending_label"] = self.ending_label
        elif self.next:
            d["next"] = self.next
        return d


class ChapterParser:
    def __init__(self, chapter_id, chapter_title, lines):
        self.cid = chapter_id
        self.ctitle = chapter_title
        self.lines = lines
        self.pos = 0
        self.scenes = []            # 通常シーン（場面単位）
        self.route_scenes = []      # QTEルートシーン
        self.scene_count = 0
        self.qte_count = 0
        self.current = None         # 書き込み先シーン
        self.pending_qte = None     # {"scene": Scene, "labels": {...}, "routes": {...}}
        self.unresolved_merges = [] # 合流先が未確定のシーン（次の場面 or 次章の先頭へ）

    def new_scene(self, title=""):
        self.scene_count += 1
        scene = Scene("%s_S%d" % (self.cid, self.scene_count), title)
        bg = guess_bg(title)
        if bg:
            scene.bg = bg
        elif title:
            warn(self.cid, "背景未割当の場面: %s (%s)" % (scene.id, title))
        # 直前の通常シーンからの接続
        self._connect_pending(scene.id)
        self.scenes.append(scene)
        self.current = scene
        return scene

    def _connect_pending(self, scene_id):
        """新しい場面が始まったとき、前の場面・未合流ルートを接続する"""
        if self.pending_qte:
            self._finalize_qte(scene_id)
        elif self.scenes and self.scenes[-1].next is None and not self.scenes[-1].is_ending \
                and self.scenes[-1].qte is None:
            self.scenes[-1].next = scene_id
        for scene in self.unresolved_merges:
            scene.next = scene_id
        self.unresolved_merges = []

    def _finalize_qte(self, merge_target):
        """QTEの遷移先を確定させる"""
        info = self.pending_qte
        scene = info["scene"]
        labels = info["labels"]
        routes = info["routes"]
        qte = {
            "text": "生き残れ！",
            "labels": [labels.get("success", "逃げる！")],
            "duration": 5000,
        }
        if "harem" in labels:
            qte["harem_label"] = labels["harem"]
        for key in ("success", "fail", "harem"):
            if key in routes:
                qte["%s_to" % key] = routes[key].id
                # クリア系ルートは合流先へ
                if not routes[key].is_ending and routes[key].next is None:
                    self.unresolved_merges.append(routes[key])
            else:
                # ルート未定義: 成功にフォールバック
                if key != "success":
                    qte.setdefault("%s_to" % key, qte.get("success_to", merge_target or ""))
                else:
                    qte["success_to"] = merge_target or ""
                    warn(self.cid, "QTE成功ルート未定義: %s" % scene.id)
        scene.qte = qte
        self.pending_qte = None

    def add_event(self, event):
        if self.current is None:
            self.new_scene("")
        self.current.events.append(event)

    def parse(self):
        n = len(self.lines)
        while self.pos < n:
            raw = self.lines[self.pos]
            line = raw.rstrip("\n")
            stripped = line.strip()
            self.pos += 1

            if stripped == "" or RE_DECOR.match(stripped):
                continue
            if stripped.startswith("※"):
                continue

            # 場面ヘッダ
            m = RE_SCENE_HEADER.match(stripped)
            if m:
                self.new_scene(m.group(2).strip() or m.group(1))
                continue

            # 【演出】等の演出指示・箱囲みのタイトルはスキップ
            if stripped.startswith("【演出】"):
                continue

            # QTE発生マーカー
            if RE_QTE_MARKER.search(stripped):
                self.qte_count += 1
                if self.current is None:
                    self.new_scene("")
                self.pending_qte = {
                    "scene": self.current,
                    "labels": {},
                    "routes": {},
                    "index": self.qte_count,
                }
                self.current = None  # QTE以降のイベントはルートシーンへ
                continue

            # 選択肢箱 │▶ label（成功ルート）│ / │▶ label（×）│ / │▶ label│
            if "▶" in stripped and self.pending_qte:
                content = strip_decoration(stripped)
                m = RE_OPTION.search(content)
                if m:
                    self.pending_qte["labels"][ROUTE_KEYS[m.group(2)]] = m.group(1).strip()
                elif RE_OPTION_WRONG.search(content):
                    pass  # 不正解選択肢はエンジン側が自動生成するので捨てる
                else:
                    m = RE_OPTION_PLAIN.search(content)
                    if m and "success" not in self.pending_qte["labels"]:
                        self.pending_qte["labels"]["success"] = m.group(1).strip()
                continue

            # QTEルートヘッダ 【 QTE：成功ルート 】
            m = RE_ROUTE_HEADER.match(stripped)
            if m and self.pending_qte:
                route_key = ROUTE_KEYS[m.group(1)]
                scene = Scene("%s_Q%d_%s" % (self.cid, self.pending_qte["index"], route_key.upper()))
                self.route_scenes.append(scene)
                self.pending_qte["routes"][route_key] = scene
                self.current = scene
                continue

            # ルート終端 ──成功ルート・クリア── / ──失敗ルート・死亡エンド──
            m = RE_ROUTE_END.match(stripped)
            if m:
                if self.current is not None and self.current in self.route_scenes:
                    if "死亡" in m.group(1):
                        self.current.is_ending = True
                        self.current.ending_id = "%s_death" % self.current.id.lower()
                        self.current.ending_label = "BAD END"
                self.current = None
                continue

            # 合流マーカー
            if RE_MERGE.search(stripped):
                if self.current is not None and self.current in self.route_scenes \
                        and not self.current.is_ending:
                    self.current = None
                # 合流先は次の場面ヘッダ出現時に解決される
                continue

            # エンディング分岐マーカー: シーン分割（接続はオーバーライドで調整）
            if RE_SPLIT_MARKER.match(stripped):
                scene = self.new_scene(stripped.strip("（）() "))
                warn(self.cid, "エンディング分岐で分割: %s ← '%s' (接続を要確認)" % (scene.id, stripped))
                continue
            if RE_CONTINUE_MARKER.match(stripped):
                # ハーレムルート等を切り離し、次の場面ヘッダから成功ルートの続きが始まる
                self.current = None
                continue

            # ルート系のその他マーカー（手動確認対象）
            if "ルート" in stripped and (stripped.startswith("（") or stripped.startswith("(")):
                warn(self.cid, "手動確認: ルート分岐マーカー '%s' (現在シーン: %s)"
                     % (stripped, self.current.id if self.current else "-"))
                continue

            # QTE直後〜ルートヘッダ間の演出注記等は本文ではないので捨てる
            if self.current is None:
                warn(self.cid, "シーン外のためスキップ (%d行目): %s" % (self.pos, stripped[:40]))
                continue

            # 台詞（話者：本文）
            m = RE_DIALOGUE.match(stripped)
            if m:
                speaker, body = m.group(1).strip(), m.group(2).strip()
                body = self._consume_continuation(body)
                if speaker == "テキスト":
                    self.add_event({"type": "line", "speaker": "", "text": clean_text(body)})
                else:
                    event = {"type": "line", "speaker": speaker, "text": clean_text(body)}
                    image = character_for(speaker)
                    if image:
                        event["character"] = image
                    self.add_event(event)
                continue

            # ト書き（…）
            if stripped.startswith("（"):
                body = self._consume_continuation(stripped)
                self.add_event({"type": "line", "speaker": "", "text": body})
                continue

            # 章末マーカー・箱の残骸は捨てる
            plain = strip_decoration(stripped)
            if plain == "" or RE_CHAPTER_END.match(plain) or plain.startswith("【"):
                continue

            # その他の話者なしテキストはナレーションとして取り込む
            self.add_event({"type": "line", "speaker": "", "text": plain})

        # 章末処理: 未確定の接続は章外(次章)へ持ち越し
        if self.pending_qte:
            self._finalize_qte(None)
        return self

    def _consume_continuation(self, body):
        """「」/（）が閉じるまで継続行を取り込む"""
        while not is_balanced(body) and self.pos < len(self.lines):
            next_line = self.lines[self.pos].rstrip("\n")
            if next_line.strip() == "":
                break
            self.pos += 1
            body += next_line.strip()
        return body

    def tail_scenes(self):
        """次章の先頭に接続すべきシーン群"""
        tails = []
        if self.scenes and self.scenes[-1].next is None and not self.scenes[-1].is_ending \
                and self.scenes[-1].qte is None:
            tails.append(self.scenes[-1])
        tails.extend(self.unresolved_merges)
        # QTE遷移先が空文字のもの（章末QTE）
        for scene in self.scenes + self.route_scenes:
            if scene.qte:
                for key in ("success_to", "fail_to", "harem_to"):
                    if scene.qte.get(key) == "":
                        tails.append((scene, key))
        # 非エンディングで next 未設定のルートシーン
        for scene in self.route_scenes:
            if not scene.is_ending and scene.next is None:
                tails.append(scene)
        return tails


def apply_overrides(data):
    if not os.path.exists(OVERRIDES_PATH):
        return 0
    with open(OVERRIDES_PATH, encoding="utf-8") as f:
        overrides = json.load(f)
    scene_overrides = overrides.get("scene_overrides", {})
    applied = 0
    for chapter in data["chapters"]:
        for i, scene in enumerate(chapter["scenes"]):
            if scene["id"] in scene_overrides:
                patch = scene_overrides[scene["id"]]
                if patch.get("_delete"):
                    chapter["scenes"][i] = None
                else:
                    for key, value in patch.items():
                        if value is None:
                            scene.pop(key, None)
                        else:
                            scene[key] = value
                applied += 1
        chapter["scenes"] = [s for s in chapter["scenes"] if s is not None]
    return applied


def main():
    chapters = []
    parsers = []
    for filename, cid, ctitle in CHAPTER_FILES:
        path = os.path.join(SCENARIO_DIR, filename)
        if not os.path.exists(path):
            warn(cid, "ファイルが見つかりません: %s" % filename)
            continue
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        parser = ChapterParser(cid, ctitle, lines).parse()
        parsers.append(parser)

    # 章間の接続: 章末の未解決シーン → 次章の最初のシーン
    for i, parser in enumerate(parsers):
        if i + 1 < len(parsers) and parsers[i + 1].scenes:
            next_first = parsers[i + 1].scenes[0].id
            for tail in parser.tail_scenes():
                if isinstance(tail, tuple):
                    scene, key = tail
                    scene.qte[key] = next_first
                elif tail.next is None:
                    tail.next = next_first
        else:
            # 最終章: 未解決の末尾はトゥルーエンド扱い
            for tail in parser.tail_scenes():
                if isinstance(tail, tuple):
                    scene, key = tail
                    scene.qte[key] = ""
                    warn(parser.cid, "最終章の未解決QTE遷移: %s.%s" % (scene.id, key))
                else:
                    tail.is_ending = True
                    tail.ending_id = "true_end"
                    tail.ending_label = "迷界ユリメトリカ　―　完"
                    tail.ending_image = "trueend.png"

    for parser in parsers:
        scenes = [s.to_dict() for s in parser.scenes + parser.route_scenes]
        # ending_image はScene生成後に動的に付与される場合がある
        for scene_obj, scene_dict in zip(parser.scenes + parser.route_scenes, scenes):
            if getattr(scene_obj, "ending_image", None):
                scene_dict["ending_image"] = scene_obj.ending_image
        chapters.append({"id": parser.cid, "title": parser.ctitle, "scenes": scenes})

    data = {
        "meta": {
            "title": "迷界ユリメトリカ",
            "version": "2.0.0",
            "generated_by": "tools/scenario_converter.py",
            "generated_from": "scenario/*.txt",
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "notes": "自動生成ファイル。手動編集せず、台本(.txt)と scenario_overrides.json を編集して再生成すること。",
        },
        "chapters": chapters,
    }

    applied = apply_overrides(data)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    # レポート出力
    total_scenes = sum(len(c["scenes"]) for c in chapters)
    total_events = sum(len(s.get("events", [])) for c in chapters for s in c["scenes"])
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("# シナリオ変換レポート\n\n")
        f.write("- 生成日時: %s\n" % data["meta"]["generated_at"])
        f.write("- 章数: %d / シーン数: %d / イベント数: %d\n" % (len(chapters), total_scenes, total_events))
        f.write("- オーバーライド適用: %d件\n\n" % applied)
        f.write("## 警告・手動確認ポイント\n\n")
        if not warnings:
            f.write("なし\n")
        for cid, message in warnings:
            f.write("- [%s] %s\n" % (cid, message))

    print("OK: %d chapters, %d scenes, %d events -> %s" % (len(chapters), total_scenes, total_events, OUTPUT_PATH))
    print("Report: %s (%d warnings)" % (REPORT_PATH, len(warnings)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
