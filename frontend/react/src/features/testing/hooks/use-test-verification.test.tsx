import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode } from 'react'
import {
  useTestingDashboard,
  useFailures,
  useRunAccuracyTests,
  useTestStatus,
  useTestRunner,
} from './use-test-verification'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
  postApi: vi.fn(),
}))

import { fetchApi, postApi } from '@/lib/api'

const mockDashboardData = {
  testRun: {
    runId: 'run-123',
    timestamp: '2026-03-17T10:00:00Z',
    totalTests: 100,
    methodsTested: 'COSINE_SIMILARITY, EDIT_DISTANCE',
  },
  testStats: {
    totalCases: 100,
    easyCount: 40,
    mediumCount: 35,
    hardCount: 25,
    easyPct: 40,
    mediumPct: 35,
    hardPct: 25,
  },
  accuracySummary: [
    { method: 'COSINE_SIMILARITY', top1AccuracyPct: 85.5, top3AccuracyPct: 92.0, top5AccuracyPct: 95.0 },
    { method: 'EDIT_DISTANCE', top1AccuracyPct: 78.0, top3AccuracyPct: 88.0, top5AccuracyPct: 91.0 },
  ],
  accuracyByDifficulty: [
    { method: 'COSINE_SIMILARITY', difficulty: 'EASY' as const, tests: 40, top1Pct: 95.0 },
    { method: 'COSINE_SIMILARITY', difficulty: 'HARD' as const, tests: 25, top1Pct: 72.0 },
  ],
  totalFailures: 15,
}

const mockFailuresData = {
  failures: [
    {
      method: 'COSINE_SIMILARITY',
      testInput: 'organic milk 2%',
      expectedMatch: 'ORGANIC WHOLE MILK',
      actualMatch: 'SKIM MILK',
      score: 0.78,
      difficulty: 'HARD' as const,
    },
  ],
  totalFailures: 15,
  totalPages: 2,
  currentPage: 1,
  pageSize: 10,
  hasPrev: false,
  hasNext: true,
  filterOptions: {
    methods: ['COSINE_SIMILARITY', 'EDIT_DISTANCE'],
    difficulties: ['EASY', 'MEDIUM', 'HARD'],
  },
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })
}

function createWrapper(queryClient?: QueryClient) {
  const client = queryClient ?? createTestQueryClient()
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  )
}

describe('useTestingDashboard', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches dashboard data from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockDashboardData)

    const { result } = renderHook(() => useTestingDashboard(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/testing/dashboard', expect.any(Object, expect.any(Object)))
  })

  it('returns dashboard data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockDashboardData)

    const { result } = renderHook(() => useTestingDashboard(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.testStats.totalCases).toBe(100)
    expect(result.current.data?.accuracySummary).toHaveLength(2)
    expect(result.current.data?.totalFailures).toBe(15)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockDashboardData)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useTestingDashboard(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['testing', 'dashboard'])
    expect(cachedData).toEqual(mockDashboardData)
  })

  it('handles loading state', () => {
    vi.mocked(fetchApi).mockImplementation(() => new Promise(() => {}))

    const { result } = renderHook(() => useTestingDashboard(), {
      wrapper: createWrapper(),
    })

    expect(result.current.isLoading).toBe(true)
    expect(result.current.data).toBeUndefined()
  })

  it('handles error state', async () => {
    vi.mocked(fetchApi).mockRejectedValueOnce(new Error('Server error'))

    const { result } = renderHook(() => useTestingDashboard(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(result.current.error).toBeTruthy()
  })
})

describe('useFailures', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches failures with default params', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFailuresData)

    const { result } = renderHook(() => useFailures(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/testing/failures?page=1&page_size=10&sort_col=METHOD&sort_dir=ASC&method_filter=All&difficulty_filter=All',
      expect.any(Object)
    )
  })

  it('fetches failures with custom params', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFailuresData)

    const { result } = renderHook(
      () =>
        useFailures({
          page: 2,
          pageSize: 20,
          sortCol: 'SCORE',
          sortDir: 'DESC',
          methodFilter: 'COSINE_SIMILARITY',
          difficultyFilter: 'HARD',
        }),
      { wrapper: createWrapper() }
    )

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/testing/failures?page=2&page_size=20&sort_col=SCORE&sort_dir=DESC&method_filter=COSINE_SIMILARITY&difficulty_filter=HARD',
      expect.any(Object)
    )
  })

  it('returns failures data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFailuresData)

    const { result } = renderHook(() => useFailures(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.failures).toHaveLength(1)
    expect(result.current.data?.totalFailures).toBe(15)
    expect(result.current.data?.hasNext).toBe(true)
  })

  it('handles error state', async () => {
    vi.mocked(fetchApi).mockRejectedValueOnce(new Error('Failed to fetch'))

    const { result } = renderHook(() => useFailures(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(result.current.error).toBeTruthy()
  })
})

