#!/usr/bin/env python3
"""
Smoke Test: 最小タスクで全経路が動くことを確認
"""

import asyncio
import sys
from pathlib import Path

# 親ディレクトリをパスに追加
sys.path.insert(0, str(Path(__file__).parent))

from eval_runner import EvalRunner


async def smoke_test():
    """スモークテスト: 最小タスクで動作確認"""
    print("=== Smoke Test: Evals v4 ===\n")
    
    # パス設定
    evals_dir = Path(__file__).parent.parent
    tasks_dir = evals_dir / "tasks"
    results_dir = evals_dir / "results" / "smoke_test"
    plugin_dir = evals_dir.parent.parent.parent  # claude-code-harnessルート
    
    # ランナーを作成
    runner = EvalRunner(
        tasks_dir=tasks_dir,
        results_dir=results_dir,
        plugin_dir=plugin_dir,
    )
    
    # 最小タスクを実行（WF-01, 1回のみ）
    task_yaml = tasks_dir / "workflow" / "workflow-tasks.yaml"
    
    print("Running WF-01 with 1 iteration...")
    print("This will test:")
    print("  - Environment isolation")
    print("  - SDK execution (with-plugin / without-plugin)")
    print("  - Transcript recording")
    print("  - Result saving")
    print()
    
    try:
        await runner.run_evaluation(
            task_yaml_path=task_yaml,
            task_id="WF-01",
            iterations=1,
        )
        
        print("\n=== Smoke Test PASSED ===")
        print(f"Results saved to: {results_dir}")
        return 0
    except Exception as e:
        print(f"\n=== Smoke Test FAILED ===")
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(smoke_test())
    sys.exit(exit_code)
