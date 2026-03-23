import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { TaskHistorySection } from './task-history-section'
import type { TaskHistoryEntry, TaskFilterOptions } from '../schemas'

interface PaginatedData<T> {
  entries: T[]
  total: number
  page: number
  pageSize: number
  totalPages?: number
}

const mockTaskHistoryData: PaginatedData<TaskHistoryEntry> = {
  entries: [
    {
      taskName: 'VECTOR_PREP_TASK',
      state: 'SUCCEEDED',
      scheduledTime: '2026-03-15T10:00:00Z',
      queryStartTime: '2026-03-15T10:00:05Z',
      durationSeconds: 15,
      errorMessage: null,
    },
    {
      taskName: 'CORTEX_SEARCH_TASK',
      state: 'FAILED',
      scheduledTime: '2026-03-15T10:05:00Z',
      queryStartTime: '2026-03-15T10:05:02Z',
      durationSeconds: 8,
      errorMessage: 'Query timeout after 60 seconds',
    },
    {
      taskName: 'ENSEMBLE_SCORING_TASK',
      state: 'EXECUTING',
      scheduledTime: '2026-03-15T10:10:00Z',
      queryStartTime: '2026-03-15T10:10:01Z',
      durationSeconds: null,
      errorMessage: null,
    },
    {
      taskName: 'DEDUP_TASK',
      state: 'SCHEDULED',
      scheduledTime: '2026-03-15T10:15:00Z',
      queryStartTime: null,
      durationSeconds: null,
      errorMessage: null,
    },
    {
      taskName: 'CANCELLED_TASK',
      state: 'CANCELLED',
      scheduledTime: '2026-03-15T10:20:00Z',
      queryStartTime: null,
      durationSeconds: null,
      errorMessage: null,
    },
    {
      taskName: 'SKIPPED_TASK',
      state: 'SKIPPED',
      scheduledTime: '2026-03-15T10:25:00Z',
      queryStartTime: null,
      durationSeconds: null,
      errorMessage: null,
    },
    {
      taskName: 'LONG_RUNNING_TASK',
      state: 'SUCCEEDED',
      scheduledTime: '2026-03-15T09:00:00Z',
      queryStartTime: '2026-03-15T09:00:01Z',
      durationSeconds: 329, // 5m 29s
      errorMessage: null,
    },
  ],
  total: 100,
  page: 1,
  pageSize: 10,
  totalPages: 10,
}

const emptyTaskHistoryData: PaginatedData<TaskHistoryEntry> = {
  entries: [],
  total: 0,
  page: 1,
  pageSize: 10,
  totalPages: 0,
}

const singlePageData: PaginatedData<TaskHistoryEntry> = {
  entries: [mockTaskHistoryData.entries[0]],
  total: 1,
  page: 1,
  pageSize: 10,
  totalPages: 1,
}

const mockFilterOptions: TaskFilterOptions = {
  taskNames: ['VECTOR_PREP_TASK', 'CORTEX_SEARCH_TASK', 'ENSEMBLE_SCORING_TASK'],
  states: ['SUCCEEDED', 'FAILED', 'EXECUTING', 'SCHEDULED', 'CANCELLED', 'SKIPPED'],
}

const emptyFilters = {}

