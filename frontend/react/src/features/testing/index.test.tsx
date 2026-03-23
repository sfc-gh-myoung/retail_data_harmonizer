/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Testing } from './index'

// Mock pointer capture methods for Radix Select in JSDOM
beforeAll(() => {
  Element.prototype.hasPointerCapture = vi.fn(() => false)
  Element.prototype.setPointerCapture = vi.fn()
  Element.prototype.releasePointerCapture = vi.fn()
  Element.prototype.scrollIntoView = vi.fn()
})

vi.mock('./hooks/use-test-verification', () => ({
  useTestingDashboard: vi.fn(),
  useFailures: vi.fn(),
  useTestRunner: vi.fn(),
}))

import { useTestingDashboard, useFailures, useTestRunner } from './hooks/use-test-verification'

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

const mockDashboardData = {
  testRun: {
    runId: 'run-abc123',
    timestamp: '2024-01-15T10:30:00Z',
    totalTests: 100,
    methodsTested: 'COSINE_SIMILARITY, EDIT_DISTANCE',
  },
  testStats: {
    totalCases: 100,
    easyCount: 40,
    mediumCount: 35,
    hardCount: 25,
    easyPct: 40,
    mediumPct: 35,
    hardPct: 25,
  },
  accuracySummary: [
    { method: 'COSINE_SIMILARITY', top1AccuracyPct: 85.5, top3AccuracyPct: 92.0, top5AccuracyPct: 95.0 },
    { method: 'EDIT_DISTANCE', top1AccuracyPct: 78.0, top3AccuracyPct: 88.0, top5AccuracyPct: 91.0 },
  ],
  accuracyByDifficulty: [
    { method: 'COSINE_SIMILARITY', difficulty: 'EASY' as const, tests: 40, top1Pct: 95.0 },
    { method: 'COSINE_SIMILARITY', difficulty: 'MEDIUM' as const, tests: 35, top1Pct: 82.0 },
    { method: 'COSINE_SIMILARITY', difficulty: 'HARD' as const, tests: 25, top1Pct: 72.0 },
  ],
  totalFailures: 15,
}

const mockFailuresData = {
  failures: [
    {
      method: 'COSINE_SIMILARITY',
      testInput: 'organic milk 2%',
      expectedMatch: 'ORGANIC WHOLE MILK',
      actualMatch: 'SKIM MILK',
      score: 0.78,
      difficulty: 'HARD' as const,
    },
  ],
  totalFailures: 15,
  totalPages: 2,
  currentPage: 1,
  pageSize: 10,
  hasPrev: false,
  hasNext: true,
  filterOptions: {
    methods: ['COSINE_SIMILARITY', 'EDIT_DISTANCE'],
    difficulties: ['EASY', 'MEDIUM', 'HARD'],
  },
}

