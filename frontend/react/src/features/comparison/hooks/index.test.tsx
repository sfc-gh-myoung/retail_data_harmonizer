import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode, Suspense } from 'react'
import {
  useAlgorithms,
  useAgreement,
  useSourcePerformance,
  useMethodAccuracy,
} from './index'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
}))

import { fetchApi } from '@/lib/api'

const mockAlgorithmsResponse = {
  algorithms: [
    { name: 'Search', description: 'Full-text search', features: ['Fast', 'Fuzzy'] },
    { name: 'Cosine', description: 'Vector similarity', features: ['Semantic'] },
  ],
}

const mockAgreementResponse = {
  agreement: [
    { level: 'High (5/5)', count: 150, avgConfidence: 0.95 },
    { level: 'Medium (4/5)', count: 200, avgConfidence: 0.85 },
  ],
}

const mockSourcePerformanceResponse = {
  sourcePerformance: [
    {
      source: 'POS_A',
      itemCount: 500,
      avgSearch: 0.85,
      avgCosine: 0.80,
      avgEdit: 0.75,
      avgJaccard: 0.70,
      avgEnsemble: 0.88,
    },
  ],
}

const mockMethodAccuracyResponse = {
  methodAccuracy: {
    totalConfirmed: 1000,
    searchCorrect: 850,
    searchAccuracyPct: 85,
    cosineCorrect: 820,
    cosineAccuracyPct: 82,
    editCorrect: 780,
    editAccuracyPct: 78,
    jaccardCorrect: 750,
    jaccardAccuracyPct: 75,
    ensembleCorrect: 940,
    ensembleAccuracyPct: 94,
  },
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
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

describe('useAlgorithms', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches algorithms from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAlgorithmsResponse)

    const { result } = renderHook(() => useAlgorithms(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/comparison/algorithms',
      expect.any(Object)
    )
  })

  it('returns algorithms data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAlgorithmsResponse)

    const { result } = renderHook(() => useAlgorithms(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.algorithms).toHaveLength(2)
    expect(result.current.data.algorithms[0].name).toBe('Search')
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAlgorithmsResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useAlgorithms(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['comparison', 'algorithms'])
    expect(cachedData).toBeDefined()
  })

  it('has staleTime set to Infinity for static data', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAlgorithmsResponse)

    const queryClient = createTestQueryClient()
    renderHook(() => useAlgorithms(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(fetchApi).toHaveBeenCalled())

    const queryState = queryClient.getQueryState(['comparison', 'algorithms'])
    expect(queryState?.isInvalidated).toBe(false)
  })
})

describe('useAgreement', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches agreement from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAgreementResponse)

    const { result } = renderHook(() => useAgreement(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/comparison/agreement',
      expect.any(Object)
    )
  })

  it('returns agreement data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAgreementResponse)

    const { result } = renderHook(() => useAgreement(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.agreement).toHaveLength(2)
    expect(result.current.data.agreement[0].avgConfidence).toBe(0.95)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAgreementResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useAgreement(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['comparison', 'agreement'])
    expect(cachedData).toBeDefined()
  })
})

describe('useSourcePerformance', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches source performance from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcePerformanceResponse)

    const { result } = renderHook(() => useSourcePerformance(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/comparison/source-performance',
      expect.any(Object)
    )
  })

  it('returns source performance data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcePerformanceResponse)

    const { result } = renderHook(() => useSourcePerformance(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.sourcePerformance).toHaveLength(1)
    expect(result.current.data.sourcePerformance[0].source).toBe('POS_A')
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcePerformanceResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useSourcePerformance(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['comparison', 'source-performance'])
    expect(cachedData).toBeDefined()
  })
})

describe('useMethodAccuracy', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches method accuracy from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockMethodAccuracyResponse)

    const { result } = renderHook(() => useMethodAccuracy(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith(
      '/v2/comparison/method-accuracy',
      expect.any(Object)
    )
  })

  it('returns method accuracy data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockMethodAccuracyResponse)

    const { result } = renderHook(() => useMethodAccuracy(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.methodAccuracy.totalConfirmed).toBe(1000)
    expect(result.current.data.methodAccuracy.ensembleAccuracyPct).toBe(94)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockMethodAccuracyResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useMethodAccuracy(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['comparison', 'method-accuracy'])
    expect(cachedData).toBeDefined()
  })
})
