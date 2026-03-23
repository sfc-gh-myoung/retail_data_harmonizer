/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Dashboard } from './index'

// Track mock state for useIsFetching
let mockIsFetchingValue = 0
const mockInvalidateQueries = vi.fn()

// Mock @tanstack/react-query hooks used directly in Dashboard
vi.mock('@tanstack/react-query', async () => {
  const actual = await vi.importActual('@tanstack/react-query')
  return {
    ...actual,
    useIsFetching: () => mockIsFetchingValue,
    useQueryClient: () => ({
      invalidateQueries: mockInvalidateQueries,
    }),
  }
})

// Mock the individual hooks
vi.mock('./hooks', () => ({
  useKpis: vi.fn(),
  useSources: vi.fn(),
  useCategories: vi.fn(),
  useSignals: vi.fn(),
  useCost: vi.fn(),
}))

vi.mock('@/components/page-header', () => ({
  PageHeader: ({ title, isFetching, onRefresh }: any) => (
    <div>
      <h1>{title}</h1>
      <button onClick={onRefresh} disabled={isFetching}>Refresh</button>
      <span>Auto-refresh: {isFetching ? 'fetching' : 'ON'}</span>
    </div>
  ),
}))

vi.mock('@/components/section-wrapper', () => ({
  SectionWrapper: ({ children }: any) => <div>{children}</div>,
}))

import { useKpis, useSources, useCategories, useSignals, useCost } from './hooks'

const mockKpisData = {
  stats: {
    totalRaw: 10000,
    totalUnique: 5000,
    totalProcessed: 4500,
    total: 10000,
    autoAccepted: 3000,
    confirmed: 1000,
    pendingReview: 300,
    rejected: 100,
    needsCategorized: 100,
    matchRate: 85.5,
  },
  statuses: [
    { label: 'Auto-Accepted', count: 3000, color: '#10b981' },
    { label: 'Pending Review', count: 300, color: '#f59e0b' },
  ],
  statusColorsMap: { 'Auto-Accepted': '#10b981', 'Pending': '#f59e0b' },
}

const mockSourcesData = {
  sourceSystems: {
    'System A': { 'Auto-Accepted': 1500, 'Pending': 100 },
  },
  sourceMax: 2000,
  sourceRates: [
    { source: 'System A', rate: 90, total: 2500 },
  ],
}

const mockCategoriesData = {
  categoryRates: [
    { category: 'Electronics', rate: 88, total: 1000 },
  ],
}

const mockSignalsData = {
  agreements: [
    { level: '5-way', count: 2000, color: '#10b981', pct: 40 },
    { level: '4-way', count: 1500, color: '#3b82f6', pct: 30 },
  ],
  signalDominance: [
    { method: 'Search', count: 2000, color: '#10b981', pct: 40 },
  ],
  signalAlignment: [
    { method: 'Cosine', count: 1800, color: '#3b82f6', pct: 36 },
  ],
}

const mockCostData = {
  costData: {
    totalRuns: 10,
    totalCredits: 50.25,
    creditRateUsd: 3.0,
    totalUsd: 150.75,
    totalItems: 5000,
    costPerItem: 0.0302,
    manualMinutesPerItem: 3.0,
    manualHourlyRate: 50.0,
    baselineWeeklyCost: 12500.0,
    hoursSaved: 250.0,
    roiPercentage: 8200,
  },
  scaleData: {
    total: 10000,
    uniqueCount: 5000,
    dedupRatio: 0.5,
    fastPathRate: 60.0,
    fastPathCount: 6000,
  },
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
      {ui}
    </QueryClientProvider>
  )
}

function mockAllHooksWithData() {
  vi.mocked(useKpis).mockReturnValue({
    data: mockKpisData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as any)

  vi.mocked(useSources).mockReturnValue({
    data: mockSourcesData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as any)

  vi.mocked(useCategories).mockReturnValue({
    data: mockCategoriesData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as any)

  vi.mocked(useSignals).mockReturnValue({
    data: mockSignalsData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as any)

  vi.mocked(useCost).mockReturnValue({
    data: mockCostData,
    isLoading: false,
    error: null,
    refetch: vi.fn(),
    isFetching: false,
  } as any)
}

describe('Dashboard', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockIsFetchingValue = 0
  })

  it('renders dashboard header correctly', () => {
    // Note: useSuspenseQuery guarantees data is available after Suspense resolves
    // Loading states are handled by Suspense boundaries, not by the component
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Pipeline Dashboard')).toBeInTheDocument()
  })

  it('renders dashboard header with controls', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)

    expect(screen.getByText('Pipeline Dashboard')).toBeInTheDocument()
    expect(screen.getByText(/Auto-refresh/)).toBeInTheDocument()
    expect(screen.getByText('Refresh')).toBeInTheDocument()
  })

  it('renders KPI cards with data', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)

    expect(screen.getByText('Total Raw')).toBeInTheDocument()
    expect(screen.getByText('Total Unique')).toBeInTheDocument()
    expect(screen.getByText('Total Processed')).toBeInTheDocument()
  })

  it('renders status breakdown KPIs', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)

    expect(screen.getAllByText('Pending Review').length).toBeGreaterThan(0)
    expect(screen.getByText('Match Rate')).toBeInTheDocument()
  })

  it('calls invalidateQueries when refresh button clicked', () => {
    mockAllHooksWithData()

    renderWithProviders(<Dashboard />)

    fireEvent.click(screen.getByText('Refresh'))

    expect(mockInvalidateQueries).toHaveBeenCalledWith({ queryKey: ['dashboard'] })
  })

  it('disables refresh button when any hook is fetching', () => {
    mockAllHooksWithData()
    // useIsFetching returns count of fetching queries - set to 1 to simulate fetching
    mockIsFetchingValue = 1

    renderWithProviders(<Dashboard />)

    expect(screen.getByText('Refresh').closest('button')).toBeDisabled()
  })

  it('renders Status Distribution section when kpis data has statuses', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Status Distribution')).toBeInTheDocument()
  })

  it('renders Primary Signal Dominance section when signals data exists', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Primary Signal Dominance')).toBeInTheDocument()
  })

  it('renders Source Status section when sources data exists', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Status by Source System')).toBeInTheDocument()
  })

  it('renders Match Rate By Source section when sourceRates exists', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Match Rate By Source')).toBeInTheDocument()
  })

  it('renders Cost & ROI section when costData exists', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Cost & ROI')).toBeInTheDocument()
  })

  it('renders Scale Projection section when scaleData exists', () => {
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)
    expect(screen.getByText('Scale Projection')).toBeInTheDocument()
  })

  it('renders all sections when data is available', () => {
    // Note: useSuspenseQuery guarantees data is non-null after Suspense resolves
    // Testing null data is invalid for suspense queries - Suspense handles loading
    mockAllHooksWithData()
    renderWithProviders(<Dashboard />)

    expect(screen.getByText('Pipeline Dashboard')).toBeInTheDocument()
    // KPI cards should be rendered when data is available
    expect(screen.getByText('Total Raw')).toBeInTheDocument()
  })
})
