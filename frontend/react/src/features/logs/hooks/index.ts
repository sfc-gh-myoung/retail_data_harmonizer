import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import {
  taskHistoryResponseSchema,
  taskFilterOptionsSchema,
  errorsResponseSchema,
  auditResponseSchema,
  type TaskHistoryData,
  type ErrorsData,
  type AuditData,
} from '../schemas'

// Re-export types for convenience
export type {
  TaskHistoryEntry,
  RecentError,
  AuditLogEntry,
  TaskFilterOptions,
} from '../schemas'

interface TaskHistoryFilters {
  taskName?: string
  state?: string
}

/**
 * Fetch Snowflake task execution history with pagination and filtering.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useTaskHistory(
  page: number = 1,
  pageSize: number = 10,
  filters: TaskHistoryFilters = {}
) {
  const queryParams = new URLSearchParams({
    page: String(page),
    page_size: String(pageSize),
  })
  if (filters.taskName) queryParams.set('task_name', filters.taskName)
  if (filters.state) queryParams.set('state', filters.state)

  return useSuspenseQuery({
    queryKey: ['logs', 'task-history', page, pageSize, filters.taskName ?? '', filters.state ?? ''],
    queryFn: () => fetchApi(`/v2/logs/task-history?${queryParams}`, taskHistoryResponseSchema),
    refetchInterval: 15000, // 15s
  })
}

/**
 * Fetch filter options for task history dropdowns.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useTaskFilterOptions() {
  return useSuspenseQuery({
    queryKey: ['logs', 'task-history', 'filter-options'],
    queryFn: () => fetchApi('/v2/logs/task-history/filter-options', taskFilterOptionsSchema),
    staleTime: 60000, // 1 minute
  })
}

/**
 * Fetch recent pipeline errors with pagination.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useErrors(page: number = 1, pageSize: number = 25) {
  const queryParams = new URLSearchParams({
    page: String(page),
    page_size: String(pageSize),
  })

  return useSuspenseQuery({
    queryKey: ['logs', 'errors', page, pageSize],
    queryFn: () => fetchApi(`/v2/logs/errors?${queryParams}`, errorsResponseSchema),
    refetchInterval: 15000, // 15s
  })
}

/**
 * Fetch audit log entries with pagination.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useAudit(page: number = 1, pageSize: number = 25) {
  const queryParams = new URLSearchParams({
    page: String(page),
    page_size: String(pageSize),
  })

  return useSuspenseQuery({
    queryKey: ['logs', 'audit', page, pageSize],
    queryFn: () => fetchApi(`/v2/logs/audit?${queryParams}`, auditResponseSchema),
    refetchInterval: 30000, // 30s
  })
}

// Re-export types
export type { TaskHistoryData, ErrorsData, AuditData }
