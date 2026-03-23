import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode, Suspense } from 'react'
import { useKpis } from './use-kpis'
import { useSources } from './use-sources'
import { useCategories } from './use-categories'
import { useSignals } from './use-signals'
import { useCost } from './use-cost'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
}))

import { fetchApi } from '@/lib/api'

const mockKpisResponse = {
  stats: {
    totalRaw: 1000,
    totalUnique: 500,
    totalProcessed: 450,
    autoAccepted: 200,
    confirmed: 150,
    pendingReview: 80,
    rejected: 20,
    needsCategorized: 0,
    matchRate: 0.9,
    total: 450,
  },
  statuses: [{ label: 'Confirmed', count: 150, color: 'green' }],
  statusColorsMap: { CONFIRMED: 'green' },
}

const mockSourcesResponse = {
  sourceSystems: { POS_A: { CONFIRMED: 100 } },
  sourceRates: [{ source: 'POS_A', total: 150, matched: 140, rate: 0.93 }],
  sourceMax: 150,
}

const mockCategoriesResponse = {
  categoryRates: [{ category: 'Beverages', total: 200, matched: 180, rate: 0.9 }],
}

const mockSignalsResponse = {
  signalDominance: [{ method: 'search', count: 500, pct: 50, color: 'blue' }],
  signalAlignment: [{ method: 'ensemble', count: 400, pct: 40, color: 'green' }],
  agreements: [{ level: 'High', count: 200, pct: 20, color: 'green' }],
}

const mockCostResponse = {
  costData: {
    totalRuns: 10,
    totalUsd: 5.5,
    totalCredits: 55,
    totalItems: 1000,
    costPerItem: 0.0055,
    baselineWeeklyCost: 100,
    hoursSaved: 20,
    roiPercentage: 250,
    creditRateUsd: 0.1,
    manualHourlyRate: 25,
    manualMinutesPerItem: 5,
  },
  scaleData: {
    total: 1000,
    uniqueCount: 500,
    dedupRatio: 2.0,
    fastPathCount: 200,
    fastPathRate: 0.4,
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

describe('useKpis', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches kpis from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockKpisResponse)

    const { result } = renderHook(() => useKpis(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/dashboard/kpis', expect.any(Object))
  })

  it('returns kpis data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockKpisResponse)

    const { result } = renderHook(() => useKpis(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.stats.totalRaw).toBe(1000)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockKpisResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useKpis(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['dashboard', 'kpis'])
    expect(cachedData).toBeDefined()
  })
})

describe('useSources', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches sources from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcesResponse)

    const { result } = renderHook(() => useSources(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/dashboard/sources', expect.any(Object))
  })

  it('returns sources data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcesResponse)

    const { result } = renderHook(() => useSources(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.sourceMax).toBe(150)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSourcesResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useSources(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['dashboard', 'sources'])
    expect(cachedData).toBeDefined()
  })
})

describe('useCategories', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches categories from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCategoriesResponse)

    const { result } = renderHook(() => useCategories(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/dashboard/categories', expect.any(Object))
  })

  it('returns categories data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCategoriesResponse)

    const { result } = renderHook(() => useCategories(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.categoryRates).toHaveLength(1)
    expect(result.current.data.categoryRates[0].category).toBe('Beverages')
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCategoriesResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useCategories(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['dashboard', 'categories'])
    expect(cachedData).toBeDefined()
  })
})

describe('useSignals', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches signals from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSignalsResponse)

    const { result } = renderHook(() => useSignals(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/dashboard/signals', expect.any(Object))
  })

  it('returns signals data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSignalsResponse)

    const { result } = renderHook(() => useSignals(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.signalDominance).toHaveLength(1)
    expect(result.current.data.agreements).toHaveLength(1)
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockSignalsResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useSignals(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['dashboard', 'signals'])
    expect(cachedData).toBeDefined()
  })
})

describe('useCost', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches cost from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCostResponse)

    const { result } = renderHook(() => useCost(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/dashboard/cost', expect.any(Object))
  })

  it('returns cost data on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCostResponse)

    const { result } = renderHook(() => useCost(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.costData?.totalUsd).toBe(5.5)
    expect(result.current.data.scaleData.total).toBe(1000)
  })

  it('handles null costData', async () => {
    const responseWithNullCost = { ...mockCostResponse, costData: null }
    vi.mocked(fetchApi).mockResolvedValueOnce(responseWithNullCost)

    const { result } = renderHook(() => useCost(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data.costData).toBeNull()
    expect(result.current.data.scaleData).toBeDefined()
  })

  it('uses correct query key', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockCostResponse)

    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useCost(), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['dashboard', 'cost'])
    expect(cachedData).toBeDefined()
  })
})
