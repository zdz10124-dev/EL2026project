import { useState, useCallback } from 'react';
import { api } from '../utils/api';
import type { SportRecord, CreateRecordRequest, PaginatedList } from '../types';

export function useRecords() {
  const [records, setRecords] = useState<SportRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ page: 1, page_size: 20, total: 0 });

  const fetchRecords = useCallback(async (params?: {
    sport_type?: string;
    start_date?: string;
    end_date?: string;
    page?: number;
  }) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.getRecords(params);
      if (res.code === 0) {
        const data = res.data as PaginatedList<SportRecord>;
        setRecords(data.list);
        setPagination(data.pagination);
      } else {
        setError(res.message);
      }
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }, []);

  const createRecord = useCallback(async (data: CreateRecordRequest) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.createRecord(data);
      if (res.code === 0) {
        return res.data as SportRecord;
      } else {
        setError(res.message);
        return null;
      }
    } catch {
      setError('网络错误，请重试');
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  return { records, loading, error, pagination, fetchRecords, createRecord };
}
