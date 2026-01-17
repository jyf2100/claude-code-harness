import type { PlansData, PlanSection, TaskStatus } from '@shared/types';
import { readFile, watch } from 'fs/promises';

export class PlansParser {
  private plansPath: string;
  private cached: PlansData | null = null;
  private onUpdate: ((data: PlansData) => void) | null = null;
  private watcher: AsyncIterable<{ eventType: string }> | null = null;
  private watcherActive = false;

  constructor(plansPath: string) {
    this.plansPath = plansPath;
  }

  setUpdateCallback(callback: (data: PlansData) => void): void {
    this.onUpdate = callback;
  }

  private parseMarkerToStatus(marker: string | undefined): TaskStatus {
    if (!marker) return 'pending';

    const lower = marker.toLowerCase();
    if (lower.includes('wip') || lower.includes('in_progress')) return 'in_progress';
    if (lower.includes('done') || lower.includes('completed') || lower.includes('complete'))
      return 'completed';
    if (lower.includes('blocked')) return 'blocked';
    return 'pending';
  }

  private parseContent(content: string): PlansData {
    const lines = content.split('\n');
    const sections: PlanSection[] = [];
    let currentSection: PlanSection | null = null;
    let taskIdCounter = 0;

    for (const line of lines) {
      // Section header (## Title)
      const sectionMatch = line.match(/^##\s+(.+)/);
      if (sectionMatch) {
        if (currentSection) {
          sections.push(currentSection);
        }
        currentSection = {
          title: sectionMatch[1].trim(),
          tasks: [],
        };
        continue;
      }

      // Task line (- [ ] task or - [x] task or - task with marker)
      const taskMatch = line.match(/^[-*]\s+\[([x\s])\]\s*(.+)/i);
      const markerTaskMatch = line.match(
        /^[-*]\s+(?:`([^`]+)`\s+)?(.+)/
      );

      if (taskMatch && currentSection) {
        const isCompleted = taskMatch[1].toLowerCase() === 'x';
        const content = taskMatch[2].trim();
        const markerMatch = content.match(/`([^`]+)`/);
        const marker = markerMatch?.[1];
        const cleanContent = content.replace(/`[^`]+`\s*/g, '').trim();

        currentSection.tasks.push({
          id: `task_${++taskIdCounter}`,
          content: cleanContent,
          status: isCompleted ? 'completed' : this.parseMarkerToStatus(marker),
          marker,
        });
      } else if (markerTaskMatch && currentSection && !line.match(/^#+/)) {
        const marker = markerTaskMatch[1];
        const content = markerTaskMatch[2].trim();

        // Skip non-task lines (headers, empty markers)
        if (content && !content.startsWith('#')) {
          currentSection.tasks.push({
            id: `task_${++taskIdCounter}`,
            content,
            status: this.parseMarkerToStatus(marker),
            marker,
          });
        }
      }
    }

    if (currentSection) {
      sections.push(currentSection);
    }

    // Calculate summary
    const allTasks = sections.flatMap((s) => s.tasks);
    const summary = {
      total: allTasks.length,
      pending: allTasks.filter((t) => t.status === 'pending').length,
      inProgress: allTasks.filter((t) => t.status === 'in_progress').length,
      completed: allTasks.filter((t) => t.status === 'completed').length,
      blocked: allTasks.filter((t) => t.status === 'blocked').length,
      progressPercent:
        allTasks.length > 0
          ? Math.round(
              (allTasks.filter((t) => t.status === 'completed').length / allTasks.length) * 100
            )
          : 0,
    };

    return { sections, summary };
  }

  async parse(): Promise<PlansData> {
    try {
      const content = await readFile(this.plansPath, 'utf-8');
      this.cached = this.parseContent(content);
      return this.cached;
    } catch (error) {
      console.error(`Failed to parse Plans.md: ${error}`);
      return {
        sections: [],
        summary: {
          total: 0,
          pending: 0,
          inProgress: 0,
          completed: 0,
          blocked: 0,
          progressPercent: 0,
        },
      };
    }
  }

  getCached(): PlansData | null {
    return this.cached;
  }

  async startWatching(): Promise<void> {
    if (this.watcherActive) return;

    this.watcherActive = true;

    try {
      const watcher = watch(this.plansPath);
      this.watcher = watcher;
      for await (const event of watcher) {
        if (!this.watcherActive) break;
        if (event.eventType === 'change') {
          const data = await this.parse();
          if (this.onUpdate) {
            this.onUpdate(data);
          }
        }
      }
    } catch (error) {
      console.error(`Plans.md watch error: ${error}`);
      this.watcherActive = false;
    }
  }

  stopWatching(): void {
    this.watcherActive = false;
  }
}
