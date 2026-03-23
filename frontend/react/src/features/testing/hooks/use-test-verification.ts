import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, useCallback } from 'react'
import { fetchApi, postApi } from '@/lib/api'
import {
  testingDashboardSchema,
  failuresResponseSchema,
  runTestsResponseSchema,
  testStatusResponseSchema,
  cancelTestsResponseSchema,
  type TestRun,
  type TestStats,
  type AccuracySummary,
  type AccuracyByDifficulty,
  type TestingDashboard,
  type Failure,
  type FailuresResponse,
  type RunTestsResponse,
  type TestStatusResponse,
  type CancelTestsResponse,
  type FilterOptionsTesting,
} from '@/lib/schemas'

// Re-export types from schemas
export type {
  TestRun,
  TestStats,
  AccuracySummary,
  AccuracyByDifficulty,
  TestingDashboard,
  Failure,
  FailuresResponse,
  RunTestsResponse,
  TestStatusResponse,
  CancelTestsResponse,
  FilterOptionsTesting,
}

export type SortColumn = 'METHOD' | 'TEST_INPUT' | 'SCORE' | 'DIFFICULTY'
export type SortDirection = 'ASC' | 'DESC'

// ---------------------------------------------------------------------------
// Hooks
// ---------------------------------------------------------------------------

export function useTestingDashboard() {
  return useQuery({
    queryKey: ['testing', 'dashboard'],
    queryFn: () => fetchApi('/v2/testing/dashboard', testingDashboardSchema),
  })
}

export interface FailuresParams {
  page?: number
  pageSize?: number
  sortCol?: SortColumn
  sortDir?: SortDirection
  methodFilter?: string
  difficultyFilter?: string
}

export function useFailures(params: FailuresParams = {}) {
  const {
    page = 1,
    pageSize = 10,
    sortCol = 'METHOD',
    sortDir = 'ASC',
    methodFilter = 'All',
    difficultyFilter = 'All',
  } = params

  const queryString = new URLSearchParams({
    page: String(page),
    page_size: String(pageSize),
    sort_col: sortCol,
    sort_dir: sortDir,
    method_filter: methodFilter,
    difficulty_filter: difficultyFilter,
  }).toString()

  return useQuery({
    queryKey: ['testing', 'failures', params],
    queryFn: () => fetchApi(`/v2/testing/failures?${queryString}`, failuresResponseSchema),
  })
}

export function useRunAccuracyTests() {
  return useMutation({
    mutationFn: (methods: string[]) =>
      postApi('/v2/testing/run', { methods }, runTestsResponseSchema),
  })
}

export function useCancelTests() {
  return useMutation({
    mutationFn: (runId?: string) =>
      postApi('/v2/testing/cancel', runId ? { run_id: runId } : {}, cancelTestsResponseSchema),
  })
}

export function useTestStatus(runId: string | null, enabled: boolean = true) {
  return useQuery({
    queryKey: ['testing', 'status', runId],
    queryFn: () => fetchApi(`/v2/testing/status/${runId}`, testStatusResponseSchema),
    enabled: enabled && runId !== null,
    refetchInterval: (query) => {
      // Poll every 3 seconds while running
      if (query.state.data?.status === 'running') {
        return 3000
      }
      return false
    },
  })
}

const ACTIVE_RUN_STORAGE_KEY = 'testing_active_run_id'
const EXPECTED_METHODS_STORAGE_KEY = 'testing_expected_methods'
const STARTED_AT_STORAGE_KEY = 'testing_started_at'

// Timeout threshold: 15 minutes in milliseconds
const STUCK_TIMEOUT_MS = 15 * 60 * 1000

/**
 * Combined hook for managing test execution with polling.
 * Persists activeRunId to localStorage so running state survives page refresh.
 * Includes timeout detection to identify stuck test runs.
 */