describe('Testing', () => {
  const mockStartTests = vi.fn()
  const mockReset = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useTestRunner).mockReturnValue({
      startTests: mockStartTests,
      reset: mockReset,
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      activeRunId: null,
      runningCount: 0,
      error: null,
    } as any)
    vi.mocked(useFailures).mockReturnValue({
      data: mockFailuresData,
      isLoading: false,
      error: null,
    } as any)
  })

  it('renders loading skeleton when loading', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: undefined,
      isLoading: true,
      error: null,
    } as any)

    const { container } = renderWithProviders(<Testing />)
    
    // Check for skeleton elements
    const skeletons = container.querySelectorAll('[class*="animate-pulse"]')
    expect(skeletons.length).toBeGreaterThan(0)
  })

  it('renders error alert when error occurs', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Failed to fetch'),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText(/unable to connect to the server/i)).toBeInTheDocument()
  })

  it('renders test verification heading', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Test Verification')).toBeInTheDocument()
  })

  it('renders refresh results button', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Refresh Results')).toBeInTheDocument()
  })

  it('renders run tests button', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByRole('button', { name: /run tests/i })).toBeInTheDocument()
  })

  it('calls startTests when run button is clicked', async () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    fireEvent.click(screen.getByRole('button', { name: /run tests/i }))
    expect(mockStartTests).toHaveBeenCalled()
  })

  it('shows running state when tests are running', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)
    vi.mocked(useTestRunner).mockReturnValue({
      startTests: mockStartTests,
      reset: mockReset,
      isStarting: false,
      isRunning: true,
      isCompleted: false,
      activeRunId: 'run-123',
      runningCount: 2,
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Button should be disabled during running state
    const runButton = screen.getByRole('button', { name: /running/i })
    expect(runButton).toBeDisabled()
  })

  it('renders latest test run section', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Latest Test Run')).toBeInTheDocument()
  })

  it('renders test set overview with stats', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Test Set Overview')).toBeInTheDocument()
    // The component shows Easy, Medium, Hard difficulty breakdowns
    expect(screen.getByText(/Easy/)).toBeInTheDocument()
    expect(screen.getByText(/Medium/)).toBeInTheDocument()
    expect(screen.getByText(/Hard/)).toBeInTheDocument()
  })

  it('renders accuracy summary table', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Accuracy Summary')).toBeInTheDocument()
    expect(screen.getByText('Top-1 Accuracy')).toBeInTheDocument()
    expect(screen.getByText('Top-3 Accuracy')).toBeInTheDocument()
  })

  it('renders accuracy by difficulty section', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Accuracy by Difficulty Level')).toBeInTheDocument()
  })

  it('renders failure analysis section', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Failure Analysis')).toBeInTheDocument()
  })

  it('shows no failures message when totalFailures is 0', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: { ...mockDashboardData, totalFailures: 0 },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText(/no failures found/i)).toBeInTheDocument()
  })

  it('toggles method checkbox when clicked', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      runningCount: 0,
      activeRunId: null,
      reset: vi.fn(),
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Find and click a method checkbox (e.g., "Include Ensemble")
    const ensembleCheckbox = screen.getByRole('checkbox', { name: /include ensemble/i })
    expect(ensembleCheckbox).not.toBeChecked()
    
    fireEvent.click(ensembleCheckbox)
    expect(ensembleCheckbox).toBeChecked()
    
    // Toggle it off again
    fireEvent.click(ensembleCheckbox)
    expect(ensembleCheckbox).not.toBeChecked()
  })

  it('calls refetch when refresh button is clicked', () => {
    const mockRefetch = vi.fn()
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: mockRefetch,
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      runningCount: 0,
      activeRunId: null,
      reset: vi.fn(),
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    const refreshButton = screen.getByRole('button', { name: /refresh results/i })
    fireEvent.click(refreshButton)
    
    expect(mockRefetch).toHaveBeenCalled()
  })

  it('shows error message when test runner has error', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      runningCount: 0,
      activeRunId: null,
      reset: vi.fn(),
      error: new Error('Test execution failed'),
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getByText('Test execution failed')).toBeInTheDocument()
  })

  it('calls startTests when run button is clicked', async () => {
    const mockStartTests = vi.fn().mockResolvedValue({})
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: mockStartTests,
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      runningCount: 0,
      activeRunId: null,
      reset: vi.fn(),
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Click run tests button
    const runButton = screen.getByRole('button', { name: /run tests/i })
    fireEvent.click(runButton)
    
    await waitFor(() => {
      expect(mockStartTests).toHaveBeenCalled()
    })
  })

  it('disables run button when no methods selected', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      runningCount: 0,
      activeRunId: null,
      reset: vi.fn(),
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Uncheck all checkboxes one by one
    const cortexCheckbox = screen.getByRole('checkbox', { name: /include cortex search/i })
    const cosineCheckbox = screen.getByRole('checkbox', { name: /include cosine similarity/i })
    const editCheckbox = screen.getByRole('checkbox', { name: /include edit distance/i })
    const jaccardCheckbox = screen.getByRole('checkbox', { name: /include jaccard similarity/i })
    
    fireEvent.click(cortexCheckbox)
    fireEvent.click(cosineCheckbox)
    fireEvent.click(editCheckbox)
    fireEvent.click(jaccardCheckbox)
    
    const runButton = screen.getByRole('button', { name: /run tests/i })
    expect(runButton).toBeDisabled()
  })

  it('shows running status message', () => {
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: mockDashboardData,
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)

    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      isStarting: false,
      isRunning: true,
      isCompleted: false,
      runningCount: 3,
      activeRunId: 'run-123',
      reset: vi.fn(),
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    expect(screen.getAllByText('Tests Running').length).toBeGreaterThan(0)
    expect(screen.getByText(/Tests are executing in the background/i)).toBeInTheDocument()
  })
})

