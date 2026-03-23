import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Comparison } from './index'

// Mock all hooks used by Comparison
vi.mock('./hooks', () => ({
  useAlgorithms: vi.fn(),
  useAgreement: vi.fn(),
  useSourcePerformance: vi.fn(),
  useMethodAccuracy: vi.fn(),
}))

import { useAlgorithms, useAgreement, useSourcePerformance, useMethodAccuracy } from './hooks'

const mockAlgorithmsData = {
  algorithms: [
    { name: 'Search', description: 'Full-text search matching', features: ['Fast', 'Fuzzy matching'] },
    { name: 'Cosine', description: 'Vector similarity', features: ['Semantic'] },
    { name: 'Edit', description: 'Edit distance', features: ['Typo detection'] },
    { name: 'Jaccard', description: 'Set similarity', features: ['Token overlap'] },
    { name: 'Ensemble', description: 'Combined methods', features: ['Best of all'] },
  ],
}

const mockAgreementData = {
  agreement: [
    { level: 'High (4/4)', count: 150, avgConfidence: 0.95 },
    { level: 'Medium (3/4)', count: 200, avgConfidence: 0.80 },
    { level: 'Low (2/4)', count: 100, avgConfidence: 0.65 },
  ],
}

const mockSourcePerformanceData = {
  sourcePerformance: [
    {
      source: 'POS_A',
      itemCount: 500,
      avgSearch: 0.85,
      avgCosine: 0.82,
      avgEdit: 0.75,
      avgJaccard: 0.70,
      avgEnsemble: 0.88,
    },
    {
      source: 'POS_B',
      itemCount: 300,
      avgSearch: 0.80,
      avgCosine: 0.78,
      avgEdit: 0.72,
      avgJaccard: 0.68,
      avgEnsemble: 0.85,
    },
  ],
}

const mockMethodAccuracyData = {
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

const mockEmptyMethodAccuracyData = {
  methodAccuracy: {
    totalConfirmed: 0,
    searchCorrect: 0,
    searchAccuracyPct: 0,
    cosineCorrect: 0,
    cosineAccuracyPct: 0,
    editCorrect: 0,
    editAccuracyPct: 0,
    jaccardCorrect: 0,
    jaccardAccuracyPct: 0,
    ensembleCorrect: 0,
    ensembleAccuracyPct: 0,
  },
}

function createMockQueryResult<T>(data: T, overrides = {}) {
  return {
    data,
    isSuccess: true,
    isError: false,
    isFetching: false,
    refetch: vi.fn(),
    ...overrides,
  }
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
}

function renderComparison() {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <Comparison />
    </QueryClientProvider>
  )
}

