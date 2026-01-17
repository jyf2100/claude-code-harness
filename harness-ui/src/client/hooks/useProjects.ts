import { useState, useEffect, useCallback } from 'react';
import type { Project, ProjectsData } from '@shared/types';

const emptyProjectsData: ProjectsData = {
  projects: [],
  activeProjectId: null,
};

export function useProjects() {
  const [projectsData, setProjectsData] = useState<ProjectsData>(emptyProjectsData);
  const [loading, setLoading] = useState(true);

  const fetchProjects = useCallback(async () => {
    try {
      const res = await fetch('/api/projects');
      if (!res.ok) throw new Error('Failed to fetch projects');
      const data = await res.json();
      setProjectsData(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchProjects();
  }, [fetchProjects]);

  const activeProject = projectsData.projects.find(
    (p) => p.id === projectsData.activeProjectId
  );

  const activateProject = useCallback(async (projectId: string) => {
    try {
      const res = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'activate', projectId }),
      });
      if (res.ok) {
        setProjectsData((prev) => ({
          ...prev,
          projects: prev.projects.map((p) => ({
            ...p,
            isActive: p.id === projectId,
          })),
          activeProjectId: projectId,
        }));
      }
    } catch (err) {
      console.error(err);
    }
  }, []);

  const addProject = useCallback(async (project: Omit<Project, 'id' | 'isActive'>) => {
    try {
      const res = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'add', project }),
      });
      if (res.ok) {
        const data = await res.json();
        setProjectsData((prev) => ({
          ...prev,
          projects: [...prev.projects, data.project],
        }));
        return data.project;
      }
    } catch (err) {
      console.error(err);
    }
    return null;
  }, []);

  const removeProject = useCallback(async (projectId: string) => {
    try {
      const res = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'remove', projectId }),
      });
      if (res.ok) {
        setProjectsData((prev) => ({
          ...prev,
          projects: prev.projects.filter((p) => p.id !== projectId),
          activeProjectId:
            prev.activeProjectId === projectId
              ? prev.projects.find((p) => p.id !== projectId)?.id || null
              : prev.activeProjectId,
        }));
      }
    } catch (err) {
      console.error(err);
    }
  }, []);

  return {
    projects: projectsData.projects,
    activeProject,
    activeProjectId: projectsData.activeProjectId,
    loading,
    activateProject,
    addProject,
    removeProject,
    refetch: fetchProjects,
  };
}
