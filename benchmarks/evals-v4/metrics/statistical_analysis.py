#!/usr/bin/env python3
"""
Statistical Analysis v4
pass@k, pass^k, 効果量、信頼区間を計算する
"""

import json
import math
import statistics
from pathlib import Path
from typing import Dict, List, Any, Tuple
from collections import defaultdict


class StatisticalAnalyzer:
    """統計分析: 評価結果を分析し、メトリクスを計算"""

    def __init__(self, results_dir: Path):
        self.results_dir = Path(results_dir).resolve()

    def load_results(self, task_id: str) -> Dict[str, List[Dict[str, Any]]]:
        """結果を読み込む"""
        results = {
            "with-plugin": [],
            "without-plugin": [],
        }
        
        for mode in ["with-plugin", "without-plugin"]:
            mode_dir = self.results_dir / task_id / mode
            if not mode_dir.exists():
                continue
            
            for iter_dir in sorted(mode_dir.glob("iter_*")):
                result_file = iter_dir / "result.json"
                if result_file.exists():
                    try:
                        with open(result_file, 'r', encoding='utf-8') as f:
                            results[mode].append(json.load(f))
                    except Exception as e:
                        print(f"Error loading {result_file}: {e}", file=sys.stderr)
        
        return results

    def calculate_pass_at_k(self, results: List[Dict[str, Any]], k: int = 1) -> float:
        """pass@kを計算
        
        pass@k: k回の試行のうち、少なくとも1回成功する確率
        """
        if len(results) == 0:
            return 0.0
        
        successes = sum(1 for r in results if r.get('execution', {}).get('success', False))
        total = len(results)
        
        if k == 1:
            return successes / total if total > 0 else 0.0
        
        # k > 1の場合、組み合わせを計算
        # pass@k = 1 - (失敗数 C k) / (総数 C k)
        failures = total - successes
        
        if failures < k:
            return 1.0
        
        # 組み合わせ計算: C(n, k) = n! / (k! * (n-k)!)
        def combination(n: int, k: int) -> float:
            if k > n or k < 0:
                return 0.0
            if k == 0 or k == n:
                return 1.0
            result = 1.0
            for i in range(min(k, n - k)):
                result = result * (n - i) / (i + 1)
            return result
        
        total_combinations = combination(total, k)
        failure_combinations = combination(failures, k)
        
        if total_combinations == 0:
            return 0.0
        
        return 1.0 - (failure_combinations / total_combinations)

    def calculate_pass_power_k(self, results: List[Dict[str, Any]], k: int = 1) -> float:
        """pass^kを計算
        
        pass^k: k回の試行すべてが成功する確率
        """
        if len(results) == 0:
            return 0.0
        
        successes = sum(1 for r in results if r.get('execution', {}).get('success', False))
        total = len(results)
        
        if total == 0:
            return 0.0
        
        success_rate = successes / total
        return success_rate ** k

    def calculate_effect_size(self, with_plugin: List[Dict[str, Any]], without_plugin: List[Dict[str, Any]]) -> float:
        """Cohen's d（効果量）を計算"""
        def extract_scores(results: List[Dict[str, Any]]) -> List[float]:
            scores = []
            for r in results:
                # 成功を1、失敗を0としてスコア化
                success = r.get('execution', {}).get('success', False)
                scores.append(1.0 if success else 0.0)
            return scores
        
        scores_with = extract_scores(with_plugin)
        scores_without = extract_scores(without_plugin)
        
        if len(scores_with) == 0 or len(scores_without) == 0:
            return 0.0
        
        mean_with = statistics.mean(scores_with)
        mean_without = statistics.mean(scores_without)
        
        # プールされた標準偏差
        var_with = statistics.variance(scores_with) if len(scores_with) > 1 else 0.0
        var_without = statistics.variance(scores_without) if len(scores_without) > 1 else 0.0
        
        n_with = len(scores_with)
        n_without = len(scores_without)
        
        pooled_std = math.sqrt(
            ((n_with - 1) * var_with + (n_without - 1) * var_without) / (n_with + n_without - 2)
        ) if (n_with + n_without) > 2 else 1.0
        
        if pooled_std == 0:
            return 0.0
        
        return (mean_with - mean_without) / pooled_std

    def calculate_confidence_interval(self, results: List[Dict[str, Any]], confidence: float = 0.95) -> Tuple[float, float]:
        """信頼区間を計算（正規分布近似）"""
        def extract_scores(results: List[Dict[str, Any]]) -> List[float]:
            scores = []
            for r in results:
                success = r.get('execution', {}).get('success', False)
                scores.append(1.0 if success else 0.0)
            return scores
        
        scores = extract_scores(results)
        
        if len(scores) == 0:
            return (0.0, 0.0)
        
        mean = statistics.mean(scores)
        std_err = statistics.stdev(scores) / math.sqrt(len(scores)) if len(scores) > 1 else 0.0
        
        # z値（95%信頼区間 = 1.96）
        z = 1.96 if confidence == 0.95 else 2.576 if confidence == 0.99 else 1.645
        
        margin = z * std_err
        
        return (max(0.0, mean - margin), min(1.0, mean + margin))

    def analyze_task(self, task_id: str) -> Dict[str, Any]:
        """タスクの結果を分析"""
        results = self.load_results(task_id)
        
        with_plugin = results.get("with-plugin", [])
        without_plugin = results.get("without-plugin", [])
        
        # pass@k (k=1, 5, 10)
        pass_at_1_with = self.calculate_pass_at_k(with_plugin, k=1)
        pass_at_1_without = self.calculate_pass_at_k(without_plugin, k=1)
        pass_at_5_with = self.calculate_pass_at_k(with_plugin, k=5) if len(with_plugin) >= 5 else None
        pass_at_5_without = self.calculate_pass_at_k(without_plugin, k=5) if len(without_plugin) >= 5 else None
        
        # pass^k (k=1, 3, 5)
        pass_power_1_with = self.calculate_pass_power_k(with_plugin, k=1)
        pass_power_1_without = self.calculate_pass_power_k(without_plugin, k=1)
        pass_power_3_with = self.calculate_pass_power_k(with_plugin, k=3) if len(with_plugin) >= 3 else None
        pass_power_3_without = self.calculate_pass_power_k(without_plugin, k=3) if len(without_plugin) >= 3 else None
        
        # 効果量
        effect_size = self.calculate_effect_size(with_plugin, without_plugin)
        
        # 信頼区間
        ci_with = self.calculate_confidence_interval(with_plugin)
        ci_without = self.calculate_confidence_interval(without_plugin)
        
        # 平均実行時間
        def avg_duration(results: List[Dict[str, Any]]) -> float:
            durations = [r.get('execution', {}).get('duration_seconds', 0) for r in results]
            return statistics.mean(durations) if durations else 0.0

        def raw_success_rate(results: List[Dict[str, Any]]) -> float:
            if not results:
                return 0.0
            successes = sum(
                1 for r in results if r.get('execution', {}).get('raw_success', False)
            )
            return successes / len(results)
        
        avg_duration_with = avg_duration(with_plugin)
        avg_duration_without = avg_duration(without_plugin)
        raw_success_with = raw_success_rate(with_plugin)
        raw_success_without = raw_success_rate(without_plugin)
        
        return {
            "task_id": task_id,
            "sample_sizes": {
                "with-plugin": len(with_plugin),
                "without-plugin": len(without_plugin),
            },
            "pass_at_k": {
                "with-plugin": {
                    "k=1": pass_at_1_with,
                    "k=5": pass_at_5_with,
                },
                "without-plugin": {
                    "k=1": pass_at_1_without,
                    "k=5": pass_at_5_without,
                },
            },
            "pass_power_k": {
                "with-plugin": {
                    "k=1": pass_power_1_with,
                    "k=3": pass_power_3_with,
                },
                "without-plugin": {
                    "k=1": pass_power_1_without,
                    "k=3": pass_power_3_without,
                },
            },
            "effect_size": {
                "cohens_d": effect_size,
                "interpretation": self._interpret_effect_size(effect_size),
            },
            "confidence_intervals": {
                "with-plugin": {
                    "lower": ci_with[0],
                    "upper": ci_with[1],
                },
                "without-plugin": {
                    "lower": ci_without[0],
                    "upper": ci_without[1],
                },
            },
            "average_durations": {
                "with-plugin": avg_duration_with,
                "without-plugin": avg_duration_without,
            },
            "raw_execution_success_rate": {
                "with-plugin": raw_success_with,
                "without-plugin": raw_success_without,
            },
        }

    def _interpret_effect_size(self, d: float) -> str:
        """効果量の解釈"""
        abs_d = abs(d)
        if abs_d < 0.2:
            return "negligible"
        elif abs_d < 0.5:
            return "small"
        elif abs_d < 0.8:
            return "medium"
        else:
            return "large"

    def generate_report(self, task_ids: List[str], output_format: str = "json") -> str:
        """レポートを生成"""
        analyses = {}
        for task_id in task_ids:
            analyses[task_id] = self.analyze_task(task_id)
        
        if output_format == "json":
            return json.dumps(analyses, indent=2, ensure_ascii=False)
        elif output_format == "markdown":
            return self._generate_markdown_report(analyses)
        else:
            return str(analyses)

    def _generate_markdown_report(self, analyses: Dict[str, Dict[str, Any]]) -> str:
        """Markdownレポートを生成"""
        lines = ["# Evaluation Report v4\n"]
        
        for task_id, analysis in analyses.items():
            lines.append(f"## Task: {task_id}\n")
            
            # サンプルサイズ
            lines.append(f"### Sample Sizes")
            lines.append(f"- with-plugin: {analysis['sample_sizes']['with-plugin']}")
            lines.append(f"- without-plugin: {analysis['sample_sizes']['without-plugin']}\n")
            
            # pass@k
            lines.append(f"### pass@k")
            lines.append(f"| Mode | k=1 | k=5 |")
            lines.append(f"|------|-----|-----|")
            lines.append(f"| with-plugin | {analysis['pass_at_k']['with-plugin']['k=1']:.3f} | {analysis['pass_at_k']['with-plugin'].get('k=5', 'N/A')} |")
            lines.append(f"| without-plugin | {analysis['pass_at_k']['without-plugin']['k=1']:.3f} | {analysis['pass_at_k']['without-plugin'].get('k=5', 'N/A')} |\n")
            
            # pass^k
            lines.append(f"### pass^k")
            lines.append(f"| Mode | k=1 | k=3 |")
            lines.append(f"|------|-----|-----|")
            lines.append(f"| with-plugin | {analysis['pass_power_k']['with-plugin']['k=1']:.3f} | {analysis['pass_power_k']['with-plugin'].get('k=3', 'N/A')} |")
            lines.append(f"| without-plugin | {analysis['pass_power_k']['without-plugin']['k=1']:.3f} | {analysis['pass_power_k']['without-plugin'].get('k=3', 'N/A')} |\n")
            
            # 効果量
            lines.append(f"### Effect Size (Cohen's d)")
            lines.append(f"- Value: {analysis['effect_size']['cohens_d']:.3f}")
            lines.append(f"- Interpretation: {analysis['effect_size']['interpretation']}\n")
            
            # 信頼区間
            lines.append(f"### 95% Confidence Intervals")
            ci_with = analysis['confidence_intervals']['with-plugin']
            ci_without = analysis['confidence_intervals']['without-plugin']
            lines.append(f"- with-plugin: [{ci_with['lower']:.3f}, {ci_with['upper']:.3f}]")
            lines.append(f"- without-plugin: [{ci_without['lower']:.3f}, {ci_without['upper']:.3f}]\n")
            
            # 平均実行時間
            lines.append(f"### Average Duration (seconds)")
            lines.append(f"- with-plugin: {analysis['average_durations']['with-plugin']:.2f}")
            lines.append(f"- without-plugin: {analysis['average_durations']['without-plugin']:.2f}\n")

            # 生の実行成功率
            lines.append(f"### Raw Execution Success Rate")
            lines.append(f"- with-plugin: {analysis['raw_execution_success_rate']['with-plugin']:.3f}")
            lines.append(f"- without-plugin: {analysis['raw_execution_success_rate']['without-plugin']:.3f}\n")
        
        return "\n".join(lines)


def main():
    """メイン関数"""
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description="Statistical Analysis v4")
    parser.add_argument("results_dir", help="Results directory")
    parser.add_argument("--task-id", help="Specific task ID to analyze")
    parser.add_argument("--format", choices=["json", "markdown"], default="json", help="Output format")
    parser.add_argument("--output", help="Output file path")
    
    args = parser.parse_args()
    
    analyzer = StatisticalAnalyzer(Path(args.results_dir))
    
    # タスクIDのリストを取得
    if args.task_id:
        task_ids = [args.task_id]
    else:
        # 結果ディレクトリから全タスクIDを取得
        task_ids = [d.name for d in Path(args.results_dir).iterdir() if d.is_dir()]
    
    # レポートを生成
    report = analyzer.generate_report(task_ids, output_format=args.format)
    
    # 出力
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"Report saved to: {args.output}")
    else:
        print(report)


if __name__ == "__main__":
    main()