export function useTestRunner() {
  const queryClient = useQueryClient()
  
  // Initialize from localStorage to survive page refresh
  const [activeRunId, setActiveRunId] = useState<string | null>(() => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem(ACTIVE_RUN_STORAGE_KEY)
    }
    return null
  })
  const [expectedMethods, setExpectedMethods] = useState<number>(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem(EXPECTED_METHODS_STORAGE_KEY)
      return stored ? parseInt(stored, 10) : 4
    }
    return 4
  })
  const [startedAt, setStartedAt] = useState<number | null>(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem(STARTED_AT_STORAGE_KEY)
      return stored ? parseInt(stored, 10) : null
    }
    return null
  })
  const [completedRunId, setCompletedRunId] = useState<string | null>(null)
  const [isStuck, setIsStuck] = useState(false)
  
  const runTests = useRunAccuracyTests()
  const cancelTests = useCancelTests()
  
  // Poll when we have an active run that hasn't completed yet
  const shouldPoll = activeRunId !== null && completedRunId !== activeRunId
  
  const status = useQuery({
    queryKey: ['testing', 'status', activeRunId, expectedMethods],
    queryFn: () => fetchApi(`/v2/testing/status/${activeRunId}?expected_methods=${expectedMethods}`, testStatusResponseSchema),
    enabled: shouldPoll && !isStuck,
    // Start polling immediately, then every 3 seconds while running (30s if stuck)
    refetchInterval: (query) => {
      const data = query.state.data
      if (!data || data.status === 'running') {
        return isStuck ? 30000 : 3000
      }
      return false
    },
    // Don't use stale data from a previous run
    staleTime: 0,
  })

  // Check for stuck state based on timeout
  const checkStuckState = useCallback(() => {
    if (startedAt && !isStuck) {
      const elapsed = Date.now() - startedAt
      if (elapsed > STUCK_TIMEOUT_MS) {
        setIsStuck(true)
      }
    }
  }, [startedAt, isStuck])

  // Check for stuck state on each poll
  if (shouldPoll && status.data?.status === 'running') {
    checkStuckState()
  }

  // Derive completion from status data
  const statusCompleted = status.data?.status === 'completed'
  const isCompleted = activeRunId !== null && completedRunId === activeRunId
  
  // When status shows completed and we haven't handled it yet
  if (statusCompleted && activeRunId && completedRunId !== activeRunId) {
    setTimeout(() => {
      queryClient.invalidateQueries({ queryKey: ['testing', 'dashboard'] })
      queryClient.invalidateQueries({ queryKey: ['testing', 'failures'] })
      setCompletedRunId(activeRunId)
      setIsStuck(false)
      localStorage.removeItem(ACTIVE_RUN_STORAGE_KEY)
      localStorage.removeItem(EXPECTED_METHODS_STORAGE_KEY)
      localStorage.removeItem(STARTED_AT_STORAGE_KEY)
    }, 0)
  }

  const startTests = useCallback(async (methods: string[]) => {
    const result = await runTests.mutateAsync(methods)
    const now = Date.now()
    setActiveRunId(result.runId)
    setExpectedMethods(methods.length)
    setStartedAt(now)
    setCompletedRunId(null)
    setIsStuck(false)
    localStorage.setItem(ACTIVE_RUN_STORAGE_KEY, result.runId)
    localStorage.setItem(EXPECTED_METHODS_STORAGE_KEY, String(methods.length))
    localStorage.setItem(STARTED_AT_STORAGE_KEY, String(now))
    return result
  }, [runTests])

  const reset = useCallback(() => {
    setActiveRunId(null)
    setCompletedRunId(null)
    setStartedAt(null)
    setIsStuck(false)
    localStorage.removeItem(ACTIVE_RUN_STORAGE_KEY)
    localStorage.removeItem(EXPECTED_METHODS_STORAGE_KEY)
    localStorage.removeItem(STARTED_AT_STORAGE_KEY)
  }, [])

  const cancelAndReset = useCallback(async () => {
    if (activeRunId) {
      try {
        await cancelTests.mutateAsync(activeRunId)
      } catch (e) {
        // Even if cancel fails, reset local state
        console.warn('Cancel request failed, resetting local state:', e)
      }
    }
    reset()
    queryClient.invalidateQueries({ queryKey: ['testing', 'dashboard'] })
    queryClient.invalidateQueries({ queryKey: ['testing', 'failures'] })
  }, [activeRunId, cancelTests, reset, queryClient])

  // isRunning is true if we have an active run that:
  // 1. Status explicitly says "running", OR
  // 2. We're still waiting for status data (shouldPoll is true but no data yet)
  // AND we haven't marked it as completed
  const isRunning = shouldPoll && (status.data?.status === 'running' || status.isLoading || !status.data) && !isCompleted

  return {
    startTests,
    reset,
    cancelAndReset,
    isStarting: runTests.isPending,
    isCancelling: cancelTests.isPending,
    isRunning,
    isStuck,
    isCompleted,
    activeRunId,
    runningCount: status.data?.runningCount ?? 0,
    error: runTests.error || status.error || cancelTests.error,
  }
}
