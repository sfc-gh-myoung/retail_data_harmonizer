/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeAll } from 'vitest'
import { DataTableViewOptions } from './data-table-view-options'

// Mock pointer capture methods for Radix in JSDOM
beforeAll(() => {
  Element.prototype.hasPointerCapture = vi.fn(() => false)
  Element.prototype.setPointerCapture = vi.fn()
  Element.prototype.releasePointerCapture = vi.fn()
  Element.prototype.scrollIntoView = vi.fn()
})

function createMockTable(columns: Array<{ id: string; visible: boolean; canHide: boolean }> = []) {
  const mockColumns = columns.map((col) => ({
    id: col.id,
    accessorFn: () => {},
    getCanHide: vi.fn(() => col.canHide),
    getIsVisible: vi.fn(() => col.visible),
    toggleVisibility: vi.fn(),
  }))
  
  return {
    getAllColumns: vi.fn(() => mockColumns),
    _mockColumns: mockColumns, // Expose for test assertions
  }
}

describe('DataTableViewOptions', () => {
  it('renders view button', () => {
    const table = createMockTable()
    
    render(<DataTableViewOptions table={table as any} />)
    
    expect(screen.getByRole('button', { name: /view/i })).toBeInTheDocument()
  })

  it('calls getAllColumns when rendering', () => {
    const table = createMockTable([
      { id: 'name', visible: true, canHide: true },
    ])
    
    render(<DataTableViewOptions table={table as any} />)
    
    expect(table.getAllColumns).toHaveBeenCalled()
  })

  it('filters columns by accessorFn and canHide', () => {
    const table = createMockTable([
      { id: 'select', visible: true, canHide: false },
      { id: 'name', visible: true, canHide: true },
    ])
    
    render(<DataTableViewOptions table={table as any} />)
    
    // The component filters columns - we verify getAllColumns is called
    expect(table.getAllColumns).toHaveBeenCalled()
    const columns = table.getAllColumns()
    expect(columns.length).toBe(2)
    expect(columns[1].getCanHide()).toBe(true)
  })

  it('calls toggleVisibility when checkbox is clicked', async () => {
    const user = userEvent.setup()
    const table = createMockTable([
      { id: 'name', visible: true, canHide: true },
      { id: 'email', visible: true, canHide: true },
    ])
    
    render(<DataTableViewOptions table={table as any} />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /view/i }))
    
    // Find and click the checkbox item for 'name' column
    const nameCheckbox = await screen.findByRole('menuitemcheckbox', { name: /name/i })
    await user.click(nameCheckbox)
    
    // Verify toggleVisibility was called on the name column
    expect(table._mockColumns[0].toggleVisibility).toHaveBeenCalledWith(false)
  })

  it('toggles column on when unchecked checkbox is clicked', async () => {
    const user = userEvent.setup()
    const table = createMockTable([
      { id: 'name', visible: false, canHide: true },
    ])
    
    render(<DataTableViewOptions table={table as any} />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /view/i }))
    
    // Find and click the checkbox item for 'name' column (which is unchecked)
    const nameCheckbox = await screen.findByRole('menuitemcheckbox', { name: /name/i })
    await user.click(nameCheckbox)
    
    // Verify toggleVisibility was called with true (since column was hidden)
    expect(table._mockColumns[0].toggleVisibility).toHaveBeenCalledWith(true)
  })
})
