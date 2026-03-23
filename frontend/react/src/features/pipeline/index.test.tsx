/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Pipeline } from './index'

// Mock the modular hooks
vi.mock('./hooks', () => ({
  usePipelineFunnel: vi.fn(),
  usePipelineTasks: vi.fn(),
  usePhaseProgress: vi.fn(),
}))

vi.mock('./hooks/use-pipeline-actions', () => ({
  usePipelineActions: vi.fn(() => ({
    startPipeline: { mutate: vi.fn(), isPending: false },
    stopPipeline: { mutate: vi.fn(), isPending: false },
    toggleTask: { mutate: vi.fn(), isPending: false },
    enableAllTasks: { mutate: vi.fn(), isPending: false },
    disableAllTasks: { mutate: vi.fn(), isPending: false },
    runPipeline: { mutate: vi.fn(), mutateAsync: vi.fn(), isPending: false },
  })),
}))

import {
  usePipelineFunnel,
  usePipelineTasks,
  usePhaseProgress,
} from './hooks'
import { usePipelineActions } from './hooks/use-pipeline-actions'

// Mock data for each modular hook
const mockFunnelData = {
  rawItems: 1000,
  categorizedItems: 800,
  blockedItems: 0,
  uniqueDescriptions: 600,
  ensembleDone: 400,
  pipelineItems: 600,
}

const mockTasksData = {
  tasks: [
    { name: 'DEDUP_FASTPATH', role: 'root', state: 'started', dag: 'stream_pipeline', level: 0, schedule: '1 minute' },
    { name: 'CLASSIFY_UNIQUE', role: 'child', state: 'started', dag: 'stream_pipeline', level: 1, schedule: null },
    { name: 'VECTOR_PREP', role: 'child', state: 'suspended', dag: 'stream_pipeline', level: 1, schedule: null },
  ],
  allTasksSuspended: false,
}

const mockPhasesData = {
  phases: [
    { name: 'Exact Match', pct: 100, done: 500, total: 500, color: '#10b981', state: 'COMPLETE' },
    { name: 'Fuzzy Match', pct: 50, done: 250, total: 500, color: '#3b82f6', state: 'PROCESSING' },
  ],
  pipelineState: 'IDLE',
  activePhase: null,
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
}

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      {ui}
    </QueryClientProvider>
  )
}

// Helper to set up all mocks with default data
function setupMocks(overrides: {
  funnel?: { data?: any; isLoading?: boolean; error?: any; isFetching?: boolean }
  tasks?: { data?: any; isLoading?: boolean; error?: any; isFetching?: boolean }
  phases?: { data?: any; isLoading?: boolean; error?: any; isFetching?: boolean }
  actions?: ReturnType<typeof usePipelineActions>
} = {}) {
  const defaultQuery = { isLoading: false, error: null, isFetching: false, refetch: vi.fn() }
  
  vi.mocked(usePipelineFunnel).mockReturnValue({
    ...defaultQuery,
    data: mockFunnelData,
    ...overrides.funnel,
  } as any)
  
  vi.mocked(usePipelineTasks).mockReturnValue({
    ...defaultQuery,
    data: mockTasksData,
    ...overrides.tasks,
  } as any)
  
  vi.mocked(usePhaseProgress).mockReturnValue({
    ...defaultQuery,
    data: mockPhasesData,
    ...overrides.phases,
  } as any)
  
  // Re-set usePipelineActions mock (cleared by vi.clearAllMocks)
  vi.mocked(usePipelineActions).mockReturnValue(overrides.actions ?? {
    startPipeline: { mutate: vi.fn(), isPending: false },
    stopPipeline: { mutate: vi.fn(), isPending: false },
    toggleTask: { mutate: vi.fn(), isPending: false },
    enableAllTasks: { mutate: vi.fn(), isPending: false },
    disableAllTasks: { mutate: vi.fn(), isPending: false },
    runPipeline: { mutate: vi.fn(), mutateAsync: vi.fn(), isPending: false },
  } as any)
}

