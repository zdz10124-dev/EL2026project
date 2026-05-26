import { useState, useCallback } from 'react';
import { api } from '../utils/api';
import type { ReminderSettings, UpdateReminderRequest } from '../types';

export function useReminder() {
  const [settings, setSettings] = useState<ReminderSettings | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchSettings = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.getReminderSettings();
      if (res.code === 0) {
        setSettings(res.data as ReminderSettings);
      } else {
        setError(res.message);
      }
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }, []);

  const updateSettings = useCallback(async (data: UpdateReminderRequest) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.updateReminderSettings(data);
      if (res.code === 0) {
        setSettings(res.data as ReminderSettings);
        return true;
      } else {
        setError(res.message);
        return false;
      }
    } catch {
      setError('网络错误，请重试');
      return false;
    } finally {
      setLoading(false);
    }
  }, []);

  return { settings, loading, error, fetchSettings, updateSettings };
}
