import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeAll } from 'vitest'
import { ActionCell } from './action-cell'

describe('ActionCell', () => {
  beforeAll(() => {
    // JSDOM mocks for Radix DropdownMenu
    Element.prototype.hasPointerCapture = vi.fn(() => false)
    Element.prototype.setPointerCapture = vi.fn()
    Element.prototype.releasePointerCapture = vi.fn()
    Element.prototype.scrollIntoView = vi.fn()
  })

  it('renders trigger button', () => {
    const actions = [{ label: 'Edit', onClick: vi.fn() }]
    
    render(<ActionCell row={{ id: '1' }} actions={actions} />)
    
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('renders with multiple actions', () => {
    const actions = [
      { label: 'Edit', onClick: vi.fn() },
      { label: 'Delete', onClick: vi.fn() },
    ]
    
    render(<ActionCell row={{ id: '1' }} actions={actions} />)
    
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('renders with destructive variant action', () => {
    const actions = [
      { label: 'Delete', onClick: vi.fn(), variant: 'destructive' as const },
    ]
    
    render(<ActionCell row={{ id: '1' }} actions={actions} />)
    
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('renders with separator between actions', () => {
    const actions = [
      { label: 'Edit', onClick: vi.fn() },
      { label: 'Delete', onClick: vi.fn(), separator: true },
    ]
    
    render(<ActionCell row={{ id: '1' }} actions={actions} />)
    
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('calls onClick with row data when action is clicked', async () => {
    const user = userEvent.setup()
    const mockOnClick = vi.fn()
    const rowData = { id: '1', name: 'Test Item' }
    const actions = [{ label: 'Edit', onClick: mockOnClick }]
    
    render(<ActionCell row={rowData} actions={actions} />)
    
    // Open the dropdown menu
    await user.click(screen.getByRole('button', { name: /open menu/i }))
    
    // Click the Edit action
    const editItem = await screen.findByRole('menuitem', { name: /edit/i })
    await user.click(editItem)
    
    // Verify onClick was called with the row data
    expect(mockOnClick).toHaveBeenCalledWith(rowData)
  })
})