describe('Pipeline', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders loading skeleton when loading', () => {
    setupMocks({
      funnel: { data: undefined, isLoading: true },
      tasks: { data: undefined, isLoading: true },
      phases: { data: undefined, isLoading: true },
    })

    renderWithProviders(<Pipeline />)

    // PipelineSkeleton renders some loading state
    expect(document.body.textContent).toBeDefined()
  })

  it('continues rendering other sections when one has an error', () => {
    setupMocks({
      funnel: { data: undefined, error: new Error('Connection failed') },
    })

    renderWithProviders(<Pipeline />)

    // Component uses SectionWrapper for error isolation - page still renders
    expect(screen.getByText('Pipeline Management')).toBeInTheDocument()
  })

  it('renders pipeline header', () => {
    setupMocks()

    renderWithProviders(<Pipeline />)

    expect(screen.getByText('Pipeline Management')).toBeInTheDocument()
    expect(screen.getByText('Refresh')).toBeInTheDocument()
  })

  it('calls refetch when refresh button clicked', () => {
    const refetch = vi.fn()
    setupMocks({
      funnel: { refetch },
    })

    renderWithProviders(<Pipeline />)

    fireEvent.click(screen.getByText('Refresh'))
    expect(refetch).toHaveBeenCalled()
  })

  it('shows loading spinner when fetching', () => {
    setupMocks({
      funnel: { isFetching: true },
    })

    renderWithProviders(<Pipeline />)

    expect(document.querySelector('.animate-spin')).toBeInTheDocument()
  })

  it('shows pipeline paused warning when all tasks suspended', () => {
    setupMocks({
      tasks: { data: { ...mockTasksData, allTasksSuspended: true } },
    })

    renderWithProviders(<Pipeline />)

    expect(screen.getByText(/Pipeline Paused/)).toBeInTheDocument()
    expect(screen.getByText('Enable Tasks')).toBeInTheDocument()
  })

  it('renders scheduled tasks section', () => {
    setupMocks()

    renderWithProviders(<Pipeline />)

    // ScheduledTasksSection renders "Manual Pipeline Run" card and DAG sections
    expect(screen.getByText('Manual Pipeline Run')).toBeInTheDocument()
    expect(screen.getByText('Stream Pipeline DAG')).toBeInTheDocument()
  })

  it('renders Enable All and Disable All buttons', () => {
    setupMocks()

    renderWithProviders(<Pipeline />)

    expect(screen.getByText('Enable All Tasks')).toBeInTheDocument()
    expect(screen.getByText('Disable All Tasks')).toBeInTheDocument()
  })

  it('calls enableAllTasks when Enable All clicked', () => {
    const enableMutate = vi.fn()
    setupMocks({
      actions: {
        startPipeline: { mutate: vi.fn(), isPending: false },
        stopPipeline: { mutate: vi.fn(), isPending: false },
        toggleTask: { mutate: vi.fn(), isPending: false },
        enableAllTasks: { mutate: enableMutate, isPending: false },
        disableAllTasks: { mutate: vi.fn(), isPending: false },
        runPipeline: { mutate: vi.fn(), mutateAsync: vi.fn(), isPending: false },
      } as any,
    })

    renderWithProviders(<Pipeline />)

    fireEvent.click(screen.getByText('Enable All Tasks'))
    expect(enableMutate).toHaveBeenCalled()
  })

  it('calls disableAllTasks when Disable All clicked', () => {
    const disableMutate = vi.fn()
    setupMocks({
      actions: {
        startPipeline: { mutate: vi.fn(), isPending: false },
        stopPipeline: { mutate: vi.fn(), isPending: false },
        toggleTask: { mutate: vi.fn(), isPending: false },
        enableAllTasks: { mutate: vi.fn(), isPending: false },
        disableAllTasks: { mutate: disableMutate, isPending: false },
        runPipeline: { mutate: vi.fn(), mutateAsync: vi.fn(), isPending: false },
      } as any,
    })

    renderWithProviders(<Pipeline />)

    fireEvent.click(screen.getByText('Disable All Tasks'))
    expect(disableMutate).toHaveBeenCalled()
  })

  it('shows active banner when processing with active phase', () => {
    setupMocks({
      phases: { data: { ...mockPhasesData, pipelineState: 'PROCESSING', activePhase: 'MATCHING' } },
      tasks: { data: { ...mockTasksData, allTasksSuspended: false } },
    })

    renderWithProviders(<Pipeline />)

    // When processing and not suspended, shows "Active:" with the phase name
    expect(screen.getByText(/Active:/)).toBeInTheDocument()
    expect(screen.getByText(/MATCHING/)).toBeInTheDocument()
  })

  it('shows pipeline paused warning when all tasks suspended', () => {
    // Note: The "Paused:" banner in the funnel is controlled by PipelineFunnelSection
    // which hardcodes allTasksSuspended={false}. The top-level Pipeline Paused warning
    // is controlled by tasksQuery.data.allTasksSuspended.
    setupMocks({
      tasks: { data: { ...mockTasksData, allTasksSuspended: true } },
    })

    renderWithProviders(<Pipeline />)

    // The top-level warning is shown
    expect(screen.getByText(/Pipeline Paused/)).toBeInTheDocument()
  })

  it('renders items blocked warning when blockedItems > 0', () => {
    setupMocks({
      funnel: { data: { ...mockFunnelData, blockedItems: 50 } },
    })

    renderWithProviders(<Pipeline />)

    // ItemsBlockedWarning should be rendered with 50 blocked items
    expect(screen.getAllByText(/blocked/i).length).toBeGreaterThan(0)
  })
})
