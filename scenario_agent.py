"""
ゲームシナリオ制作エージェント
QTE+ADVゲーム「Absolute」専用
ジャンル：百合ホラー × バカエロコメディ
レーティング：R15〜R18
"""
import json
import os
import sys
import re
import anthropic
from pathlib import Path
from datetime import datetime

# =============================================================================
# 設定
# =============================================================================
SAVE_DIR = Path(r"C:\Users\datepo\ドキュメント\Absolute")
SAVE_DIR.mkdir(parents=True, exist_ok=True)

client = anthropic.Anthropic()

# =============================================================================
# ツール実装
# =============================================================================

def _create_outline(title: str, premise: str, chapter_count: int) -> dict:
    """あらすじ・章構成を生成"""
    return {
        "request": "outline",
        "title": title,
        "premise": premise,
        "chapter_count": chapter_count,
    }


def _create_scene(chapter: str, scene_name: str, scene_type: str,
                  characters: list, notes: str) -> dict:
    """シーン脚本を生成するためのパラメータを返す"""
    return {
        "request": "scene",
        "chapter": chapter,
        "scene_name": scene_name,
        "scene_type": scene_type,
        "characters": characters,
        "notes": notes,
    }


def _create_character(name: str, role: str, personality: str, notes: str) -> dict:
    """キャラクタープロフィールを生成するためのパラメータを返す"""
    return {
        "request": "character",
        "name": name,
        "role": role,
        "personality": personality,
        "notes": notes,
    }


def _create_qte_event(scene_context: str, qte_type: str,
                      success_outcome: str, failure_outcome: str) -> dict:
    """QTEイベントシナリオを生成するためのパラメータを返す"""
    return {
        "request": "qte",
        "scene_context": scene_context,
        "qte_type": qte_type,
        "success_outcome": success_outcome,
        "failure_outcome": failure_outcome,
    }


def _create_dialogue(scene_context: str, characters: list, situation: str,
                     tone: str) -> dict:
    """台詞・掛け合いを生成するためのパラメータを返す"""
    return {
        "request": "dialogue",
        "scene_context": scene_context,
        "characters": characters,
        "situation": situation,
        "tone": tone,
    }


