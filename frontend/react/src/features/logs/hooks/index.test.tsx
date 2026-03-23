import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode, Suspense } from 'react'
import {
  useTaskHistory,
  useErrors,
  useAudit,
} from './index'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
}))

import { fetchApi } from '@/lib/api'

const mockTaskHistoryResponse = {
  taskHistory: {
    entries: [
      {
        taskName: 'HARMONIZER_REFRESH',
        state: 'SUCCEEDED',
        scheduledTime: '2024-01-15T10:00:00Z',
        queryStartTime: '2024-01-15T10:00:05Z',
        durationSeconds: 120,
        errorMessage: null,
      },
    ],
    total: 100,
    page: 1,
    pageSize: 10,
    totalPages: 10,
  },
}

const mockErrorsResponse = {
  recentErrors: {
    entries: [
      {
        logId: 'err-1',
        runId: 'run-1',
        stepName: 'categorization',
        category: 'VALIDATION',
        errorMessage: 'Invalid category mapping',
        itemsFailed: 5,
        queryId: 'query-123',
        createdAt: '2024-01-15T10:00:00Z',
      },
    ],
    total: 50,
    page: 1,
    pageSize: 25,
    totalPages: 2,
  },
}

const mockAuditResponse = {
  auditLogs: {
    entries: [
      {
        auditId: 'audit-1',
        actionType: 'UPDATE',
        tableName: 'MATCHES',
        recordId: 'match-123',
        oldValue: 'PENDING',
        newValue: 'CONFIRMED',
        changedBy: 'user@example.com',
        changedAt: '2024-01-15T10:00:00Z',
        changeReason: 'Manual review',
      },
    ],
    total: 200,
    page: 1,
    pageSize: 25,
    totalPages: 8,
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
    <QueryClientProvider client={client}>
      <Suspense fallback={<div>Loading...</div>}>{children}</Suspense>
    </QueryClientProvider>
  )
}

describe('useTaskHistory', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches task history from correct endpoint with default pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTaskHistoryResponse)

    const { result } = renderHook(() => useTaskHistory(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/task-history?page=1&page_size=10',
      expect.any(Object)
    )
  })

  it('fetches task history with custom pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTaskHistoryResponse)

    const { result } = renderHook(() => useTaskHistory(2, 20), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/task-history?page=2&page_size=20',
      expect.any(Object)
    )
  })

  it('returns task history data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTaskHistoryResponse)

    const { result } = renderHook(() => useTaskHistory(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.taskHistory.entries).toHaveLength(1)
    expect(result.current.data.taskHistory.totalPages).toBe(10)
  })

  it('uses correct query key with pagination params', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTaskHistoryResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useTaskHistory(3, 15), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['logs', 'task-history', 3, 15, '', ''])
    expect(cachedData).toBeDefined()
  })
})

describe('useErrors', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches errors from correct endpoint with default pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockErrorsResponse)

    const { result } = renderHook(() => useErrors(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/errors?page=1&page_size=25',
      expect.any(Object)
    )
  })

  it('fetches errors with custom pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockErrorsResponse)

    const { result } = renderHook(() => useErrors(2, 50), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/errors?page=2&page_size=50',
      expect.any(Object)
    )
  })

  it('returns errors data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockErrorsResponse)

    const { result } = renderHook(() => useErrors(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.recentErrors.entries).toHaveLength(1)
    expect(result.current.data.recentErrors.entries[0].category).toBe('VALIDATION')
  })

  it('uses correct query key with pagination params', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockErrorsResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useErrors(5, 100), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['logs', 'errors', 5, 100])
    expect(cachedData).toBeDefined()
  })
})

describe('useAudit', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches audit from correct endpoint with default pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAuditResponse)

    const { result } = renderHook(() => useAudit(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/audit?page=1&page_size=25',
      expect.any(Object)
    )
  })

  it('fetches audit with custom pagination', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAuditResponse)

    const { result } = renderHook(() => useAudit(3, 50), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/logs/audit?page=3&page_size=50',
      expect.any(Object)
    )
  })

  it('returns audit data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAuditResponse)

    const { result } = renderHook(() => useAudit(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.auditLogs.entries).toHaveLength(1)
    expect(result.current.data.auditLogs.entries[0].actionType).toBe('UPDATE')
  })

  it('uses correct query key with pagination params', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAuditResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useAudit(2, 30), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['logs', 'audit', 2, 30])
    expect(cachedData).toBeDefined()
  })
})
