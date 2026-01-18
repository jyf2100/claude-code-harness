#!/usr/bin/env python3
"""
Model-based Grader v4
LLMを使用した評価グレーダー（校正前提）
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Anthropic SDKのインポート
try:
    import anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False
    print("Warning: anthropic SDK not installed. Model grading will be skipped.", file=sys.stderr)


class ModelGrader:
    """モデルベースグレーダー: LLMで評価する"""

    def __init__(self, project_dir: Path, api_key: Optional[str] = None):
        self.project_dir = Path(project_dir).resolve()
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        
        if HAS_ANTHROPIC and self.api_key:
            self.client = anthropic.Anthropic(api_key=self.api_key)
        else:
            self.client = None

    def read_plans_md(self) -> str:
        """Plans.mdを読み込む"""
        plans_path = self.project_dir / "Plans.md"
        if plans_path.exists():
            return plans_path.read_text(encoding='utf-8')
        return ""

    def read_transcript(self) -> list:
        """トランスクリプトを読み込む"""
        transcript_path = self.project_dir.parent / "transcript.json"
        if transcript_path.exists():
            try:
                with open(transcript_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                pass
        return []

    def grade_plan_quality(self, rubric: Optional[str] = None) -> int:
        """計画の品質を評価（1-5）"""
        if not self.client:
            return 3  # デフォルトスコア
        
        plans_content = self.read_plans_md()
        if not plans_content:
            return 1
        
        default_rubric = """
評価基準:
5: 曖昧さを完全に解消し、詳細で実行可能な計画。フェーズ分け、テストケース設計、エッジケース考慮が含まれる。
4: ほとんどの曖昧さを解消、軽微な不明点のみ。基本的なフェーズ分けとテスト計画がある。
3: 基本的な計画はあるが、いくつかの曖昧さが残る。テスト計画が不十分。
2: 計画が不十分、多くの曖昧さが未解消。構造化されていない。
1: 計画なし、または曖昧なまま実装開始。
"""
        
        prompt = f"""
以下の Plans.md の内容を評価してください。

{rubric or default_rubric}

Plans.md の内容:
{plans_content}

スコア（1-5の整数のみ）:
"""
        
        try:
            response = self.client.messages.create(
                model="claude-3-5-haiku-20241022",
                max_tokens=10,
                messages=[{"role": "user", "content": prompt}],
            )
            
            score_text = response.content[0].text.strip()
            # スコアを抽出
            import re
            match = re.search(r'\b([1-5])\b', score_text)
            if match:
                return int(match.group(1))
            return 3
        except Exception as e:
            print(f"Error in plan_quality grading: {e}", file=sys.stderr)
            return 3

    def grade_test_coverage(self) -> int:
        """テストカバレッジを評価（1-5）"""
        if not self.client:
            return 3
        
        plans_content = self.read_plans_md()
        
        prompt = f"""
テストは重要なケースを網羅しているか？1-5で評価してください。

評価基準:
5: 完璧なテスト計画、すべての重要なケースを網羅
4: 良いテスト計画、軽微な漏れ
3: 普通、主要なケースは網羅
2: 不十分、重要な漏れ
1: テスト計画なし、または不適切

Plans.md の内容:
{plans_content}

スコア（1-5の整数のみ）:
"""
        
        try:
            response = self.client.messages.create(
                model="claude-3-5-haiku-20241022",
                max_tokens=10,
                messages=[{"role": "user", "content": prompt}],
            )
            
            score_text = response.content[0].text.strip()
            import re
            match = re.search(r'\b([1-5])\b', score_text)
            if match:
                return int(match.group(1))
            return 3
        except Exception as e:
            print(f"Error in test_coverage grading: {e}", file=sys.stderr)
            return 3

    def grade_review_thoroughness(self) -> int:
        """レビューの徹底性を評価（1-5）"""
        if not self.client:
            return 3
        
        transcript = self.read_transcript()
        plans_content = self.read_plans_md()
        
        prompt = f"""
レビューは問題を適切に指摘しているか？1-5で評価してください。

評価基準:
5: 完璧なレビュー、すべての問題を特定
4: 良いレビュー、主要な問題を特定
3: 普通、一部の問題を特定
2: 不十分、重要な問題を見逃している
1: レビューなし、または不適切

Plans.md の内容:
{plans_content}

トランスクリプト（参考）:
{json.dumps(transcript[:10], ensure_ascii=False, indent=2)}

スコア（1-5の整数のみ）:
"""
        
        try:
            response = self.client.messages.create(
                model="claude-3-5-haiku-20241022",
                max_tokens=10,
                messages=[{"role": "user", "content": prompt}],
            )
            
            score_text = response.content[0].text.strip()
            import re
            match = re.search(r'\b([1-5])\b', score_text)
            if match:
                return int(match.group(1))
            return 3
        except Exception as e:
            print(f"Error in review_thoroughness grading: {e}", file=sys.stderr)
            return 3

    def grade_all(self, grader_config: Dict[str, Any]) -> Dict[str, Any]:
        """全グレーダーを実行"""
        results = {}
        
        if not self.client:
            # SDKが利用できない場合はデフォルトスコアを返す
            model_graders = grader_config.get('model_based', {})
            for grader_name in model_graders:
                results[grader_name] = 3  # デフォルトスコア
            results['_warning'] = 'Anthropic SDK not available, using default scores'
            return results
        
        model_graders = grader_config.get('model_based', {})
        
        for grader_name in model_graders:
            grader_method = getattr(self, f"grade_{grader_name}", None)
            if grader_method:
                try:
                    results[grader_name] = grader_method()
                except Exception as e:
                    results[grader_name] = 3
                    results[f"{grader_name}_error"] = str(e)
            else:
                results[grader_name] = 3
        
        return results


def main():
    """メイン関数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Model-based Grader v4")
    parser.add_argument("project_dir", help="Project directory to grade")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--no-llm", action="store_true", help="Skip LLM grading (use defaults)")
    
    args = parser.parse_args()
    
    api_key = None if args.no_llm else os.environ.get("ANTHROPIC_API_KEY")
    grader = ModelGrader(Path(args.project_dir), api_key=api_key)
    
    # グレーダー設定（デフォルト）
    grader_config = {
        "model_based": [
            "plan_quality",
            "test_coverage",
            "review_thoroughness",
        ]
    }
    
    results = grader.grade_all(grader_config)
    
    if args.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        for name, value in results.items():
            if not name.startswith('_'):
                print(f"{name}: {value}")


if __name__ == "__main__":
    main()