def _save_scenario(filename: str, content: str, category: str) -> dict:
    """シナリオをファイルに保存"""
    # カテゴリ別サブフォルダ
    subdir = SAVE_DIR / category
    subdir.mkdir(exist_ok=True)

    # ファイル名にタイムスタンプを付加（重複防止）
    safe_name = re.sub(r'[\\/:*?"<>|]', '_', filename)
    if not safe_name.endswith(".txt"):
        safe_name += ".txt"
    filepath = subdir / safe_name

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(f"# {filename}\n")
        f.write(f"# 保存日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"# カテゴリ: {category}\n\n")
        f.write(content)

    return {"saved": True, "path": str(filepath)}


def _load_scenario(filepath: str) -> dict:
    """ファイルからシナリオを読み込む"""
    path = Path(filepath)
    if not path.exists():
        return {"error": f"ファイルが見つかりません: {filepath}"}
    with open(path, encoding="utf-8") as f:
        content = f.read()
    return {"content": content, "path": str(path)}


def _list_scenarios() -> list:
    """保存済みシナリオ一覧を返す"""
    results = []
    for f in sorted(SAVE_DIR.rglob("*.txt")):
        results.append({
            "name": f.stem,
            "category": f.parent.name,
            "path": str(f),
            "updated": datetime.fromtimestamp(f.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
        })
    return results


def execute_tool(name: str, args: dict) -> str:
    """ツール名に応じて処理を実行"""
    try:
        if name == "create_outline":
            return json.dumps(_create_outline(
                args["title"], args["premise"], args.get("chapter_count", 5)
            ), ensure_ascii=False)

        elif name == "create_scene":
            return json.dumps(_create_scene(
                args["chapter"], args["scene_name"], args["scene_type"],
                args.get("characters", []), args.get("notes", "")
            ), ensure_ascii=False)

        elif name == "create_character":
            return json.dumps(_create_character(
                args["name"], args["role"], args.get("personality", ""),
                args.get("notes", "")
            ), ensure_ascii=False)

        elif name == "create_qte_event":
            return json.dumps(_create_qte_event(
                args["scene_context"], args["qte_type"],
                args.get("success_outcome", ""), args.get("failure_outcome", "")
            ), ensure_ascii=False)

        elif name == "create_dialogue":
            return json.dumps(_create_dialogue(
                args["scene_context"], args.get("characters", []),
                args["situation"], args.get("tone", "")
            ), ensure_ascii=False)

        elif name == "save_scenario":
            return json.dumps(_save_scenario(
                args["filename"], args["content"], args.get("category", "misc")
            ), ensure_ascii=False)

        elif name == "load_scenario":
            return json.dumps(_load_scenario(args["filepath"]), ensure_ascii=False)

        elif name == "list_scenarios":
            return json.dumps(_list_scenarios(), ensure_ascii=False)

        else:
            return json.dumps({"error": f"不明なツール: {name}"})
    except Exception as e:
        return json.dumps({"error": str(e)})


# =============================================================================
# ツール定義（Claude APIに渡すスキーマ）
# =============================================================================
TOOLS = [
    {
        "name": "create_outline",
        "description": "ゲーム全体のあらすじと章構成（ストーリーライン）を作成します。",
        "input_schema": {
            "type": "object",
            "properties": {
                "title":         {"type": "string", "description": "作品タイトル"},
                "premise":       {"type": "string", "description": "前提・世界観・主人公設定など"},
                "chapter_count": {"type": "integer", "description": "章数（デフォルト5）"},
            },
            "required": ["title", "premise"],
        },
    },
    {
        "name": "create_scene",
        "description": "特定シーンの詳細脚本（ト書き・台詞・演出指示）を作成します。ホラー演出・コメディ・百合エロ要素を含められます。",
        "input_schema": {
            "type": "object",
            "properties": {
                "chapter":    {"type": "string", "description": "章番号またはタイトル"},
                "scene_name": {"type": "string", "description": "シーン名"},
                "scene_type": {
                    "type": "string",
                    "enum": ["horror", "comedy", "yuri_romance", "yuri_erotic", "action", "daily", "climax"],
                    "description": "シーンの種類",
                },
                "characters": {
                    "type": "array", "items": {"type": "string"},
                    "description": "登場キャラクター名のリスト",
                },
                "notes": {"type": "string", "description": "演出の注意点・含めたい要素など"},
            },
            "required": ["chapter", "scene_name", "scene_type"],
        },
    },
    {
        "name": "create_character",
        "description": "キャラクタープロフィール（外見・性格・背景・百合関係性）を作成します。",
        "input_schema": {
            "type": "object",
            "properties": {
                "name":        {"type": "string", "description": "キャラクター名"},
                "role":        {"type": "string", "description": "役割（主人公・ヒロイン・敵・サブキャラなど）"},
                "personality": {"type": "string", "description": "性格・特徴の概要"},
                "notes":       {"type": "string", "description": "その他メモ（関係性・秘密・伏線など）"},
            },
            "required": ["name", "role"],
        },
    },
    {
        "name": "create_qte_event",
        "description": "QTEイベントのシナリオを作成します。成功・失敗それぞれの展開を含みます。",
        "input_schema": {
            "type": "object",
            "properties": {
                "scene_context":    {"type": "string", "description": "QTEが発生するシーンの状況説明"},
                "qte_type":         {"type": "string", "description": "QTEの種類（逃走・戦闘・回避・解錠・誘惑など）"},
                "success_outcome":  {"type": "string", "description": "成功した場合の展開（任意）"},
                "failure_outcome":  {"type": "string", "description": "失敗した場合の展開（任意）"},
            },
            "required": ["scene_context", "qte_type"],
        },
    },
    {
        "name": "create_dialogue",
        "description": "特定シーンのキャラクター台詞・掛け合いをADV形式で作成します。",
        "input_schema": {
            "type": "object",
            "properties": {
                "scene_context": {"type": "string", "description": "シーンの状況説明"},
                "characters": {
                    "type": "array", "items": {"type": "string"},
                    "description": "登場キャラクター名",
                },
                "situation":  {"type": "string", "description": "台詞が発生する具体的な状況"},
                "tone":       {"type": "string", "description": "雰囲気（ホラー・コメディ・甘い・緊張感など）"},
            },
            "required": ["scene_context", "situation"],
        },
    },
    {
        "name": "save_scenario",
        "description": "生成したシナリオをファイルに保存します。",
        "input_schema": {
            "type": "object",
            "properties": {
                "filename": {"type": "string", "description": "保存するファイル名（拡張子不要）"},
                "content":  {"type": "string", "description": "保存するシナリオ本文"},
                "category": {
                    "type": "string",
                    "enum": ["outline", "scene", "character", "qte", "dialogue", "misc"],
                    "description": "カテゴリ（フォルダ分け）",
                },
            },
            "required": ["filename", "content"],
        },
    },
    {
        "name": "load_scenario",
        "description": "保存済みシナリオファイルを読み込みます。",
        "input_schema": {
            "type": "object",
            "properties": {
                "filepath": {"type": "string", "description": "読み込むファイルのフルパス"},
            },
            "required": ["filepath"],
        },
    },
    {
        "name": "list_scenarios",
        "description": "保存済みシナリオの一覧を取得します。",
        "input_schema": {"type": "object", "properties": {}, "required": []},
    },
]

# =============================================================================
# システムプロンプト
# =============================================================================
SYSTEM_PROMPT = """あなたは百合ホラー×バカエロコメディジャンルに特化した、ベテランのゲームシナリオライターです。
QTE+ADVゲーム「Absolute」のシナリオ制作をサポートします。

## あなたの得意分野
- **ホラー演出**：じわじわと恐怖を積み上げる心理ホラー、突然の恐怖演出（ジャンプスケア的な台詞・状況）、不気味な伏線の配置
- **バカコメディ**：シリアスな場面を台無しにするズッコケ展開、キャラのズレた言動による笑い、テンポよい掛け合い
- **百合エロ**：女性キャラ同士の甘くドキドキする関係性、R15〜R18相当の描写（直接的な性行為の描写なし、着衣の上からの前戯・キス・密着シーンまで）
- **QTE設計**：緊張感のある選択肢・成功/失敗分岐のドラマ作り

## シナリオ執筆スタイル
- ADVゲーム形式：「キャラ名：台詞」「（ト書き）」「【選択肢】」の形式で書く
- 台詞はキャラの個性が出るように、くどくならない長さで
- ホラーとコメディのテンポの緩急を意識する（怖い→笑い→怖い のリズム）
- 百合描写は「萌え」を大切に、強引すぎず自然な流れで
- レーティング：R15〜R18（性行為の直接描写なし、前戯・身体接触・際どい台詞まで）

## ツールの使い方
1. ユーザーの依頼を理解し、適切なツールを選んで実行する
2. 生成したシナリオは必ずsave_scenarioで保存し、ファイルパスをユーザーに伝える
3. 既存シナリオを参照したい場合はlist_scenarios→load_scenarioの順で確認する
4. 一度の依頼で複数ツールを組み合わせて良い（キャラ作成→シーン作成→保存など）

## 注意事項
- 常に日本語で返答する
- 生成したシナリオは必ず保存する
- ユーザーの設定・世界観を尊重し、勝手に変えない
- 直接的な性行為描写（挿入・フェラチオ等）は生成しない"""


# =============================================================================
# エージェントのメインループ
# =============================================================================
def run_agent(user_request: str) -> None:
    messages = [{"role": "user", "content": user_request}]
    print()

    while True:
        response = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=8096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        for block in response.content:
            if block.type == "text" and block.text:
                print(block.text)

        if response.stop_reason == "end_turn":
            break

        if response.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    print(f"\n  [🔧 {block.name}]", end=" ", flush=True)
                    result = execute_tool(block.name, block.input)
                    preview = result[:120].replace("\n", " ")
                    print(f"→ {preview}{'...' if len(result) > 120 else ''}")
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "user", "content": tool_results})
        else:
            break


# =============================================================================
# CLI エントリーポイント
# =============================================================================
def main() -> None:
    print("=" * 55)
    print("  シナリオ制作エージェント - Absolute")
    print("  ジャンル：百合ホラー × バカエロコメディ")
    print("  モデル  ：claude-opus-4-6")
    print(f"  保存先  ：{SAVE_DIR}")
    print("  終了    ：quit または Ctrl+C")
    print("=" * 55)

    try:
        while True:
            print()
            user_input = input("依頼: ").strip()
            if not user_input:
                continue
            if user_input.lower() in ("quit", "exit", "q"):
                print("終了します。")
                break
            run_agent(user_input)
    except KeyboardInterrupt:
        print("\n終了します。")


if __name__ == "__main__":
    main()
