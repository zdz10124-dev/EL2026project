import { useState, useCallback } from 'react';
import { api } from '../utils/api';
import type { SportReport, WeeklyReport, TrainingPlan, GeneratePlanRequest } from '../types';

export function useReport() {
  const [report, setReport] = useState<SportReport | null>(null);
  const [weekly, setWeekly] = useState<WeeklyReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generateReport = useCallback(async (recordId: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.generateReport(recordId);
      if (res.code === 0) {
        setReport(res.data as SportReport);
      } else {
        setError(res.message);
      }
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchWeekly = useCallback(async (weekStart: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.getWeeklyReport(weekStart);
      if (res.code === 0) {
        setWeekly(res.data as WeeklyReport);
      } else {
        setError(res.message);
      }
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }, []);

  return { report, weekly, loading, error, generateReport, fetchWeekly };
}

export function usePlan() {
  const [plan, setPlan] = useState<TrainingPlan | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generatePlan = useCallback(async (data: GeneratePlanRequest) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.generatePlan(data);
      if (res.code === 0) {
        setPlan(res.data as TrainingPlan);
      } else {
        setError(res.message);
      }
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }, []);

  return { plan, loading, error, generatePlan };
}
