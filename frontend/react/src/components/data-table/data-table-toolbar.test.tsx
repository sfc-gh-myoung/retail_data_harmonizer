/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { DataTableToolbar } from './data-table-toolbar'

function createMockTable(columnFilters: any[] = []) {
  return {
    getState: vi.fn(() => ({
      columnFilters,
    })),
    resetColumnFilters: vi.fn(),
  }
}

describe('DataTableToolbar', () => {
  it('renders children', () => {
    const table = createMockTable()
    
    render(
      <DataTableToolbar table={table as any}>
        <button>Filter Button</button>
      </DataTableToolbar>
    )
    
    expect(screen.getByRole('button', { name: 'Filter Button' })).toBeInTheDocument()
  })

  it('does not show reset button when no filters', () => {
    const table = createMockTable([])
    
    render(<DataTableToolbar table={table as any} />)
    
    expect(screen.queryByRole('button', { name: /reset/i })).not.toBeInTheDocument()
  })

  it('shows reset button when filters are active', () => {
    const table = createMockTable([{ id: 'status', value: 'active' }])
    
    render(<DataTableToolbar table={table as any} />)
    
    expect(screen.getByRole('button', { name: /reset/i })).toBeInTheDocument()
  })

  it('calls resetColumnFilters when reset is clicked', () => {
    const table = createMockTable([{ id: 'status', value: 'active' }])
    
    render(<DataTableToolbar table={table as any} />)
    
    fireEvent.click(screen.getByRole('button', { name: /reset/i }))
    
    expect(table.resetColumnFilters).toHaveBeenCalled()
  })
})