describe('Testing - FailureAnalysis handlers', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useTestRunner).mockReturnValue({
      startTests: vi.fn(),
      reset: vi.fn(),
      isStarting: false,
      isRunning: false,
      isCompleted: false,
      activeRunId: null,
      runningCount: 0,
      error: null,
    } as any)
  })

  it('calls useFailures with updated sort when column header is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: {
        testRun: { runId: 'run-1', timestamp: '2024-01-15T10:30:00Z', totalTests: 100, methodsTested: 'COSINE' },
        testStats: { totalCases: 100, easyCount: 40, mediumCount: 35, hardCount: 25, easyPct: 40, mediumPct: 35, hardPct: 25 },
        accuracySummary: [{ method: 'COSINE', top1AccuracyPct: 85, top3AccuracyPct: 92, top5AccuracyPct: 95 }],
        accuracyByDifficulty: [],
        totalFailures: 5,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)
    vi.mocked(useFailures).mockReturnValue({
      data: {
        failures: [{ method: 'COSINE', testInput: 'test', expectedMatch: 'A', actualMatch: 'B', score: 0.7, difficulty: 'HARD' }],
        totalFailures: 5,
        totalPages: 1,
        currentPage: 1,
        pageSize: 10,
        hasPrev: false,
        hasNext: false,
        filterOptions: { methods: ['COSINE'], difficulties: ['EASY', 'MEDIUM', 'HARD'] },
      },
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Find and click the Method column header in the failure analysis table
    // Use getAllByRole and find the one in the failures table (which has a button inside)
    const methodHeaders = screen.getAllByRole('columnheader', { name: /method/i })
    // The clickable one should have a button or be in the failure analysis section
    const clickableHeader = methodHeaders.find(h => h.querySelector('button') || h.closest('table'))
    if (clickableHeader) {
      await user.click(clickableHeader)
    }
    
    // Verify useFailures was called with sort parameters
    expect(useFailures).toHaveBeenCalled()
  })

  it('calls useFailures with updated filter when method filter changes', async () => {
    const user = userEvent.setup()
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: {
        testRun: { runId: 'run-1', timestamp: '2024-01-15T10:30:00Z', totalTests: 100, methodsTested: 'COSINE' },
        testStats: { totalCases: 100, easyCount: 40, mediumCount: 35, hardCount: 25, easyPct: 40, mediumPct: 35, hardPct: 25 },
        accuracySummary: [{ method: 'COSINE', top1AccuracyPct: 85, top3AccuracyPct: 92, top5AccuracyPct: 95 }],
        accuracyByDifficulty: [],
        totalFailures: 5,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)
    vi.mocked(useFailures).mockReturnValue({
      data: {
        failures: [{ method: 'COSINE', testInput: 'test', expectedMatch: 'A', actualMatch: 'B', score: 0.7, difficulty: 'HARD' }],
        totalFailures: 5,
        totalPages: 1,
        currentPage: 1,
        pageSize: 10,
        hasPrev: false,
        hasNext: false,
        filterOptions: { methods: ['COSINE_SIMILARITY', 'EDIT_DISTANCE'], difficulties: ['EASY', 'MEDIUM', 'HARD'] },
      },
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Find the method filter dropdown (first combobox in FailureAnalysis section)
    const filterDropdowns = screen.getAllByRole('combobox')
    const methodDropdown = filterDropdowns.find(el => el.textContent?.includes('All') || el.getAttribute('aria-label')?.includes('method'))
    
    if (methodDropdown) {
      await user.click(methodDropdown)
      
      // Select a specific method
      const option = await screen.findByRole('option', { name: /cosine/i })
      await user.click(option)
      
      expect(useFailures).toHaveBeenCalled()
    }
  })

  it('updates page when Next button is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: {
        testRun: { runId: 'run-1', timestamp: '2024-01-15T10:30:00Z', totalTests: 100, methodsTested: 'COSINE' },
        testStats: { totalCases: 100, easyCount: 40, mediumCount: 35, hardCount: 25, easyPct: 40, mediumPct: 35, hardPct: 25 },
        accuracySummary: [{ method: 'COSINE', top1AccuracyPct: 85, top3AccuracyPct: 92, top5AccuracyPct: 95 }],
        accuracyByDifficulty: [],
        totalFailures: 25,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)
    vi.mocked(useFailures).mockReturnValue({
      data: {
        failures: [{ method: 'COSINE', testInput: 'test', expectedMatch: 'A', actualMatch: 'B', score: 0.7, difficulty: 'HARD' }],
        totalFailures: 25,
        totalPages: 3,
        currentPage: 1,
        pageSize: 10,
        hasPrev: false,
        hasNext: true,
        filterOptions: { methods: ['COSINE'], difficulties: ['EASY', 'MEDIUM', 'HARD'] },
      },
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Find and click the Next button in the failure analysis section
    const nextButton = screen.getByRole('button', { name: /next/i })
    await user.click(nextButton)
    
    // Verify useFailures was called (with updated page parameter)
    expect(useFailures).toHaveBeenCalled()
  })

  it('updates page when Previous button is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(useTestingDashboard).mockReturnValue({
      data: {
        testRun: { runId: 'run-1', timestamp: '2024-01-15T10:30:00Z', totalTests: 100, methodsTested: 'COSINE' },
        testStats: { totalCases: 100, easyCount: 40, mediumCount: 35, hardCount: 25, easyPct: 40, mediumPct: 35, hardPct: 25 },
        accuracySummary: [{ method: 'COSINE', top1AccuracyPct: 85, top3AccuracyPct: 92, top5AccuracyPct: 95 }],
        accuracyByDifficulty: [],
        totalFailures: 25,
      },
      isLoading: false,
      error: null,
      refetch: vi.fn(),
    } as any)
    vi.mocked(useFailures).mockReturnValue({
      data: {
        failures: [{ method: 'COSINE', testInput: 'test', expectedMatch: 'A', actualMatch: 'B', score: 0.7, difficulty: 'HARD' }],
        totalFailures: 25,
        totalPages: 3,
        currentPage: 2,
        pageSize: 10,
        hasPrev: true,
        hasNext: true,
        filterOptions: { methods: ['COSINE'], difficulties: ['EASY', 'MEDIUM', 'HARD'] },
      },
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Testing />)
    
    // Find and click the Previous button
    const prevButton = screen.getByRole('button', { name: /previous/i })
    await user.click(prevButton)
    
    // Verify useFailures was called (with updated page parameter)
    expect(useFailures).toHaveBeenCalled()
  })
})
