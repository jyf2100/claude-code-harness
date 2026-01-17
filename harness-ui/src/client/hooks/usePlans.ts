import { useState, useEffect, useCallback, useRef } from 'react';
import type { PlansData } from '@shared/types';

const emptyPlans: PlansData = {
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

interface UsePlansOptions {
  projectId?: string | null;
}

export function usePlans(options: UsePlansOptions = {}) {
  const { projectId } = options;
  const [plans, setPlans] = useState<PlansData>(emptyPlans);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const currentProjectId = useRef<string | null | undefined>(projectId);

  const fetchPlans = useCallback(async (pid?: string | null) => {
    try {
      setLoading(true);
      const queryParam = pid ? `?projectId=${encodeURIComponent(pid)}` : '';
      const res = await fetch(`/api/plans${queryParam}`);
      if (!res.ok) throw new Error('Failed to fetch plans');
      const data = await res.json();
      setPlans(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPlans(projectId);
    currentProjectId.current = projectId;
  }, [projectId, fetchPlans]);

  const updatePlans = useCallback((data: PlansData) => {
    // Only update if this is for the current project or no projectId filter
    if (!currentProjectId.current || data.projectId === currentProjectId.current) {
      setPlans(data);
    }
  }, []);

  const refetch = useCallback(() => {
    return fetchPlans(currentProjectId.current);
  }, [fetchPlans]);

  return { plans, loading, error, updatePlans, refetch };
}