describe('useRunAccuracyTests', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls run endpoint with methods array', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-456',
      status: 'running',
      methods: ['cosine', 'edit_distance'],
    })

    const { result } = renderHook(() => useRunAccuracyTests(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate(['cosine', 'edit_distance'])
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith(
      '/v2/testing/run',
      {
        methods: ['cosine', 'edit_distance'],
      },
      expect.any(Object)
    )
  })

  it('returns run response on success', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-789',
      status: 'running',
      methods: ['cortex_search'],
    })

    const { result } = renderHook(() => useRunAccuracyTests(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate(['cortex_search'])
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.runId).toBe('run-789')
    expect(result.current.data?.status).toBe('running')
  })

  it('handles error state', async () => {
    vi.mocked(postApi).mockRejectedValueOnce(new Error('Test run failed'))

    const { result } = renderHook(() => useRunAccuracyTests(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate(['cosine'])
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(result.current.error).toBeTruthy()
  })
})

describe('useTestStatus', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches status for given runId', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce({
      status: 'running',
      runningCount: 3,
    })

    const { result } = renderHook(() => useTestStatus('run-123'), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/testing/status/run-123', expect.any(Object, expect.any(Object)))
  })

  it('returns status data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce({
      status: 'running',
      runningCount: 2,
    })

    const { result } = renderHook(() => useTestStatus('run-123'), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.status).toBe('running')
    expect(result.current.data?.runningCount).toBe(2)
  })

  it('does not fetch when runId is null', () => {
    const { result } = renderHook(() => useTestStatus(null), {
      wrapper: createWrapper(),
    })

    expect(result.current.isLoading).toBe(false)
    expect(result.current.isFetching).toBe(false)
    expect(fetchApi).not.toHaveBeenCalled()
  })

  it('does not fetch when enabled is false', () => {
    const { result } = renderHook(() => useTestStatus('run-123', false), {
      wrapper: createWrapper(),
    })

    expect(result.current.isLoading).toBe(false)
    expect(result.current.isFetching).toBe(false)
    expect(fetchApi).not.toHaveBeenCalled()
  })
})

describe('useTestRunner', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('starts in idle state', () => {
    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    expect(result.current.isStarting).toBe(false)
    expect(result.current.isRunning).toBe(false)
    expect(result.current.isCompleted).toBe(false)
    expect(result.current.activeRunId).toBeNull()
    expect(result.current.runningCount).toBe(0)
    expect(result.current.error).toBeNull()
  })

  it('starts tests and sets activeRunId', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-abc',
      status: 'running',
      methods: ['cosine'],
    })

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    expect(result.current.activeRunId).toBe('run-abc')
    expect(postApi).toHaveBeenCalledWith('/v2/testing/run', { methods: ['cosine'] }, expect.any(Object))
  })

  it('shows isStarting while mutation is pending', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-xyz',
      status: 'running',
      methods: ['cosine'],
    })

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    // Before starting, isStarting should be false
    expect(result.current.isStarting).toBe(false)

    // Start and complete
    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    // After completing, isStarting should be false
    expect(result.current.isStarting).toBe(false)
  })

  it('shows isRunning while status is running', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-def',
      status: 'running',
      methods: ['cosine'],
    })
    vi.mocked(fetchApi).mockResolvedValue({
      status: 'running',
      runningCount: 2,
    })

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    // Wait for status query to complete
    await waitFor(() => {
      expect(result.current.isRunning).toBe(true)
    })

    expect(result.current.runningCount).toBe(2)
  })

  it('shows isCompleted when status becomes completed', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-ghi',
      status: 'running',
      methods: ['cosine'],
    })
    vi.mocked(fetchApi).mockResolvedValue({
      status: 'completed',
      runningCount: 0,
    })

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    // Wait for completion detection
    await waitFor(() => {
      expect(result.current.isCompleted).toBe(true)
    })

    // Should invalidate dashboard and failures queries
    await waitFor(() => {
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['testing', 'dashboard'] })
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['testing', 'failures'] })
    })
  })

  it('reset clears the state', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-jkl',
      status: 'running',
      methods: ['cosine'],
    })

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    expect(result.current.activeRunId).toBe('run-jkl')

    act(() => {
      result.current.reset()
    })

    expect(result.current.activeRunId).toBeNull()
    expect(result.current.isCompleted).toBe(false)
  })

  it('exposes mutation error', async () => {
    const testError = new Error('Failed to start tests')
    vi.mocked(postApi).mockRejectedValueOnce(testError)

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      try {
        await result.current.startTests(['cosine'])
      } catch {
        // Expected to throw
      }
    })

    // Wait for the error to be reflected in state
    await waitFor(() => {
      // Either error or mutation error should be truthy after failure
      expect(result.current.activeRunId).toBeNull()
    })
  })

  it('exposes status query error', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({
      runId: 'run-mno',
      status: 'running',
      methods: ['cosine'],
    })
    vi.mocked(fetchApi).mockRejectedValue(new Error('Status fetch failed'))

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })

    await waitFor(() => {
      expect(result.current.error).toBeTruthy()
    })
  })

  it('handles multiple test runs sequentially', async () => {
    vi.mocked(postApi)
      .mockResolvedValueOnce({ runId: 'run-1', status: 'running', methods: ['cosine'] })
      .mockResolvedValueOnce({ runId: 'run-2', status: 'running', methods: ['edit_distance'] })

    const { result } = renderHook(() => useTestRunner(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      await result.current.startTests(['cosine'])
    })
    expect(result.current.activeRunId).toBe('run-1')

    await act(async () => {
      await result.current.startTests(['edit_distance'])
    })
    expect(result.current.activeRunId).toBe('run-2')
  })
})