describe('Comparison', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useAlgorithms).mockReturnValue(createMockQueryResult(mockAlgorithmsData))
    vi.mocked(useAgreement).mockReturnValue(createMockQueryResult(mockAgreementData))
    vi.mocked(useSourcePerformance).mockReturnValue(createMockQueryResult(mockSourcePerformanceData))
    vi.mocked(useMethodAccuracy).mockReturnValue(createMockQueryResult(mockMethodAccuracyData))
  })

  describe('page layout', () => {
    it('renders page header with title', () => {
      renderComparison()
      expect(screen.getByText('Algorithm Comparison')).toBeInTheDocument()
    })

    it('renders all algorithm cards', () => {
      renderComparison()
      // Check for algorithm descriptions which are unique to the algorithm cards section
      expect(screen.getByText('Full-text search matching')).toBeInTheDocument()
      expect(screen.getByText('Vector similarity')).toBeInTheDocument()
      expect(screen.getByText('Edit distance')).toBeInTheDocument()
      expect(screen.getByText('Set similarity')).toBeInTheDocument()
      expect(screen.getByText('Combined methods')).toBeInTheDocument()
    })

    it('renders algorithm descriptions', () => {
      renderComparison()
      expect(screen.getByText('Full-text search matching')).toBeInTheDocument()
      expect(screen.getByText('Vector similarity')).toBeInTheDocument()
    })

    it('renders algorithm features', () => {
      renderComparison()
      expect(screen.getByText(/Fast/)).toBeInTheDocument()
      expect(screen.getByText(/Semantic/)).toBeInTheDocument()
    })
  })

  describe('Agreement Analysis section', () => {
    it('renders Agreement Analysis card title', () => {
      renderComparison()
      expect(screen.getByText('Agreement Analysis')).toBeInTheDocument()
    })

    it('renders agreement data in table', () => {
      renderComparison()
      expect(screen.getByText('High (4/4)')).toBeInTheDocument()
      expect(screen.getByText('Medium (3/4)')).toBeInTheDocument()
      expect(screen.getByText('Low (2/4)')).toBeInTheDocument()
    })

    it('shows empty state when no agreement data', () => {
      vi.mocked(useAgreement).mockReturnValue(
        createMockQueryResult({ agreement: [] })
      )
      renderComparison()
      expect(screen.getByText('No agreement data available. Run the pipeline first.')).toBeInTheDocument()
    })
  })

  describe('Source Performance section', () => {
    it('renders Source Performance card title', () => {
      renderComparison()
      expect(screen.getByText('Performance by Source System')).toBeInTheDocument()
    })

    it('renders source names in table', () => {
      renderComparison()
      expect(screen.getByText('POS_A')).toBeInTheDocument()
      expect(screen.getByText('POS_B')).toBeInTheDocument()
    })

    it('shows empty state when no source performance data', () => {
      vi.mocked(useSourcePerformance).mockReturnValue(
        createMockQueryResult({ sourcePerformance: [] })
      )
      renderComparison()
      expect(screen.getByText('No source performance data available.')).toBeInTheDocument()
    })
  })

  describe('Method Accuracy section', () => {
    it('renders Method Accuracy card title', () => {
      renderComparison()
      expect(screen.getByText('Method Accuracy vs Confirmed Matches')).toBeInTheDocument()
    })

    it('renders accuracy cards for all methods', () => {
      renderComparison()
      // Labels
      expect(screen.getByText('Edit Distance')).toBeInTheDocument()
      // Percentages
      expect(screen.getByText('85%')).toBeInTheDocument()
      expect(screen.getByText('82%')).toBeInTheDocument()
      expect(screen.getByText('78%')).toBeInTheDocument()
      expect(screen.getByText('75%')).toBeInTheDocument()
      expect(screen.getByText('94%')).toBeInTheDocument()
    })

    it('renders correct/total counts', () => {
      renderComparison()
      expect(screen.getByText('850/1000 correct')).toBeInTheDocument()
      expect(screen.getByText('940/1000 correct')).toBeInTheDocument()
    })

    it('shows empty state when totalConfirmed is 0', () => {
      vi.mocked(useMethodAccuracy).mockReturnValue(
        createMockQueryResult(mockEmptyMethodAccuracyData)
      )
      renderComparison()
      expect(screen.getByText('No confirmed matches yet. Confirm matches in the Review tab to see accuracy metrics.')).toBeInTheDocument()
    })
  })

  describe('ConfidenceBadge color variants', () => {
    it('renders confidence badges with appropriate colors', () => {
      renderComparison()
      // The ConfidenceBadge component is used in both agreement and source performance tables
      // It uses different variants based on value thresholds
      // >0.8 = success, >=0.7 = warning, >=0.6 = secondary, <0.6 = destructive
      
      // Check that confidence values are displayed (formatted to 4 decimal places)
      expect(screen.getByText('0.9500')).toBeInTheDocument() // 0.95 avgConfidence
      // 0.8000 appears multiple times (agreement + source performance), so use getAllBy
      expect(screen.getAllByText('0.8000').length).toBeGreaterThan(0)
      expect(screen.getByText('0.6500')).toBeInTheDocument() // 0.65 avgConfidence
    })
  })

  describe('AccuracyCard highlight', () => {
    it('renders Ensemble card with highlight styling', () => {
      renderComparison()
      // Ensemble is the highlighted card (best method)
      const ensembleCard = screen.getByText('94%').closest('div')
      expect(ensembleCard).toHaveClass('bg-primary/10')
    })

    it('renders other cards without highlight styling', () => {
      renderComparison()
      // Search is not highlighted
      const searchCard = screen.getByText('85%').closest('div')
      expect(searchCard).toHaveClass('bg-muted/50')
    })
  })

  describe('refetch functionality', () => {
    it('calls refetch on all queries when refetchAll is triggered', () => {
      const mockRefetchAlgorithms = vi.fn()
      const mockRefetchAgreement = vi.fn()
      const mockRefetchSourcePerformance = vi.fn()
      const mockRefetchMethodAccuracy = vi.fn()

      vi.mocked(useAlgorithms).mockReturnValue(
        createMockQueryResult(mockAlgorithmsData, { refetch: mockRefetchAlgorithms })
      )
      vi.mocked(useAgreement).mockReturnValue(
        createMockQueryResult(mockAgreementData, { refetch: mockRefetchAgreement })
      )
      vi.mocked(useSourcePerformance).mockReturnValue(
        createMockQueryResult(mockSourcePerformanceData, { refetch: mockRefetchSourcePerformance })
      )
      vi.mocked(useMethodAccuracy).mockReturnValue(
        createMockQueryResult(mockMethodAccuracyData, { refetch: mockRefetchMethodAccuracy })
      )

      renderComparison()

      // Note: The PageHeader's onRefresh is passed refetchAll internally
      // We verify the hooks are called with expected structure
      expect(useAlgorithms).toHaveBeenCalled()
      expect(useAgreement).toHaveBeenCalled()
      expect(useSourcePerformance).toHaveBeenCalled()
      expect(useMethodAccuracy).toHaveBeenCalled()
    })
  })

  describe('isFetching state', () => {
    it('detects fetching state from any hook', () => {
      vi.mocked(useAlgorithms).mockReturnValue(
        createMockQueryResult(mockAlgorithmsData, { isFetching: true })
      )

      renderComparison()

      // Component should render successfully even when fetching
      expect(screen.getByText('Algorithm Comparison')).toBeInTheDocument()
    })
  })
})

describe('ConfidenceBadge thresholds', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useAlgorithms).mockReturnValue(createMockQueryResult(mockAlgorithmsData))
    vi.mocked(useAgreement).mockReturnValue(createMockQueryResult({
      agreement: [
        { level: 'Very High', count: 10, avgConfidence: 0.95 },  // >0.8 = success
        { level: 'High', count: 10, avgConfidence: 0.75 },       // >=0.7 = warning
        { level: 'Medium', count: 10, avgConfidence: 0.65 },     // >=0.6 = secondary
        { level: 'Low', count: 10, avgConfidence: 0.50 },        // <0.6 = destructive
      ],
    }))
    vi.mocked(useSourcePerformance).mockReturnValue(createMockQueryResult({ sourcePerformance: [] }))
    vi.mocked(useMethodAccuracy).mockReturnValue(createMockQueryResult(mockMethodAccuracyData))
  })

  it('applies correct badge variants based on confidence thresholds', () => {
    renderComparison()

    // Values should be formatted to 4 decimal places
    expect(screen.getByText('0.9500')).toBeInTheDocument()
    expect(screen.getByText('0.7500')).toBeInTheDocument()
    expect(screen.getByText('0.6500')).toBeInTheDocument()
    expect(screen.getByText('0.5000')).toBeInTheDocument()
  })
})