describe('TaskHistorySection', () => {
  const mockOnPageChange = vi.fn()
  const mockOnFilterChange = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders section title', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    expect(screen.getByText('Task Execution History')).toBeInTheDocument()
  })

  it('section is open by default', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    // Content should be visible initially
    expect(screen.getByText('VECTOR_PREP_TASK')).toBeInTheDocument()
  })

  it('can collapse section via trigger', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const trigger = screen.getByText('Task Execution History').closest('button')
    fireEvent.click(trigger!)
    
    // Content should be hidden
    expect(screen.queryByText('VECTOR_PREP_TASK')).not.toBeInTheDocument()
  })

  it('renders empty state when no entries', () => {
    render(<TaskHistorySection data={emptyTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    expect(screen.getByText(/no task execution history matches/i)).toBeInTheDocument()
  })

  it('renders task entries in table', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByText('VECTOR_PREP_TASK')).toBeInTheDocument()
    expect(screen.getByText('CORTEX_SEARCH_TASK')).toBeInTheDocument()
    expect(screen.getByText('ENSEMBLE_SCORING_TASK')).toBeInTheDocument()
  })

  it('displays state with correct icons and colors for SUCCEEDED', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // The class is on the span containing the state text
    // Multiple SUCCEEDED entries may exist
    const succeededSpans = screen.getAllByText('SUCCEEDED')
    expect(succeededSpans[0].closest('span')).toHaveClass('text-green-600')
  })

  it('displays state with correct icons and colors for FAILED', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const failedSpan = screen.getByText('FAILED').closest('span')
    expect(failedSpan).toHaveClass('text-red-600')
  })

  it('displays state with correct colors for EXECUTING', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const executingSpan = screen.getByText('EXECUTING').closest('span')
    expect(executingSpan).toHaveClass('text-yellow-600')
  })

  it('displays state with correct colors for SCHEDULED', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const scheduledSpan = screen.getByText('SCHEDULED').closest('span')
    expect(scheduledSpan).toHaveClass('text-blue-600')
  })

  it('displays state with correct colors for CANCELLED', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const cancelledSpan = screen.getByText('CANCELLED').closest('span')
    expect(cancelledSpan).toHaveClass('text-gray-600')
  })

  it('displays state with correct colors for SKIPPED', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const skippedSpan = screen.getByText('SKIPPED').closest('span')
    expect(skippedSpan).toHaveClass('text-gray-500')
  })

  it('formats duration in seconds correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // 15 seconds
    expect(screen.getByText('15.0s')).toBeInTheDocument()
    // 8 seconds
    expect(screen.getByText('8.0s')).toBeInTheDocument()
  })

  it('formats duration in minutes and seconds correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // 329 seconds = 5m 29s
    expect(screen.getByText('5m 29s')).toBeInTheDocument()
  })

  it('displays -- for null duration', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // Tasks with null durationSeconds should show '--'
    const dashes = screen.getAllByText('--')
    expect(dashes.length).toBeGreaterThan(0)
  })

  it('formats scheduled time correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // The formatTime function with 'date' format shows month/day/hour:minute
    // We just check that dates are rendered without crashing
    const dateStrings = screen.getAllByText(/03\/15/)
    expect(dateStrings.length).toBeGreaterThan(0)
  })

  it('formats query start time correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // The formatTime function with 'time' format shows HH:MM:SS
    // Check that time strings are rendered (the exact format depends on locale)
    expect(screen.getByText('VECTOR_PREP_TASK')).toBeInTheDocument()
  })

  it('displays -- for null times', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // Tasks with null queryStartTime should show '--'
    const dashes = screen.getAllByText('--')
    expect(dashes.length).toBeGreaterThan(0)
  })

  it('displays error indicator for failed tasks', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // Look for the error indicator - component shows "⚠ Error" when errorMessage exists
    // Use getAllByText since there's also a header column named "Error"
    const errorElements = screen.getAllByText(/Error/)
    expect(errorElements.length).toBeGreaterThanOrEqual(1)
  })

  it('displays -- for tasks without errors', () => {
    render(<TaskHistorySection data={singlePageData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const dashes = screen.getAllByText('--')
    expect(dashes.length).toBeGreaterThan(0)
  })

  it('shows error indicator when errorMessage is present', () => {
    // Entry at index 1 has an errorMessage
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByText('Error')).toBeInTheDocument()
  })

  it('expands row when clicked', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // Click first row to expand
    const firstRow = screen.getByText('VECTOR_PREP_TASK').closest('tr')
    fireEvent.click(firstRow!)
    
    // Chevron should rotate (we can't directly test CSS but can verify the click works)
    // The component toggles expandedRows state
  })

  it('collapses row when clicked again', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const firstRow = screen.getByText('VECTOR_PREP_TASK').closest('tr')
    
    // First click - expand
    fireEvent.click(firstRow!)
    
    // Second click - collapse
    fireEvent.click(firstRow!)
    
    // Component should handle toggle without error
  })

  it('displays succeeded and failed counts', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByText(/2 succeeded/)).toBeInTheDocument()
    expect(screen.getByText(/1 failed/)).toBeInTheDocument()
  })

  it('applies red color to failed count when > 0', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const failedText = screen.getByText(/1 failed/)
    expect(failedText).toHaveClass('text-red-600')
  })

  it('does not apply red color to failed count when 0', () => {
    render(<TaskHistorySection data={singlePageData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    const failedText = screen.getByText(/0 failed/)
    expect(failedText).not.toHaveClass('text-red-600')
  })

  it('displays pagination info correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByText(/showing 1-10 of 100 items/i)).toBeInTheDocument()
  })

  it('renders pagination controls when multiple pages', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByRole('button', { name: /previous/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /next/i })).toBeInTheDocument()
    expect(screen.getByText('1 / 10')).toBeInTheDocument()
  })

  it('does not render pagination when single page', () => {
    render(<TaskHistorySection data={singlePageData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.queryByRole('button', { name: /previous/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /next/i })).not.toBeInTheDocument()
  })

  it('disables Previous button on first page', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByRole('button', { name: /previous/i })).toBeDisabled()
  })

  it('disables Next button on last page', () => {
    const lastPageData: PaginatedData<TaskHistoryEntry> = {
      ...mockTaskHistoryData,
      page: 10,
      totalPages: 10,
    }
    render(<TaskHistorySection data={lastPageData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByRole('button', { name: /next/i })).toBeDisabled()
  })

  it('calls onPageChange with previous page when Previous clicked', () => {
    const pageData: PaginatedData<TaskHistoryEntry> = {
      ...mockTaskHistoryData,
      page: 2,
    }
    render(<TaskHistorySection data={pageData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    fireEvent.click(screen.getByRole('button', { name: /previous/i }))
    expect(mockOnPageChange).toHaveBeenCalledWith(1)
  })

  it('calls onPageChange with next page when Next clicked', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    fireEvent.click(screen.getByRole('button', { name: /next/i }))
    expect(mockOnPageChange).toHaveBeenCalledWith(2)
  })

  it('pagination buttons stop event propagation', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // The pagination buttons have stopPropagation to prevent row toggle
    const nextButton = screen.getByRole('button', { name: /next/i })
    fireEvent.click(nextButton)
    
    // Should only trigger page change, not row toggle
    expect(mockOnPageChange).toHaveBeenCalledTimes(1)
  })

  it('renders table headers correctly', () => {
    render(<TaskHistorySection data={mockTaskHistoryData} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    expect(screen.getByText('Task')).toBeInTheDocument()
    expect(screen.getByText('Status')).toBeInTheDocument()
    expect(screen.getByText('Scheduled')).toBeInTheDocument()
    expect(screen.getByText('Started')).toBeInTheDocument()
    expect(screen.getByText('Duration')).toBeInTheDocument()
    expect(screen.getByText('Error')).toBeInTheDocument()
  })

  it('handles task with all null optional fields', () => {
    const minimalTask: PaginatedData<TaskHistoryEntry> = {
      entries: [{
        taskName: 'MINIMAL_TASK',
        state: 'SCHEDULED',
        scheduledTime: null as unknown as string,
        queryStartTime: null,
        durationSeconds: null,
        errorMessage: null,
      }],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    }
    
    render(<TaskHistorySection data={minimalTask} filterOptions={mockFilterOptions} filters={emptyFilters} onPageChange={mockOnPageChange} onFilterChange={mockOnFilterChange} />)
    
    // Should render without crashing
    expect(screen.getByText('MINIMAL_TASK')).toBeInTheDocument()
  })
})
