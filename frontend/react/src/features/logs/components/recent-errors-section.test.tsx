import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { RecentErrorsSection } from './recent-errors-section'
import type { RecentError } from '../schemas'

interface PaginatedErrorsData {
  errors: RecentError[]
  total: number
  page: number
  pageSize: number
  totalPages?: number
}

const mockErrorsData: PaginatedErrorsData = {
  errors: [
    {
      logId: 'err-1',
      runId: 'run-123',
      stepName: 'CORTEX_SEARCH',
      category: 'MATCH',
      errorMessage: 'Query timeout after 60 seconds',
      itemsFailed: 5,
      queryId: 'query-abc123',
      createdAt: '2026-03-15T10:05:00',
    },
    {
      logId: 'err-2',
      runId: 'run-456',
      stepName: 'VECTOR_PREP',
      category: 'DEDUP',
      errorMessage: 'This is a very long error message that should be truncated when displayed in the table row because it exceeds the maximum character limit of 80 characters and needs ellipsis',
      itemsFailed: 100,
      queryId: 'query-def456',
      createdAt: '2026-03-15T11:15:00',
    },
    {
      logId: 'err-3',
      runId: 'run-789',
      stepName: 'ENSEMBLE_SCORING',
      category: null,
      errorMessage: null,
      itemsFailed: 0,
      queryId: null,
      createdAt: '2026-03-15T12:30:00',
    },
  ],
  total: 75,
  page: 1,
  pageSize: 25,
  totalPages: 3,
}

const emptyErrorsData: PaginatedErrorsData = {
  errors: [],
  total: 0,
  page: 1,
  pageSize: 25,
  totalPages: 0,
}

const singlePageData: PaginatedErrorsData = {
  errors: [mockErrorsData.errors[0]],
  total: 1,
  page: 1,
  pageSize: 25,
  totalPages: 1,
}

