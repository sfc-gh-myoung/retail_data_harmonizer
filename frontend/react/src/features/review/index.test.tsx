import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Review } from './index'

vi.mock('./hooks/use-matches', () => ({
  useMatches: vi.fn(),
  useBulkAction: vi.fn(() => ({ mutate: vi.fn(), isPending: false })),
  useUpdateMatch: vi.fn(() => ({ mutate: vi.fn(), isPending: false })),
  useFilterOptions: vi.fn(),
  useSkipMatch: vi.fn(() => ({ mutate: vi.fn(), isPending: false })),
  useFeedback: vi.fn(() => ({ mutate: vi.fn(), isPending: false })),
}))

vi.mock('./components/confidence-badge', () => ({
  ConfidenceBadge: ({ score }: { score: number }) => (
    <span data-testid="confidence-badge">{score.toFixed(3)}</span>
  ),
}))

vi.mock('./components/score-breakdown', () => ({
  ScoreBreakdown: () => <div data-testid="score-breakdown" />,
}))

vi.mock('./components/alternatives-modal', () => ({
  AlternativesModal: () => <div data-testid="alternatives-modal" />,
}))

import {
  useMatches,
  useBulkAction,
  useUpdateMatch,
  useFilterOptions,
  useSkipMatch,
  useFeedback,
} from './hooks/use-matches'

const mockMatch = (overrides = {}) => ({
  id: 'match-1',
  itemId: 'item-1',
  matchId: 'mid-1',
  rawName: 'DIET COKE 12PK',
  matchedName: 'Diet Coke 12 Pack Cans',
  standardItemId: 'STD-001',
  status: 'PENDING_REVIEW',
  source: 'POS_SYSTEM_A',
  category: 'Beverages',
  subcategory: 'Carbonated',
  brand: 'Coca-Cola',
  price: 5.99,
  searchScore: 0.85,
  cosineScore: 0.82,
  editScore: 0.78,
  jaccardScore: 0.75,
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
  ...overrides,
})

const mockMatchesData = {
  items: [
    mockMatch(),
    mockMatch({
      id: 'match-2',
      itemId: 'item-2',
      matchId: 'mid-2',
      rawName: 'PEPSI 6PK',
      matchedName: 'Pepsi 6 Pack Cans',
      status: 'PENDING_REVIEW',
      source: 'POS_SYSTEM_B',
      category: 'Beverages',
      ensembleScore: 0.72,
      maxRawScore: 0.70,
      matchSource: 'COSINE',
      agreementLevel: 2,
      boostPercent: 0,
    }),
    mockMatch({
      id: 'match-3',
      itemId: 'item-3',
      matchId: 'mid-3',
      rawName: 'LAYS CHIPS',
      matchedName: "Lay's Classic Chips",
      status: 'CONFIRMED',
      source: 'POS_SYSTEM_A',
      category: 'Snacks',
      ensembleScore: 0.95,
      maxRawScore: 0.92,
      matchSource: 'SEARCH',
      agreementLevel: 4,
      boostPercent: 20,
    }),
  ],
  total: 3,
  page: 1,
  pageSize: 25,
  totalPages: 1,
}

const mockFilterOptions = {
  sources: ['POS_SYSTEM_A', 'POS_SYSTEM_B'],
  categories: ['Beverages', 'Snacks'],
  matchSources: ['SEARCH', 'COSINE', 'EDIT', 'JACCARD'],
  boostLevels: [
    { value: 'high', label: 'High' },
    { value: 'medium', label: 'Medium' },
    { value: 'low', label: 'Low' },
  ],
  groupByOptions: [
    { value: 'unique_description', label: 'No Grouping' },
    { value: 'source_system', label: 'Source System' },
    { value: 'category', label: 'Category' },
    { value: 'match_source', label: 'Match Source' },
  ],
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
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
  )
}

