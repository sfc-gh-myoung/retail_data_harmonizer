import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactNode } from 'react'
import {
  useMatches,
  useFilterOptions,
  useAlternatives,
  useBulkAction,
  useUpdateMatch,
  useSkipMatch,
  useFeedback,
  useSelectAlternative,
} from './use-matches'

vi.mock('@/lib/api', () => ({
  fetchApi: vi.fn(),
  postApi: vi.fn(),
  postFormApi: vi.fn(),
}))

vi.mock('sonner', () => ({
  toast: {
    success: vi.fn(),
    error: vi.fn(),
  },
}))

import { fetchApi, postApi, postFormApi } from '@/lib/api'
import { toast } from 'sonner'

const mockMatch = {
  id: 'match-1',
  itemId: 'item-1',
  matchId: 'mid-1',
  rawName: 'DIET COKE 12PK',
  matchedName: 'Diet Coke 12 Pack',
  standardItemId: 'STD-001',
  status: 'PENDING_REVIEW',
  source: 'POS_A',
  category: 'Beverages',
  subcategory: 'Carbonated',
  brand: 'Coca-Cola',
  price: 5.99,
  searchScore: 0.85,
  cosineScore: 0.80,
  editScore: 0.75,
  jaccardScore: 0.70,
  ensembleScore: 0.88,
  maxRawScore: 0.85,
  score: 0.85,
  matchSource: 'SEARCH',
  matchMethod: 'ensemble',
  agreementLevel: 3,
  boostLevel: 'medium',
  boostPercent: 15,
  duplicateCount: 1,
  createdAt: '2026-03-17T10:00:00Z',
}

const mockMatchesResponse = {
  items: [mockMatch],
  total: 1,
  page: 1,
  pageSize: 25,
  totalPages: 1,
}

const mockFilterOptions = {
  sources: ['POS_A', 'POS_B'],
  categories: ['Beverages', 'Snacks'],
  matchSources: ['SEARCH', 'COSINE'],
  boostLevels: [{ value: 'high', label: 'High' }],
  groupByOptions: [{ value: 'source', label: 'Source' }],
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

describe('useMatches', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches matches with filters', async () => {
    vi.mocked(postApi).mockResolvedValueOnce(mockMatchesResponse)

    const filters = { status: 'PENDING_REVIEW', page: 1 }
    const { result } = renderHook(() => useMatches(filters), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith('/v2/matches/search', filters, expect.any(Object))
  })

  it('returns matches on success', async () => {
    vi.mocked(postApi).mockResolvedValueOnce(mockMatchesResponse)

    const { result } = renderHook(() => useMatches({}), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.items).toHaveLength(1)
    expect(result.current.data?.items[0].rawName).toBe('DIET COKE 12PK')
  })

  it('includes filters in query key', async () => {
    vi.mocked(postApi).mockResolvedValueOnce(mockMatchesResponse)

    const filters = { status: 'CONFIRMED', source: 'POS_A' }
    const queryClient = createTestQueryClient()
    const { result } = renderHook(() => useMatches(filters), {
      wrapper: createWrapper(queryClient),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    const cachedData = queryClient.getQueryData(['matches', filters])
    expect(cachedData).toBeDefined()
  })
})

describe('useFilterOptions', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches filter options from correct endpoint', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFilterOptions)

    const { result } = renderHook(() => useFilterOptions(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/matches/filter-options', expect.any(Object))
  })

  it('returns filter options on success', async () => {
    vi.mocked(fetchApi).mockResolvedValueOnce(mockFilterOptions)

    const { result } = renderHook(() => useFilterOptions(), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(result.current.data?.sources).toContain('POS_A')
    expect(result.current.data?.categories).toContain('Beverages')
  })
})

describe('useAlternatives', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('fetches alternatives when itemId is provided', async () => {
    const mockAlternatives = { alternatives: [{ standardItemId: 'STD-002', description: 'Alt product', brand: 'Brand', price: 6.99, score: 0.75, method: 'search', rank: 1 }] }
    vi.mocked(fetchApi).mockResolvedValueOnce(mockAlternatives)

    const { result } = renderHook(() => useAlternatives('item-1'), {
      wrapper: createWrapper(),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetchApi).toHaveBeenCalledWith('/v2/matches/item-1/alternatives', expect.any(Object))
  })

  it('does not fetch when itemId is null', async () => {
    const { result } = renderHook(() => useAlternatives(null), {
      wrapper: createWrapper(),
    })

    expect(result.current.isLoading).toBe(false)
    expect(fetchApi).not.toHaveBeenCalled()
  })
})

describe('useBulkAction', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls bulk endpoint with action and ids', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useBulkAction(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ action: 'accept', ids: ['match-1', 'match-2'] })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith(
      '/v2/matches/bulk',
      {
        action: 'accept',
        ids: ['match-1', 'match-2'],
      },
      expect.any(Object)
    )
  })

  it('shows success toast on completion', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useBulkAction(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ action: 'accept', ids: ['match-1'] })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('1 match confirmed')
  })

  it('shows error toast on failure', async () => {
    vi.mocked(postApi).mockRejectedValueOnce(new Error('Server error'))

    const { result } = renderHook(() => useBulkAction(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ action: 'reject', ids: ['match-1'] })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalled()
  })
})

