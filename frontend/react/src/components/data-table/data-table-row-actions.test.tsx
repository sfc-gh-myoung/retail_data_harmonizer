/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { DataTableRowActions } from './data-table-row-actions'

function createMockRow(data = { id: '1', name: 'Test' }) {
  return {
    original: data,
    id: '0',
    getValue: vi.fn((key: string) => data[key as keyof typeof data]),
  }
}

describe('DataTableRowActions', () => {
  it('renders nothing when actions array is empty', () => {
    const row = createMockRow()
    const { container } = render(
      <DataTableRowActions row={row as any} actions={[]} />
    )
    expect(container).toBeEmptyDOMElement()
  })

  it('renders trigger button with actions', () => {
    const row = createMockRow()
    const actions = [
      { label: 'Edit', onClick: vi.fn() },
      { label: 'Delete', onClick: vi.fn() },
    ]
    
    render(<DataTableRowActions row={row as any} actions={actions} />)
    
    expect(screen.getByRole('button', { name: /open menu/i })).toBeInTheDocument()
  })

  it('returns null when function returns empty array', () => {
    const row = createMockRow()
    const actionsFunc = () => []
    
    const { container } = render(
      <DataTableRowActions row={row as any} actions={actionsFunc} />
    )
    
    expect(container).toBeEmptyDOMElement()
  })

  it('calls function-based actions with row', () => {
    const row = createMockRow({ id: '123', name: 'Dynamic' })
    const actionsFunc = vi.fn(() => [
      { label: 'Edit', onClick: vi.fn() },
    ])
    
    render(<DataTableRowActions row={row as any} actions={actionsFunc} />)
    
    expect(actionsFunc).toHaveBeenCalledWith(row)
  })
})
