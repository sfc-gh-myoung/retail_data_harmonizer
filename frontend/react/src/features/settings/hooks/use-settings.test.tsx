import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode } from 'react'
import {
  useSettings,
  useUpdateSettings,
  useResetSettings,
  useReEvaluate,
  useResetPipeline,
} from './use-settings'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
  patchApi: vi.fn(),
  postApi: vi.fn(),
}))

import { fetchApi, patchApi, postApi } from '@/lib/api'

const mockSettings = {
  weights: {
    cortexSearch: 0.3,
    cosine: 0.25,
    editDistance: 0.25,
    jaccard: 0.2,
  },
  thresholds: {
    autoAccept: 0.95,
    reject: 0.3,
    reviewMin: 0.5,
    reviewMax: 0.9,
  },
  performance: {
    batchSize: 100,
    parallelism: 4,
    cacheEnabled: true,
  },
  cost: {
    cortexCostPerCall: 0.002,
    targetROI: 5,
    maxDailyCost: 100,
  },
  automation: {
    autoAcceptEnabled: true,
    autoRejectEnabled: false,
    minAgreementLevel: 3,
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

describe('useSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches settings from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSettings)

    const { result } = renderHook(() => useSettings(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/settings', expect.any(Object, expect.any(Object)))
  })

  it('returns settings data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSettings)

    const { result } = renderHook(() => useSettings(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.weights.cortexSearch).toBe(0.3)
    expect(result.current.data?.thresholds.autoAccept).toBe(0.95)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSettings)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useSettings(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['settings'])
    expect(cachedData).toEqual(mockSettings)
  })
})

describe('useUpdateSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls PATCH endpoint with partial settings', async () => {
    vi.mocked(patchApi).mockResolvedValueOnce(mockSettings)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useUpdateSettings(), {
      wrapper: createWrapper(queryClient),
    })

    const partialUpdate = {
      weights: { ...mockSettings.weights, cortexSearch: 0.4 },
    }

    await act(async () => {
      result.current.mutate(partialUpdate)
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(patchApi).toHaveBeenCalledWith('/v2/settings', partialUpdate, expect.any(Object))
  })

  it('invalidates settings query on success', async () => {
    vi.mocked(patchApi).mockResolvedValueOnce(mockSettings)

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useUpdateSettings(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ weights: mockSettings.weights })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['settings'] })
  })
})

describe('useResetSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls reset endpoint', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useResetSettings(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith('/settings/reset', {}, expect.any(Object))
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['settings'] })
  })
})

describe('useReEvaluate', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls re-evaluate endpoint', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useReEvaluate(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith('/v2/settings/re-evaluate', {}, expect.any(Object))
  })

  it('invalidates matches and dashboard queries on success', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useReEvaluate(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['matches'] })
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['dashboard'] })
  })
})

describe('useResetPipeline', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls pipeline reset endpoint', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true, message: 'Pipeline reset' })

    const { result } = renderHook(() => useResetPipeline(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith('/v2/pipeline/reset', {}, expect.any(Object))
  })

  it('invalidates matches, dashboard, and pipeline queries on success', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true, message: 'Pipeline reset' })

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useResetPipeline(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['matches'] })
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['dashboard'] })
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['pipeline'] })
  })

  it('handles error state', async () => {
    vi.mocked(postApi).mockRejectedValueOnce(new Error('Reset failed'))

    const { result } = renderHook(() => useResetPipeline(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isError).toBe(true))
  })

  it('returns success response data', async () => {
    const mockResponse = { success: true, message: 'Pipeline has been reset successfully' }
    vi.mocked(postApi).mockResolvedValueOnce(mockResponse)

    const { result } = renderHook(() => useResetPipeline(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate()
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data).toEqual(mockResponse)
  })
})
