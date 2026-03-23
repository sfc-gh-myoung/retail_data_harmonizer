/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeAll } from 'vitest'
import { DataTablePagination, DataTablePaginationSimple } from './data-table-pagination'

// Mock pointer capture methods for Radix Select in JSDOM
beforeAll(() => {
  Element.prototype.hasPointerCapture = vi.fn(() => false)
  Element.prototype.setPointerCapture = vi.fn()
  Element.prototype.releasePointerCapture = vi.fn()
  Element.prototype.scrollIntoView = vi.fn()
})

// Create a mock table object that mimics TanStack Table API
function createMockTable(overrides = {}) {
  return {
    getFilteredSelectedRowModel: vi.fn(() => ({ rows: [] })),
    getFilteredRowModel: vi.fn(() => ({ rows: Array(100).fill({}) })),
    getState: vi.fn(() => ({
      pagination: { pageIndex: 0, pageSize: 10 },
    })),
    setPageSize: vi.fn(),
    setPageIndex: vi.fn(),
    getPageCount: vi.fn(() => 10),
    getCanPreviousPage: vi.fn(() => false),
    getCanNextPage: vi.fn(() => true),
    previousPage: vi.fn(),
    nextPage: vi.fn(),
    ...overrides,
  }
}

describe('DataTablePagination', () => {
  it('renders row selection count', () => {
    const table = createMockTable({
      getFilteredSelectedRowModel: vi.fn(() => ({ rows: [1, 2, 3] })),
      getFilteredRowModel: vi.fn(() => ({ rows: Array(50).fill({}) })),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByText(/3 of 50 row\(s\) selected/)).toBeInTheDocument()
  })

  it('renders page info', () => {
    const table = createMockTable()
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByText(/Page 1 of 10/)).toBeInTheDocument()
  })

  it('renders rows per page selector', () => {
    const table = createMockTable()
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByText('Rows per page')).toBeInTheDocument()
  })

  it('renders navigation buttons', () => {
    const table = createMockTable()
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByRole('button', { name: /go to first page/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /go to previous page/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /go to next page/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /go to last page/i })).toBeInTheDocument()
  })

  it('disables previous buttons on first page', () => {
    const table = createMockTable({
      getCanPreviousPage: vi.fn(() => false),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByRole('button', { name: /go to first page/i })).toBeDisabled()
    expect(screen.getByRole('button', { name: /go to previous page/i })).toBeDisabled()
  })

  it('disables next buttons on last page', () => {
    const table = createMockTable({
      getCanNextPage: vi.fn(() => false),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    expect(screen.getByRole('button', { name: /go to next page/i })).toBeDisabled()
    expect(screen.getByRole('button', { name: /go to last page/i })).toBeDisabled()
  })

  it('calls nextPage when next button clicked', () => {
    const table = createMockTable()
    
    render(<DataTablePagination table={table as any} />)
    
    fireEvent.click(screen.getByRole('button', { name: /go to next page/i }))
    expect(table.nextPage).toHaveBeenCalled()
  })

  it('calls previousPage when previous button clicked', () => {
    const table = createMockTable({
      getCanPreviousPage: vi.fn(() => true),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    fireEvent.click(screen.getByRole('button', { name: /go to previous page/i }))
    expect(table.previousPage).toHaveBeenCalled()
  })

  it('calls setPageIndex(0) when first page button clicked', () => {
    const table = createMockTable({
      getCanPreviousPage: vi.fn(() => true),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    fireEvent.click(screen.getByRole('button', { name: /go to first page/i }))
    expect(table.setPageIndex).toHaveBeenCalledWith(0)
  })

  it('calls setPageIndex with last page when last page button clicked', () => {
    const table = createMockTable({
      getPageCount: vi.fn(() => 5),
    })
    
    render(<DataTablePagination table={table as any} />)
    
    fireEvent.click(screen.getByRole('button', { name: /go to last page/i }))
    expect(table.setPageIndex).toHaveBeenCalledWith(4)
  })

  it('calls setPageSize when rows per page is changed', async () => {
    const user = userEvent.setup()
    const table = createMockTable()
    
    render(<DataTablePagination table={table as any} />)
    
    // Open the page size select dropdown
    const trigger = screen.getByRole('combobox')
    await user.click(trigger)
    
    // Select 25 rows per page
    const option25 = await screen.findByRole('option', { name: '25' })
    await user.click(option25)
    
    expect(table.setPageSize).toHaveBeenCalledWith(25)
  })
})

describe('DataTablePaginationSimple', () => {
  it('does not render row selection count', () => {
    const table = createMockTable()
    
    render(<DataTablePaginationSimple table={table as any} />)
    
    expect(screen.queryByText(/row\(s\) selected/)).not.toBeInTheDocument()
  })

  it('renders page info', () => {
    const table = createMockTable()
    
    render(<DataTablePaginationSimple table={table as any} />)
    
    expect(screen.getByText(/Page 1 of 10/)).toBeInTheDocument()
  })

  it('renders navigation buttons', () => {
    const table = createMockTable()
    
    render(<DataTablePaginationSimple table={table as any} />)
    
    expect(screen.getByRole('button', { name: /go to next page/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /go to previous page/i })).toBeInTheDocument()
  })

  it('calls setPageSize when rows per page is changed', async () => {
    const user = userEvent.setup()
    const table = createMockTable()
    
    render(<DataTablePaginationSimple table={table as any} />)
    
    // Open the page size select dropdown
    const trigger = screen.getByRole('combobox')
    await user.click(trigger)
    
    // Select 50 rows per page
    const option50 = await screen.findByRole('option', { name: '50' })
    await user.click(option50)
    
    expect(table.setPageSize).toHaveBeenCalledWith(50)
  })
})