describe('useUpdateMatch', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls status endpoint', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith('/v2/matches/match-1/status', { status: 'CONFIRMED' }, expect.any(Object))
  })

  it('shows success toast', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('Match confirmed')
  })

  it('shows rejected status in toast', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'REJECTED' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('Match rejected')
  })

  it('shows lowercase status for other statuses', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'PENDING' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('Match pending')
  })

  it('performs optimistic update by removing item from cache', async () => {
    const queryClient = createTestQueryClient()
    
    // Pre-populate cache with matches data
    queryClient.setQueryData(['matches', {}], mockMatchesResponse)
    
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))
  })

  it('rolls back optimistic update on error', async () => {
    const queryClient = createTestQueryClient()
    
    // Pre-populate cache with matches data
    queryClient.setQueryData(['matches', {}], mockMatchesResponse)
    
    vi.mocked(postApi).mockRejectedValueOnce(new Error('Update failed'))

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to update match: Update failed')
  })

  it('handles non-Error error objects', async () => {
    vi.mocked(postApi).mockRejectedValueOnce('String error')

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to update match: Unknown error')
  })

  it('invalidates queries on settled', async () => {
    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')
    
    vi.mocked(postApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ id: 'match-1', status: 'CONFIRMED' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['matches'], refetchType: 'none' })
  })

  it('passes updateRelated flag to API when provided', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true, updatedCount: 3 })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ 
        id: 'match-1', 
        status: 'CONFIRMED',
        rawName: 'skittles',
        updateRelated: true 
      })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postApi).toHaveBeenCalledWith(
      '/v2/matches/match-1/status',
      { 
        status: 'CONFIRMED', 
        updateRelated: true 
      },
      expect.any(Object)
    )
  })

  it('shows plural toast message when multiple matches updated', async () => {
    vi.mocked(postApi).mockResolvedValueOnce({ success: true, updatedCount: 96, variantCount: 3 })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ 
        id: 'match-1', 
        status: 'CONFIRMED',
        rawName: 'skittles',
        updateRelated: true 
      })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('96 matches confirmed (3 variants)')
  })

  it('filters items by normalized description in optimistic update when updateRelated is true', async () => {
    const queryClient = createTestQueryClient()
    
    // Pre-populate cache with matches data including items with same normalized description
    const matchesWithDuplicates = {
      ...mockMatchesResponse,
      items: [
        { ...mockMatchesResponse.items[0], id: 'match-1', rawName: 'Skittles' },
        { ...mockMatchesResponse.items[0], id: 'match-2', rawName: 'SKITTLES' },
        { ...mockMatchesResponse.items[0], id: 'match-3', rawName: 'skittles' },
        { ...mockMatchesResponse.items[0], id: 'match-4', rawName: 'M&Ms' },
      ],
      total: 4,
    }
    queryClient.setQueryData(['matches', {}], matchesWithDuplicates)
    
    vi.mocked(postApi).mockResolvedValueOnce({ success: true, updatedCount: 3 })

    const { result } = renderHook(() => useUpdateMatch(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ 
        id: 'match-1', 
        status: 'CONFIRMED',
        rawName: 'Skittles',
        updateRelated: true 
      })
    })

    // Check that the cache was updated optimistically - all Skittles variants removed
    const cachedData = queryClient.getQueryData<typeof mockMatchesResponse>(['matches', {}])
    expect(cachedData?.items).toHaveLength(1) // Only M&Ms should remain
    expect(cachedData?.items[0].rawName).toBe('M&Ms')
    expect(cachedData?.total).toBe(1)
  })
})

describe('useSkipMatch', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls review action endpoint with skip action', async () => {
    vi.mocked(postFormApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useSkipMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postFormApi).toHaveBeenCalled()
  })

  it('shows success toast on skip', async () => {
    vi.mocked(postFormApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useSkipMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(toast.success).toHaveBeenCalledWith('Match skipped')
  })

  it('shows error toast on failure', async () => {
    vi.mocked(postFormApi).mockRejectedValueOnce(new Error('Skip failed'))

    const { result } = renderHook(() => useSkipMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to skip match: Skip failed')
  })

  it('handles non-Error error objects', async () => {
    vi.mocked(postFormApi).mockRejectedValueOnce('String error')

    const { result } = renderHook(() => useSkipMatch(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to skip match: Unknown error')
  })
})

describe('useFeedback', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls feedback endpoint', async () => {
    vi.mocked(postFormApi).mockResolvedValueOnce({ success: true })

    const { result } = renderHook(() => useFeedback(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ matchId: 'mid-1', itemId: 'item-1', feedback: 'up' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postFormApi).toHaveBeenCalled()
  })
})

describe('useSelectAlternative', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('calls select-alternative endpoint', async () => {
    vi.mocked(postFormApi).mockResolvedValueOnce({ success: true })

    const queryClient = createTestQueryClient()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    const { result } = renderHook(() => useSelectAlternative(), {
      wrapper: createWrapper(queryClient),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1', standardId: 'STD-002' })
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(postFormApi).toHaveBeenCalled()
    expect(toast.success).toHaveBeenCalledWith('Alternative selected')
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['matches'], refetchType: 'none' })
  })

  it('shows error toast on failure', async () => {
    vi.mocked(postFormApi).mockRejectedValueOnce(new Error('Selection failed'))

    const { result } = renderHook(() => useSelectAlternative(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1', standardId: 'STD-002' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to select alternative: Selection failed')
  })

  it('handles non-Error error objects', async () => {
    vi.mocked(postFormApi).mockRejectedValueOnce('String error')

    const { result } = renderHook(() => useSelectAlternative(), {
      wrapper: createWrapper(),
    })

    await act(async () => {
      result.current.mutate({ itemId: 'item-1', matchId: 'mid-1', standardId: 'STD-002' })
    })

    await waitFor(() => expect(result.current.isError).toBe(true))

    expect(toast.error).toHaveBeenCalledWith('Failed to select alternative: Unknown error')
  })
})
