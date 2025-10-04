#!/usr/bin/env python3
"""
初手モード（Overview Mode）のプロンプトテスト
GPT-5-miniで実際のレスポンスを確認
"""

import base64
import json
import os
import sys
import requests

def encode_image(image_path):
    """画像をbase64エンコード"""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def test_overview_mode(api_key, image_path):
    """初手モードのプロンプトでAPIテスト"""

    # 画像をエンコード
    base64_image = encode_image(image_path)

    # システムプロンプト
    system_prompt = """あなたは引越し・処分プランナーです。
部屋の写真を分析し、引越しに向けた処分作業の優先順位を提案してください。

【重要な視点】
- 総量把握：部屋全体にどのくらいの物があり、処分すべき物の量を見積もる
- 処分品分類：SELL（売る）、GIVE（譲る）、RECYCLE（処分）、KEEP（持っていく）の仕分け
- サルベージ優先：まだ使える物・売れる物を見逃さない
- ゴール日からの逆算：処分に時間がかかる物（売却、寄付手配）から着手

【分析の優先順位】
1. 大物・処分判断が重い物（家具・家電）→ 売却/処分に時間がかかる
2. 量が多いエリア（クローゼット、収納棚）→ 仕分けに時間がかかる
3. 売却価値がある物（ガジェット、家電、家具）→ 早めの出品が有利
4. 日常生活への影響が少ない物 → 先に片付けても支障なし

【時間見積もり】
- 仕分け：1エリアあたり30-60分
- 出品準備：写真撮影・説明文作成で物1つあたり10-30分
- 処分手配：粗大ゴミ予約、寄付先調査などで30-60分

【考え方】
- 完璧な片付けではなく、「処分すべき物の洗い出し」が目的
- 後から詳細な仕分けをするため、まずは物の総量とカテゴリを把握
- 売却できる物は早めに出品（引越し直前では間に合わない）

必ず以下のJSON形式で出力してください。"""

    # ユーザープロンプト
    user_prompt = "この部屋の写真を分析し、引越しに向けた処分作業の優先順位を提案してください。"

    # JSON Schema
    json_schema = {
        "type": "object",
        "required": ["overview", "priority_areas", "quick_start"],
        "additionalProperties": False,
        "properties": {
            "overview": {
                "type": "object",
                "required": ["状態", "推定時間", "主な課題"],
                "additionalProperties": False,
                "properties": {
                    "状態": {"type": "string", "description": "物の総量と処分対象の見積もり"},
                    "推定時間": {"type": "string", "description": "仕分け・処分手配の総時間"},
                    "主な課題": {"type": "array", "items": {"type": "string"}, "maxItems": 3}
                }
            },
            "priority_areas": {
                "type": "array",
                "minItems": 3,
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "required": ["順位", "エリア名", "理由", "作業内容", "所要時間", "難易度", "効果"],
                    "additionalProperties": False,
                    "properties": {
                        "順位": {"type": "integer", "minimum": 1},
                        "エリア名": {"type": "string"},
                        "理由": {"type": "string", "maxLength": 100},
                        "作業内容": {
                            "type": "array",
                            "items": {"type": "string"},
                            "minItems": 2,
                            "maxItems": 4
                        },
                        "所要時間": {"type": "string"},
                        "難易度": {"enum": ["簡単", "普通", "難しい"]},
                        "効果": {"enum": ["大", "中", "小"]}
                    }
                }
            },
            "quick_start": {
                "type": "string",
                "description": "最初の30分で処分対象の総量把握のために何をすべきか"
            }
        }
    }

    # APIリクエスト構築
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "gpt-5-mini",
        "input": [
            {
                "role": "system",
                "content": [{"type": "input_text", "text": system_prompt}]
            },
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": user_prompt},
                    {
                        "type": "input_image",
                        "image_url": f"data:image/jpeg;base64,{base64_image}"
                    }
                ]
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "overview_plan",
                "schema": json_schema
            }
        },
        "max_output_tokens": 2500,
        "reasoning": {"effort": "low"}
    }

    print("🚀 APIリクエスト送信中...")
    print(f"📸 画像: {image_path}")
    print(f"🤖 モデル: gpt-5-mini")
    print(f"📊 リクエストサイズ: {len(json.dumps(payload))} bytes\n")

    # APIリクエスト送信
    response = requests.post(
        "https://api.openai.com/v1/responses",
        headers=headers,
        json=payload,
        timeout=60
    )

    # レスポンス確認
    print(f"✅ ステータスコード: {response.status_code}")

    if response.status_code != 200:
        print(f"❌ エラー: {response.text}")
        return None

    # レスポンス解析
    result = response.json()

    # リクエストID
    request_id = response.headers.get('x-request-id', 'N/A')
    print(f"🆔 リクエストID: {request_id}\n")

    # 結果を整形して表示
    print("=" * 80)
    print("📦 APIレスポンス（生データ）:")
    print("=" * 80)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("\n")

    # JSON抽出試行
    try:
        if "outputs" in result and len(result["outputs"]) > 0:
            for output in result["outputs"]:
                if "content" in output:
                    for content in output["content"]:
                        # output_json タイプを探す
                        if content.get("type") == "output_json":
                            parsed_json = content.get("output_json")
                            print("=" * 80)
                            print("✨ 抽出されたJSON（整形版）:")
                            print("=" * 80)
                            print(json.dumps(parsed_json, ensure_ascii=False, indent=2))
                            return parsed_json

                        # output_text タイプもチェック
                        elif content.get("type") == "output_text":
                            text = content.get("text", "")
                            # JSONとしてパース試行
                            try:
                                parsed = json.loads(text)
                                print("=" * 80)
                                print("✨ 抽出されたJSON（整形版）:")
                                print("=" * 80)
                                print(json.dumps(parsed, ensure_ascii=False, indent=2))
                                return parsed
                            except json.JSONDecodeError:
                                print(f"⚠️ output_textがJSONではありません: {text[:200]}")
    except Exception as e:
        print(f"❌ JSON抽出エラー: {e}")

    return result

def load_api_key_from_keychain():
    """macOS KeychainからAPIキーを読み取る"""
    try:
        import subprocess
        result = subprocess.run(
            [
                "security", "find-generic-password",
                "-s", "com.example.tatsutori",
                "-a", "openai_api_key",
                "-w"
            ],
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return None
    except Exception as e:
        print(f"⚠️ Keychainアクセスエラー: {e}")
        return None

def main():
    # APIキーを取得（優先順位: Keychain > 環境変数）
    api_key = load_api_key_from_keychain()

    if not api_key:
        api_key = os.getenv("OPENAI_API_KEY")

    if not api_key:
        print("❌ エラー: APIキーが見つかりません")
        print("\n以下のいずれかを確認してください:")
        print("  1. アプリでAPIキーを設定済みか")
        print("  2. 環境変数 OPENAI_API_KEY が設定されているか")
        print("\n環境変数で設定する場合:")
        print("  export OPENAI_API_KEY='your-api-key-here'")
        sys.exit(1)

    print(f"✅ APIキー取得成功 (長さ: {len(api_key)} 文字)\n")

    # テスト画像のパス
    image_path = "test_images/IMG_6387 Medium.jpeg"

    if not os.path.exists(image_path):
        print(f"❌ エラー: 画像が見つかりません: {image_path}")
        sys.exit(1)

    # テスト実行
    result = test_overview_mode(api_key, image_path)

    if result:
        print("\n✅ テスト成功！")
    else:
        print("\n❌ テスト失敗")
        sys.exit(1)

if __name__ == "__main__":
    main()
