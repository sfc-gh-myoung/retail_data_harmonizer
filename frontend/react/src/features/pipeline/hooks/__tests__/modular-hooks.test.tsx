import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode } from 'react'
import { usePipelineFunnel } from '../use-pipeline-funnel'
import { usePhaseProgress } from '../use-phase-progress'
import { usePipelineTasks } from '../use-pipeline-tasks'
import { usePipelineActions } from '../use-pipeline-actions'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
  postApi: vi.fn(),
}))

import { fetchApi, postApi } from '@/lib/api'

// Mock API responses - these are the TRANSFORMED outputs (camelCase)
// since fetchApi is mocked and schema.parse doesn't run
const mockFunnelResponse = {
  rawItems: 1000,
  categorizedItems: 800,
  blockedItems: 50,
  uniqueDescriptions: 600,
  pipelineItems: 550,
  ensembleDone: 400,
}

const mockPhasesResponse = {
  phases: [
    { name: 'DEDUP', done: 100, total: 100, pct: 100, state: 'COMPLETE', color: '#22c55e' },
    { name: 'CLASSIFY', done: 50, total: 100, pct: 50, state: 'PROCESSING', color: '#3b82f6' },
  ],
  pipelineState: 'PROCESSING',
  activePhase: 'CLASSIFY',
  ensembleWaitingFor: null,
  batchId: 'batch-123',
}

const mockTasksResponse = {
  tasks: [
    { name: 'DEDUP_FASTPATH', state: 'started', schedule: '*/5 * * * *', role: 'root', level: 0, dag: 'stream_pipeline' },
    { name: 'CLASSIFY_UNIQUE', state: 'suspended', schedule: null, role: 'child', level: 1, dag: 'stream_pipeline' },
  ],
  allTasksSuspended: false,
  pendingCount: 150,
  isRunning: true,
}

const mockActionResponse = {
  success: true,
  message: 'Action completed',
  jobId: 'new-job-123',
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

describe('usePipelineFunnel', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches funnel data from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFunnelResponse)

    const { result } = renderHook(() => usePipelineFunnel(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/pipeline/funnel', expect.any(Object))
  })

  it('returns funnel data with correct structure', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFunnelResponse)

    const { result } = renderHook(() => usePipelineFunnel(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.rawItems).toBe(1000)
    expect(result.current.data?.categorizedItems).toBe(800)
    expect(result.current.data?.blockedItems).toBe(50)
    expect(result.current.data?.uniqueDescriptions).toBe(600)
    expect(result.current.data?.pipelineItems).toBe(550)
    expect(result.current.data?.ensembleDone).toBe(400)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFunnelResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => usePipelineFunnel(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['pipeline', 'funnel'])
    expect(cachedData).toBeDefined()
  })

})

describe('usePhaseProgress', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches phases from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockPhasesResponse)

    const { result } = renderHook(() => usePhaseProgress(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/pipeline/phases', expect.any(Object))
  })

  it('transforms response correctly', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockPhasesResponse)

    const { result } = renderHook(() => usePhaseProgress(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.pipelineState).toBe('PROCESSING')
    expect(result.current.data?.activePhase).toBe('CLASSIFY')
    expect(result.current.data?.batchId).toBe('batch-123')
    expect(result.current.data?.phases).toHaveLength(2)
    expect(result.current.data?.phases[0].name).toBe('DEDUP')
  })
})

describe('usePipelineTasks', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches tasks from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTasksResponse)

    const { result } = renderHook(() => usePipelineTasks(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/pipeline/tasks', expect.any(Object))
  })

  it('transforms response correctly', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockTasksResponse)

    const { result } = renderHook(() => usePipelineTasks(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.allTasksSuspended).toBe(false)
    expect(result.current.data?.pendingCount).toBe(150)
    expect(result.current.data?.isRunning).toBe(true)
    expect(result.current.data?.tasks).toHaveLength(2)
    expect(result.current.data?.tasks[0].name).toBe('DEDUP_FASTPATH')
  })
})

describe('usePipelineActions', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('runPipeline', () => {
    it('calls run endpoint', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const queryClient = createTestQueryClient()
      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(queryClient),
      })

      await act(async () => {
        result.current.runPipeline.mutate()
      })

      await waitFor(() => expect(result.current.runPipeline.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith('/v2/pipeline/run', {}, expect.any(Object))
    })

    it('invalidates queries on success', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const queryClient = createTestQueryClient()
      const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(queryClient),
      })

      await act(async () => {
        result.current.runPipeline.mutate()
      })

      await waitFor(() => expect(result.current.runPipeline.isSuccess).toBe(true))

      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['pipeline'] })
    })
  })

  describe('stopPipeline', () => {
    it('calls stop endpoint with job ID', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(),
      })

      await act(async () => {
        result.current.stopPipeline.mutate('job-123')
      })

      await waitFor(() => expect(result.current.stopPipeline.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith(
        '/v2/pipeline/stop',
        { job_id: 'job-123' },
        expect.any(Object)
      )
    })
  })

  describe('toggleTask', () => {
    it('calls toggle endpoint with task name and action', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(),
      })

      await act(async () => {
        result.current.toggleTask.mutate({ taskName: 'DEDUP_FASTPATH', action: 'suspend' })
      })

      await waitFor(() => expect(result.current.toggleTask.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith(
        '/v2/pipeline/toggle',
        { task_name: 'DEDUP_FASTPATH', action: 'suspend' },
        expect.any(Object)
      )
    })
  })

  describe('enableAllTasks', () => {
    it('calls enable-all endpoint', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const queryClient = createTestQueryClient()
      const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(queryClient),
      })

      await act(async () => {
        result.current.enableAllTasks.mutate()
      })

      await waitFor(() => expect(result.current.enableAllTasks.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith('/v2/pipeline/tasks/enable-all', {}, expect.any(Object))
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['pipeline'] })
    })
  })

  describe('disableAllTasks', () => {
    it('calls disable-all endpoint', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(),
      })

      await act(async () => {
        result.current.disableAllTasks.mutate()
      })

      await waitFor(() => expect(result.current.disableAllTasks.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith('/v2/pipeline/tasks/disable-all', {}, expect.any(Object))
    })
  })

  describe('resetPipeline', () => {
    it('calls reset endpoint', async () => {
      vi.mocked(postApi).mockResolvedValueOnce(mockActionResponse)

      const queryClient = createTestQueryClient()
      const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

      const { result } = renderHook(() => usePipelineActions(), {
        wrapper: createWrapper(queryClient),
      })

      await act(async () => {
        result.current.resetPipeline.mutate()
      })

      await waitFor(() => expect(result.current.resetPipeline.isSuccess).toBe(true))

      expect(postApi).toHaveBeenCalledWith('/v2/pipeline/reset', {}, expect.any(Object))
      expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['pipeline'] })
    })
  })
})