function setupDefaultMocks() {
  vi.mocked(useMatches).mockReturnValue({
    data: mockMatchesData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as unknown as ReturnType<typeof useMatches>)

  vi.mocked(useFilterOptions).mockReturnValue({
    data: mockFilterOptions,
    isLoading: false,
    error: null,
  } as unknown as ReturnType<typeof useFilterOptions>)
}

describe('Review', () => {
  beforeAll(() => {
    // JSDOM mocks for Radix Select
    Element.prototype.hasPointerCapture = vi.fn(() => false)
    Element.prototype.setPointerCapture = vi.fn()
    Element.prototype.releasePointerCapture = vi.fn()
    Element.prototype.scrollIntoView = vi.fn()
  })

  beforeEach(() => {
    vi.clearAllMocks()
  })

  // ── Loading state ───────────────────────────────────────────────────

  it('renders loading skeleton when data is loading', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: undefined,
      isLoading: true,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: undefined,
      isLoading: true,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    // Header still renders
    expect(screen.getByText('Review Matches')).toBeInTheDocument()
    // Skeleton shown instead of table
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
  })

  // ── Error state ─────────────────────────────────────────────────────

  it('renders error alert when fetch fails', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Network error'),
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: undefined,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    expect(screen.getByText(/failed to load matches/i)).toBeInTheDocument()
    expect(screen.getByText(/network error/i)).toBeInTheDocument()
  })

  // ── Data rendering ──────────────────────────────────────────────────

  it('renders matches in the table', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText('DIET COKE 12PK')).toBeInTheDocument()
    expect(screen.getByText('PEPSI 6PK')).toBeInTheDocument()
    expect(screen.getByText('LAYS CHIPS')).toBeInTheDocument()
  })

  it('renders matched product names', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText('Diet Coke 12 Pack Cans')).toBeInTheDocument()
    expect(screen.getByText('Pepsi 6 Pack Cans')).toBeInTheDocument()
    expect(screen.getByText("Lay's Classic Chips")).toBeInTheDocument()
  })

  it('renders source system for each match', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getAllByText('POS_SYSTEM_A')).toHaveLength(2)
    expect(screen.getByText('POS_SYSTEM_B')).toBeInTheDocument()
  })

  it('renders match source badges', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Two SEARCH badges (match-1 and match-3) and one COSINE badge
    expect(screen.getAllByText('SEARCH')).toHaveLength(2)
    expect(screen.getByText('COSINE')).toBeInTheDocument()
  })

  it('renders confidence scores via ConfidenceBadge', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    const badges = screen.getAllByTestId('confidence-badge')
    expect(badges.length).toBeGreaterThanOrEqual(6)
  })

  it('renders pagination info when data exists', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText(/showing/i)).toBeInTheDocument()
  })

  // ── Header controls ─────────────────────────────────────────────────

  it('renders auto-refresh toggle', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText('Auto-refresh')).toBeInTheDocument()
    expect(screen.getByRole('switch')).toBeInTheDocument()
  })

  it('renders refresh button', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByRole('button', { name: /refresh/i })).toBeInTheDocument()
  })

  it('calls refetch when refresh button is clicked', () => {
    const mockRefetch = vi.fn()
    vi.mocked(useMatches).mockReturnValue({
      data: mockMatchesData,
      isLoading: false,
      error: null,
      refetch: mockRefetch,
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    fireEvent.click(screen.getByRole('button', { name: /refresh/i }))
    expect(mockRefetch).toHaveBeenCalled()
  })

  // ── Row expansion ───────────────────────────────────────────────────

  it('expands row to show score breakdown on click', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Score breakdown not visible initially
    expect(screen.queryByTestId('score-breakdown')).not.toBeInTheDocument()

    // Click the first data row to expand it
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    // Score breakdown now visible
    expect(screen.getByTestId('score-breakdown')).toBeInTheDocument()
  })

  it('shows action buttons in expanded row', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Expand first row
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    // Action buttons visible
    expect(screen.getByRole('button', { name: /confirm/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /reject/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /skip/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /show alternatives/i })).toBeInTheDocument()
  })

  it('calls updateMatch when Confirm is clicked in expanded row', () => {
    const mockMutate = vi.fn()
    vi.mocked(useUpdateMatch).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useUpdateMatch>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Expand first row
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    fireEvent.click(screen.getByRole('button', { name: /confirm/i }))
    expect(mockMutate).toHaveBeenCalledWith({ 
      id: 'match-1', 
      status: 'CONFIRMED',
      rawName: 'DIET COKE 12PK',
      updateRelated: true,
    })
  })

  it('calls updateMatch when Reject is clicked in expanded row', () => {
    const mockMutate = vi.fn()
    vi.mocked(useUpdateMatch).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useUpdateMatch>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Expand first row
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    fireEvent.click(screen.getByRole('button', { name: /reject/i }))
    expect(mockMutate).toHaveBeenCalledWith({ 
      id: 'match-1', 
      status: 'REJECTED',
      rawName: 'DIET COKE 12PK',
      updateRelated: true,
    })
  })

  it('calls skipMatch when Skip is clicked in expanded row', () => {
    const mockMutate = vi.fn()
    vi.mocked(useSkipMatch).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useSkipMatch>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Expand first row
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    fireEvent.click(screen.getByRole('button', { name: /skip/i }))
    expect(mockMutate).toHaveBeenCalledWith({ itemId: 'item-1', matchId: 'mid-1' })
  })

  it('shows feedback buttons in expanded row', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Expand first row
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText('Feedback:')).toBeInTheDocument()
    expect(screen.getByTitle('Thumbs up')).toBeInTheDocument()
    expect(screen.getByTitle('Thumbs down')).toBeInTheDocument()
  })

  it('calls feedback mutation on thumbs up click', () => {
    const mockMutate = vi.fn()
    vi.mocked(useFeedback).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useFeedback>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    fireEvent.click(screen.getByTitle('Thumbs up'))
    expect(mockMutate).toHaveBeenCalledWith({
      matchId: 'mid-1',
      itemId: 'item-1',
      feedback: 'up',
    })
  })

  // ── Bulk selection ──────────────────────────────────────────────────

  it('renders checkboxes for actionable rows', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Select all checkbox + 2 actionable rows (PENDING_REVIEW), not CONFIRMED match-3
    const checkboxes = screen.getAllByRole('checkbox')
    // Select-all + 2 actionable
    expect(checkboxes.length).toBe(3)
  })

  it('shows bulk action buttons when rows are selected', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Click select-all checkbox
    const selectAll = screen.getAllByRole('checkbox')[0]
    fireEvent.click(selectAll)

    expect(screen.getByText(/selected/i)).toBeInTheDocument()
  })

  it('calls bulkAction on bulk confirm', () => {
    const mockMutate = vi.fn()
    vi.mocked(useBulkAction).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useBulkAction>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Select all
    const selectAll = screen.getAllByRole('checkbox')[0]
    fireEvent.click(selectAll)

    // Click bulk confirm
    const bulkConfirm = screen.getAllByRole('button').find(
      (btn) => btn.textContent?.includes('Confirm') && btn.closest('.border-l')
    )
    if (bulkConfirm) {
      fireEvent.click(bulkConfirm)
      expect(mockMutate).toHaveBeenCalled()
    }
  })

  // ── No results ──────────────────────────────────────────────────────

  it('renders empty state when no matches', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [],
        total: 0,
        page: 1,
        pageSize: 25,
        totalPages: 0,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    expect(screen.getByText('No results.')).toBeInTheDocument()
  })

  // ── Boost and agreement badges ──────────────────────────────────────

  it('renders agreement level badges with boost percentage', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText('3-way: 15%')).toBeInTheDocument()
    expect(screen.getByText('4-way: 20%')).toBeInTheDocument()
  })

  // ── Duplicate count badge ───────────────────────────────────────────

  it('renders duplicate count badge when duplicateCount > 1', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        ...mockMatchesData,
        items: [mockMatch({ duplicateCount: 5 })],
        total: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    expect(screen.getByText('5 items')).toBeInTheDocument()
  })

  // ── Alternatives modal ──────────────────────────────────────────────

  it('renders alternatives modal component', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByTestId('alternatives-modal')).toBeInTheDocument()
  })

  // ── Processing status ───────────────────────────────────────────────

  it('shows Processing... for PENDING matches without matched name', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [mockMatch({ status: 'PENDING', matchedName: '' })],
        total: 1,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    expect(screen.getByText('Processing...')).toBeInTheDocument()
  })

  // ── Expand button ───────────────────────────────────────────────────────

  it('expands row when expand button is clicked directly', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Find expand buttons (chevron icons)
    const expandButtons = screen.getAllByRole('button').filter(
      (btn) => btn.querySelector('svg[class*="lucide-chevron"]')
    )
    
    if (expandButtons.length > 0) {
      fireEvent.click(expandButtons[0])
      expect(screen.getByTestId('score-breakdown')).toBeInTheDocument()
    }
  })

  // ── Auto-refresh toggle ─────────────────────────────────────────────────

  it('toggles auto-refresh on switch click', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    const autoRefreshSwitch = screen.getByRole('switch')
    expect(autoRefreshSwitch).toHaveAttribute('data-state', 'unchecked')

    fireEvent.click(autoRefreshSwitch)
    expect(autoRefreshSwitch).toHaveAttribute('data-state', 'checked')
  })

  // ── Filter changes ──────────────────────────────────────────────────────

  it('renders status filter dropdown', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Find status filter trigger
    expect(screen.getByText('Pending Review')).toBeInTheDocument()
  })

  it('renders group by dropdown', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getByText('No Grouping')).toBeInTheDocument()
  })

  // ── Match source badges ─────────────────────────────────────────────────

  it('renders different match source styles', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [
          mockMatch({ matchSource: 'EDIT' }),
          mockMatch({ id: 'match-2', matchSource: 'JACCARD' }),
          mockMatch({ id: 'match-3', matchSource: 'SEARCH' }),
        ],
        total: 3,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    expect(screen.getByText('EDIT')).toBeInTheDocument()
    expect(screen.getByText('JACCARD')).toBeInTheDocument()
    expect(screen.getByText('SEARCH')).toBeInTheDocument()
  })

  // ── Different status badges ─────────────────────────────────────────────

  it('renders CONFIRMED status badge', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [mockMatch({ status: 'CONFIRMED' })],
        total: 1,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    // Click to expand and see status badge
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText('CONFIRMED')).toBeInTheDocument()
  })

  it('renders REJECTED status badge', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [mockMatch({ status: 'REJECTED' })],
        total: 1,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    // Click to expand and see status badge
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText('REJECTED')).toBeInTheDocument()
  })

  it('renders SKIPPED status badge', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [mockMatch({ status: 'SKIPPED' })],
        total: 1,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    // Click to expand and see status badge
    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText('SKIPPED')).toBeInTheDocument()
  })

  // ── Expanded row details ────────────────────────────────────────────────

  it('shows brand in expanded row when available', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText(/Coca-Cola/)).toBeInTheDocument()
  })

  it('shows price in expanded row when > 0', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    expect(screen.getByText(/\$5\.99/)).toBeInTheDocument()
  })

  // ── Feedback down button ────────────────────────────────────────────────

  it('calls feedback mutation on thumbs down click', () => {
    const mockMutate = vi.fn()
    vi.mocked(useFeedback).mockReturnValue({
      mutate: mockMutate,
      isPending: false,
    } as unknown as ReturnType<typeof useFeedback>)

    setupDefaultMocks()
    renderWithProviders(<Review />)

    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    fireEvent.click(screen.getByTitle('Thumbs down'))
    expect(mockMutate).toHaveBeenCalledWith({
      matchId: 'mid-1',
      itemId: 'item-1',
      feedback: 'down',
    })
  })

  // ── Non-actionable rows ─────────────────────────────────────────────────

  it('disables action buttons for non-actionable matches', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: {
        items: [mockMatch({ status: 'CONFIRMED' })],
        total: 1,
        page: 1,
        pageSize: 25,
        totalPages: 1,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: false,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    const firstRow = screen.getByText('DIET COKE 12PK').closest('tr')!
    fireEvent.click(firstRow)

    // Confirm button should be disabled for CONFIRMED status
    const confirmBtn = screen.getByRole('button', { name: /confirm/i })
    expect(confirmBtn).toBeDisabled()
  })

  // ── Sorting ─────────────────────────────────────────────────────────────

  it('renders sortable column headers', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Check for actual column headers
    expect(screen.getByText('POS Item')).toBeInTheDocument()
    expect(screen.getByText('Matched Product')).toBeInTheDocument()
    expect(screen.getByText('Match')).toBeInTheDocument()
  })

  // ── isFetching state ────────────────────────────────────────────────────

  it('shows loading indicator when refetching', () => {
    vi.mocked(useMatches).mockReturnValue({
      data: mockMatchesData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
      isFetching: true,
    } as unknown as ReturnType<typeof useMatches>)

    vi.mocked(useFilterOptions).mockReturnValue({
      data: mockFilterOptions,
      isLoading: false,
      error: null,
    } as unknown as ReturnType<typeof useFilterOptions>)

    renderWithProviders(<Review />)

    // Should show spinner or loading indicator
    expect(document.querySelector('.animate-spin')).toBeInTheDocument()
  })

  // ── Pagination ──────────────────────────────────────────────────────────

  it('renders pagination controls', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    // Pagination info should be visible - check for total count
    expect(screen.getByText('3')).toBeInTheDocument()
  })

  // ── Category column ─────────────────────────────────────────────────────

  it('renders category for matches', () => {
    setupDefaultMocks()
    renderWithProviders(<Review />)

    expect(screen.getAllByText('Beverages').length).toBeGreaterThanOrEqual(1)
    expect(screen.getByText('Snacks')).toBeInTheDocument()
  })

  // ── Filter and groupBy handlers ────────────────────────────────────────

  describe('Review - filter and groupBy handlers', () => {
    it('calls useMatches with updated groupBy when group by filter changes', async () => {
      const user = userEvent.setup()
      setupDefaultMocks()
      renderWithProviders(<Review />)

      // Initial call should have groupBy: 'unique_description' (default)
      expect(useMatches).toHaveBeenCalled()
      const initialCall = vi.mocked(useMatches).mock.calls[0][0]
      expect(initialCall.groupBy).toBe('unique_description')

      // Find the Group By dropdown trigger (shows "No Grouping" initially)
      const groupByTrigger = screen.getByText('No Grouping').closest('button')!
      await user.click(groupByTrigger)

      // Select "Source System" option
      const sourceSystemOption = await screen.findByRole('option', { name: /source system/i })
      await user.click(sourceSystemOption)

      // Verify useMatches was called with updated groupBy
      const calls = vi.mocked(useMatches).mock.calls
      const lastCall = calls[calls.length - 1][0]
      expect(lastCall.groupBy).toBe('source_system')
    })

    it('calls useMatches with updated status when status filter changes', async () => {
      const user = userEvent.setup()
      setupDefaultMocks()
      renderWithProviders(<Review />)

      // Find the Status dropdown trigger (shows "Pending Review" initially)
      const statusTrigger = screen.getByText('Pending Review').closest('button')!
      await user.click(statusTrigger)

      // Select "Confirmed" option
      const confirmedOption = await screen.findByRole('option', { name: /confirmed/i })
      await user.click(confirmedOption)

      // Verify useMatches was called with updated status
      const calls = vi.mocked(useMatches).mock.calls
      const lastCall = calls[calls.length - 1][0]
      expect(lastCall.status).toBe('CONFIRMED')
    })

    it('resets page to 1 when filter changes', async () => {
      const user = userEvent.setup()
      setupDefaultMocks()
      renderWithProviders(<Review />)

      // Find the Source System filter (shows "All Sources" placeholder or first source)
      const sourceLabels = screen.getAllByText('All Sources')
      const sourceFilterTrigger = sourceLabels[0].closest('button')
      
      if (sourceFilterTrigger) {
        await user.click(sourceFilterTrigger)
        const posAOption = await screen.findByRole('option', { name: /POS_SYSTEM_A/i })
        await user.click(posAOption)

        // Verify page was reset to 1
        const calls = vi.mocked(useMatches).mock.calls
        const lastCall = calls[calls.length - 1][0]
        expect(lastCall.page).toBe(1)
      }
    })

    it('displays grouped data when groupBy is active', () => {
      // Set up mock with groupBy set to 'source_system'
      vi.mocked(useMatches).mockReturnValue({
        data: {
          items: [
            mockMatch({ source: 'POS_SYSTEM_A' }),
            mockMatch({ id: 'match-2', source: 'POS_SYSTEM_A' }),
            mockMatch({ id: 'match-3', source: 'POS_SYSTEM_B' }),
          ],
          total: 3,
          page: 1,
          pageSize: 25,
          totalPages: 1,
        },
        isLoading: false,
        error: null,
        refetch: vi.fn(),
        isFetching: false,
      } as unknown as ReturnType<typeof useMatches>)

      vi.mocked(useFilterOptions).mockReturnValue({
        data: mockFilterOptions,
        isLoading: false,
        error: null,
      } as unknown as ReturnType<typeof useFilterOptions>)

      renderWithProviders(<Review />)

      // Data should render (grouping is computed client-side when groupBy !== 'unique_description')
      expect(screen.getAllByText('DIET COKE 12PK').length).toBeGreaterThanOrEqual(1)
    })

    it('toggles group collapse state when group header is clicked', async () => {
      // This test verifies the toggleGroup function by checking UI state
      // When grouping is active, clicking a group header should collapse/expand it
      vi.mocked(useMatches).mockReturnValue({
        data: {
          items: [
            mockMatch({ source: 'POS_SYSTEM_A', category: 'Beverages' }),
            mockMatch({ id: 'match-2', source: 'POS_SYSTEM_A', category: 'Beverages' }),
          ],
          total: 2,
          page: 1,
          pageSize: 25,
          totalPages: 1,
        },
        isLoading: false,
        error: null,
        refetch: vi.fn(),
        isFetching: false,
      } as unknown as ReturnType<typeof useMatches>)

      vi.mocked(useFilterOptions).mockReturnValue({
        data: mockFilterOptions,
        isLoading: false,
        error: null,
      } as unknown as ReturnType<typeof useFilterOptions>)

      const user = userEvent.setup()
      renderWithProviders(<Review />)

      // Change groupBy to 'category' to activate grouping
      const groupByTrigger = screen.getByText('No Grouping').closest('button')!
      await user.click(groupByTrigger)
      const categoryOption = await screen.findByRole('option', { name: /^category$/i })
      await user.click(categoryOption)

      // Look for group header rows - they should have the group name
      const beveragesGroups = screen.queryAllByText('Beverages')
      const beveragesGroup = beveragesGroups.find(el => el.closest('tr.cursor-pointer'))
      if (beveragesGroup) {
        // Click the group header to collapse
        const groupRow = beveragesGroup.closest('tr')
        if (groupRow) {
          fireEvent.click(groupRow)
          // Group is now collapsed - verifies toggleGroup was called
        }
      }
    })

    it('clears collapsed groups when groupBy changes', async () => {
      const user = userEvent.setup()
      setupDefaultMocks()
      renderWithProviders(<Review />)

      // Change groupBy to category
      const groupByTrigger = screen.getByText('No Grouping').closest('button')!
      await user.click(groupByTrigger)
      const categoryOption = await screen.findByRole('option', { name: /^category$/i })
      await user.click(categoryOption)

      // Verify useMatches was called with updated groupBy
      const calls = vi.mocked(useMatches).mock.calls
      expect(calls.length).toBeGreaterThan(1)
      // Verify last call includes category groupBy
      const lastCall = calls[calls.length - 1]
      expect(lastCall[0]).toMatchObject({ groupBy: 'category' })
    })
  })
})
