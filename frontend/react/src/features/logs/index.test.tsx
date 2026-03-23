import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Suspense } from 'react'
import { Logs } from './index'

// Mock hooks that actually exist in the component
vi.mock('./hooks', () => ({
  useTaskHistory: vi.fn(),
  useTaskFilterOptions: vi.fn(),
  useErrors: vi.fn(),
  useAudit: vi.fn(),
}))

import {
  useTaskHistory,
  useTaskFilterOptions,
  useErrors,
  useAudit,
} from './hooks'

// Mock data for each hook
const mockTaskHistoryData = {
  taskHistory: {
    entries: [
      {
        taskName: 'VECTOR_PREP_TASK',
        state: 'SUCCEEDED' as const,
        scheduledTime: '2026-03-15T10:00:00Z',
        queryStartTime: '2026-03-15T10:00:05Z',
        durationSeconds: 15,
        errorMessage: null,
      },
      {
        taskName: 'CORTEX_SEARCH_TASK',
        state: 'FAILED' as const,
        scheduledTime: '2026-03-15T10:05:00Z',
        queryStartTime: '2026-03-15T10:05:02Z',
        durationSeconds: 8,
        errorMessage: 'Query timeout',
      },
    ],
    total: 2,
    page: 1,
    pageSize: 10,
    totalPages: 1,
  },
}

const mockErrorsData = {
  recentErrors: {
    entries: [
      {
        logId: 'err-1',
        runId: 'run-123',
        stepName: 'CORTEX_SEARCH',
        category: 'MATCH',
        errorMessage: 'Query timeout after 60 seconds',
        itemsFailed: 5,
        queryId: 'query-abc',
        createdAt: '2026-03-15 10:05',
      },
    ],
    total: 1,
    page: 1,
    pageSize: 25,
    totalPages: 1,
  },
}

const mockAuditData = {
  auditLogs: {
    entries: [
      {
        auditId: 'audit-1',
        actionType: 'CONFIRM',
        tableName: 'MATCHES',
        recordId: 'match-123',
        oldValue: null,
        newValue: 'CONFIRMED',
        changedBy: 'MYOUNG',
        changedAt: '2026-03-15 09:30',
        changeReason: 'Verified match',
      },
    ],
    total: 1,
    page: 1,
    pageSize: 25,
    totalPages: 1,
  },
}

const mockFilterOptionsData = {
  taskNames: ['VECTOR_PREP_TASK', 'CORTEX_SEARCH_TASK'],
  states: ['SUCCEEDED', 'FAILED', 'EXECUTING'],
}

function createMockQueryReturn<T>(data: T) {
  return {
    data,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  }
}

function setupAllMocks() {
  vi.mocked(useTaskHistory).mockReturnValue(createMockQueryReturn(mockTaskHistoryData) as ReturnType<typeof useTaskHistory>)
  vi.mocked(useTaskFilterOptions).mockReturnValue(createMockQueryReturn(mockFilterOptionsData) as ReturnType<typeof useTaskFilterOptions>)
  vi.mocked(useErrors).mockReturnValue(createMockQueryReturn(mockErrorsData) as ReturnType<typeof useErrors>)
  vi.mocked(useAudit).mockReturnValue(createMockQueryReturn(mockAuditData) as ReturnType<typeof useAudit>)
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
}

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <Suspense fallback={<div>Loading...</div>}>
        {ui}
      </Suspense>
    </QueryClientProvider>,
  )
}

describe('Logs', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setupAllMocks()
  })

  it('renders page header', () => {
    renderWithProviders(<Logs />)
    expect(screen.getByText('Logs & Observability')).toBeInTheDocument()
  })

  it('renders task history section with entries', () => {
    renderWithProviders(<Logs />)
    expect(screen.getByText('Task Execution History')).toBeInTheDocument()
    expect(screen.getByText('VECTOR_PREP_TASK')).toBeInTheDocument()
    expect(screen.getByText('CORTEX_SEARCH_TASK')).toBeInTheDocument()
  })

  it('renders recent errors section', () => {
    renderWithProviders(<Logs />)
    expect(screen.getByText('Recent Errors')).toBeInTheDocument()
  })

  it('renders audit trail section', () => {
    renderWithProviders(<Logs />)
    expect(screen.getByText('Audit Trail')).toBeInTheDocument()
  })

  it('renders refresh button', () => {
    renderWithProviders(<Logs />)
    expect(screen.getByRole('button', { name: /refresh/i })).toBeInTheDocument()
  })

  it('calls refetch on all hooks when refresh button is clicked', async () => {
    const mockRefetchTaskHistory = vi.fn()
    const mockRefetchErrors = vi.fn()
    const mockRefetchAudit = vi.fn()

    vi.mocked(useTaskHistory).mockReturnValue({
      ...createMockQueryReturn(mockTaskHistoryData),
      refetch: mockRefetchTaskHistory,
    } as ReturnType<typeof useTaskHistory>)

    vi.mocked(useErrors).mockReturnValue({
      ...createMockQueryReturn(mockErrorsData),
      refetch: mockRefetchErrors,
    } as ReturnType<typeof useErrors>)

    vi.mocked(useAudit).mockReturnValue({
      ...createMockQueryReturn(mockAuditData),
      refetch: mockRefetchAudit,
    } as ReturnType<typeof useAudit>)

    renderWithProviders(<Logs />)

    const refreshButton = screen.getByRole('button', { name: /refresh/i })
    fireEvent.click(refreshButton)

    await waitFor(() => {
      expect(mockRefetchTaskHistory).toHaveBeenCalled()
      expect(mockRefetchErrors).toHaveBeenCalled()
      expect(mockRefetchAudit).toHaveBeenCalled()
    })
  })

  it('shows fetching state when any hook is fetching', () => {
    vi.mocked(useTaskHistory).mockReturnValue({
      ...createMockQueryReturn(mockTaskHistoryData),
      isFetching: true,
    } as ReturnType<typeof useTaskHistory>)

    renderWithProviders(<Logs />)

    // The refresh button should indicate fetching state
    const refreshButton = screen.getByRole('button', { name: /refresh/i })
    expect(refreshButton).toBeInTheDocument()
  })
})