describe('RecentErrorsSection', () => {
  const mockOnPageChange = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders section title', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    expect(screen.getByText('Recent Errors')).toBeInTheDocument()
  })

  it('shows total errors count badge with destructive variant', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    expect(screen.getByText('75 errors')).toBeInTheDocument()
  })

  it('does not show badge when total is 0', () => {
    render(<RecentErrorsSection data={emptyErrorsData} onPageChange={mockOnPageChange} />)
    expect(screen.queryByText(/errors/)).not.toBeInTheDocument()
  })

  it('renders empty state when no entries', () => {
    render(<RecentErrorsSection data={emptyErrorsData} onPageChange={mockOnPageChange} />)
    
    // Need to expand the section first (it starts collapsed)
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText(/no errors in the last 7 days/i)).toBeInTheDocument()
  })

  it('section starts collapsed by default', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    // Content should not be visible initially
    expect(screen.queryByText('CORTEX_SEARCH')).not.toBeInTheDocument()
  })

  it('expands section when trigger clicked', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('CORTEX_SEARCH')).toBeInTheDocument()
    expect(screen.getByText('VECTOR_PREP')).toBeInTheDocument()
  })

  it('renders error entries in table', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('CORTEX_SEARCH')).toBeInTheDocument()
    expect(screen.getByText('VECTOR_PREP')).toBeInTheDocument()
    expect(screen.getByText('ENSEMBLE_SCORING')).toBeInTheDocument()
  })

  it('displays category or dash for null category', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('MATCH')).toBeInTheDocument()
    expect(screen.getByText('DEDUP')).toBeInTheDocument()
    // Null category shows dash
    const cells = screen.getAllByRole('cell')
    const dashCells = cells.filter(cell => cell.textContent === '—')
    expect(dashCells.length).toBeGreaterThan(0)
  })

  it('truncates long error messages in table row', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // The long error message should be truncated with ellipsis
    expect(screen.getByText(/This is a very long error message/)).toBeInTheDocument()
    expect(screen.getByText(/\.\.\./)).toBeInTheDocument()
  })

  it('displays "Unknown error" for null error message', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('Unknown error')).toBeInTheDocument()
  })

  it('displays items failed count', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText('100')).toBeInTheDocument()
    expect(screen.getByText('0')).toBeInTheDocument()
  })

  it('displays query ID or dash for null', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('query-abc123')).toBeInTheDocument()
    expect(screen.getByText('query-def456')).toBeInTheDocument()
  })

  it('expands row when clicked to show full error', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Click first row to expand
    const firstRow = screen.getByText('CORTEX_SEARCH').closest('tr')
    fireEvent.click(firstRow!)
    
    // Should show expanded details
    expect(screen.getByText('Full Error Message')).toBeInTheDocument()
    // Use getAllByText since the error message appears in both table cell and expanded view
    const errorMessages = screen.getAllByText('Query timeout after 60 seconds')
    expect(errorMessages.length).toBeGreaterThanOrEqual(1)
  })

  it('shows query details in expanded view', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Click first row
    const firstRow = screen.getByText('CORTEX_SEARCH').closest('tr')
    fireEvent.click(firstRow!)
    
    // Should show query details
    expect(screen.getByText('Query ID:')).toBeInTheDocument()
    expect(screen.getByText('Step:')).toBeInTheDocument()
    expect(screen.getByText('Category:')).toBeInTheDocument()
    expect(screen.getByText('Items Failed:')).toBeInTheDocument()
  })

  it('does not show query details section when queryId is null', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Click third row with null queryId
    const rows = screen.getAllByRole('row')
    const thirdDataRow = rows[3]
    fireEvent.click(thirdDataRow)
    
    // Query details section should not be rendered
    const queryIdLabels = screen.queryAllByText('Query ID:')
    expect(queryIdLabels.length).toBe(0)
  })

  it('collapses row when clicked again', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    const firstRow = screen.getByText('CORTEX_SEARCH').closest('tr')
    
    // Expand
    fireEvent.click(firstRow!)
    expect(screen.getByText('Full Error Message')).toBeInTheDocument()
    
    // Collapse
    fireEvent.click(firstRow!)
    expect(screen.queryByText('Full Error Message')).not.toBeInTheDocument()
  })

  it('displays pagination info correctly', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText(/showing 1-25 of 75 errors/i)).toBeInTheDocument()
  })

  it('renders pagination controls when multiple pages', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByRole('button', { name: /previous/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /next/i })).toBeInTheDocument()
    expect(screen.getByText('1 / 3')).toBeInTheDocument()
  })

  it('does not render pagination when single page', () => {
    render(<RecentErrorsSection data={singlePageData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.queryByRole('button', { name: /previous/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /next/i })).not.toBeInTheDocument()
  })

  it('disables Previous button on first page', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByRole('button', { name: /previous/i })).toBeDisabled()
  })

  it('disables Next button on last page', () => {
    const lastPageData: PaginatedErrorsData = {
      ...mockErrorsData,
      page: 3,
      totalPages: 3,
    }
    render(<RecentErrorsSection data={lastPageData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByRole('button', { name: /next/i })).toBeDisabled()
  })

  it('calls onPageChange with previous page when Previous clicked', () => {
    const pageData: PaginatedData<RecentError> = {
      ...mockErrorsData,
      page: 2,
    }
    render(<RecentErrorsSection data={pageData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    fireEvent.click(screen.getByRole('button', { name: /previous/i }))
    expect(mockOnPageChange).toHaveBeenCalledWith(1)
  })

  it('calls onPageChange with next page when Next clicked', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    fireEvent.click(screen.getByRole('button', { name: /next/i }))
    expect(mockOnPageChange).toHaveBeenCalledWith(2)
  })

  it('formats createdAt timestamp correctly', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Component slices first 16 characters
    expect(screen.getByText('2026-03-15T10:05')).toBeInTheDocument()
  })

  it('handles entry with empty createdAt', () => {
    const dataWithEmptyDate: PaginatedErrorsData = {
      ...singlePageData,
      errors: [{
        ...singlePageData.errors[0],
        createdAt: null as unknown as string,
      }],
    }
    
    render(<RecentErrorsSection data={dataWithEmptyDate} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Should not crash
    expect(screen.getByText('CORTEX_SEARCH')).toBeInTheDocument()
  })

  it('renders table headers correctly', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    expect(screen.getByText('Time')).toBeInTheDocument()
    expect(screen.getByText('Step')).toBeInTheDocument()
    expect(screen.getByText('Category')).toBeInTheDocument()
    expect(screen.getByText('Error Message')).toBeInTheDocument()
    expect(screen.getByText('Items Failed')).toBeInTheDocument()
    expect(screen.getByText('Query ID')).toBeInTheDocument()
  })

  it('shows full error message in expanded view for long messages', () => {
    render(<RecentErrorsSection data={mockErrorsData} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Click second row with long error
    const vectorRow = screen.getByText('VECTOR_PREP').closest('tr')
    fireEvent.click(vectorRow!)
    
    // Full error should be visible in the pre element
    const preElement = screen.getByText(/This is a very long error message that should be truncated when displayed in the table row/)
    expect(preElement.tagName).toBe('PRE')
  })

  it('displays 0 for null itemsFailed', () => {
    const dataWithNullItems: PaginatedErrorsData = {
      errors: [{
        ...mockErrorsData.errors[0],
        itemsFailed: null as unknown as number,
      }],
      total: 1,
      page: 1,
      pageSize: 25,
      totalPages: 1,
    }
    
    render(<RecentErrorsSection data={dataWithNullItems} onPageChange={mockOnPageChange} />)
    
    const trigger = screen.getByText('Recent Errors').closest('button')
    fireEvent.click(trigger!)
    
    // Should display 0 for null
    expect(screen.getByText('0')).toBeInTheDocument()
  })
})
