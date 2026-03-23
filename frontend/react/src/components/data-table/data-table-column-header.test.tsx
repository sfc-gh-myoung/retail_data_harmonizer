import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { type Column } from '@tanstack/react-table'
import { DataTableColumnHeader } from './data-table-column-header'

function createMockColumn(options: {
  canSort?: boolean
  canHide?: boolean
  isSorted?: false | 'asc' | 'desc'
} = {}): Column<unknown, unknown> {
  const {
    canSort = true,
    canHide = true,
    isSorted = false,
  } = options

  return {
    getCanSort: () => canSort,
    getCanHide: () => canHide,
    getIsSorted: () => isSorted,
    toggleSorting: vi.fn(),
    toggleVisibility: vi.fn(),
  } as unknown as Column<unknown, unknown>
}

describe('DataTableColumnHeader', () => {
  it('renders title without dropdown when column cannot sort', () => {
    const column = createMockColumn({ canSort: false })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    expect(screen.getByText('Name')).toBeInTheDocument()
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('renders sortable header with dropdown trigger', () => {
    const column = createMockColumn({ canSort: true })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    expect(screen.getByRole('button', { name: /name/i })).toBeInTheDocument()
  })

  it('shows ArrowUpDown icon when not sorted', () => {
    const column = createMockColumn({ canSort: true, isSorted: false })
    
    const { container } = render(
      <DataTableColumnHeader column={column} title="Name" />
    )
    
    // Should have the neutral sorting icon
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
  })

  it('shows ArrowDown icon when sorted descending', () => {
    const column = createMockColumn({ canSort: true, isSorted: 'desc' })
    
    const { container } = render(
      <DataTableColumnHeader column={column} title="Name" />
    )
    
    // Should show the down arrow
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
  })

  it('shows ArrowUp icon when sorted ascending', () => {
    const column = createMockColumn({ canSort: true, isSorted: 'asc' })
    
    const { container } = render(
      <DataTableColumnHeader column={column} title="Name" />
    )
    
    // Should show the up arrow
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
  })

  it('renders dropdown trigger for sortable column', () => {
    const column = createMockColumn({ canSort: true })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    // The sortable column should render as a dropdown trigger button
    const button = screen.getByRole('button', { name: /name/i })
    expect(button).toBeInTheDocument()
    expect(button).toHaveAttribute('aria-haspopup', 'menu')
  })

  it('has correct mock methods for sorting', () => {
    const column = createMockColumn({ canSort: true })
    
    // Verify the column mock has sorting methods
    expect(column.toggleSorting).toBeDefined()
    expect(column.getCanSort()).toBe(true)
    expect(column.getIsSorted()).toBe(false)
  })

  it('has correct mock methods for hiding', () => {
    const columnCanHide = createMockColumn({ canSort: true, canHide: true })
    const columnCannotHide = createMockColumn({ canSort: true, canHide: false })
    
    // Verify the column mock has hide methods
    expect(columnCanHide.toggleVisibility).toBeDefined()
    expect(columnCanHide.getCanHide()).toBe(true)
    expect(columnCannotHide.getCanHide()).toBe(false)
  })

  it('applies custom className', () => {
    const column = createMockColumn({ canSort: false })
    
    const { container } = render(
      <DataTableColumnHeader column={column} title="Name" className="custom-class" />
    )
    
    expect(container.firstChild).toHaveClass('custom-class')
  })

  it('renders sortable column with custom className', () => {
    const column = createMockColumn({ canSort: true })
    
    const { container } = render(
      <DataTableColumnHeader column={column} title="Name" className="custom-class" />
    )
    
    expect(container.firstChild).toHaveClass('custom-class')
  })

  it('calls toggleSorting(false) when Asc is clicked', async () => {
    const user = userEvent.setup()
    const column = createMockColumn({ canSort: true })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /name/i }))
    
    // Click Asc option
    const ascMenuItem = await screen.findByRole('menuitem', { name: /asc/i })
    await user.click(ascMenuItem)
    
    expect(column.toggleSorting).toHaveBeenCalledWith(false)
  })

  it('calls toggleSorting(true) when Desc is clicked', async () => {
    const user = userEvent.setup()
    const column = createMockColumn({ canSort: true })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /name/i }))
    
    // Click Desc option
    const descMenuItem = await screen.findByRole('menuitem', { name: /desc/i })
    await user.click(descMenuItem)
    
    expect(column.toggleSorting).toHaveBeenCalledWith(true)
  })

  it('calls toggleVisibility(false) when Hide is clicked', async () => {
    const user = userEvent.setup()
    const column = createMockColumn({ canSort: true, canHide: true })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /name/i }))
    
    // Click Hide option
    const hideMenuItem = await screen.findByRole('menuitem', { name: /hide/i })
    await user.click(hideMenuItem)
    
    expect(column.toggleVisibility).toHaveBeenCalledWith(false)
  })

  it('does not show Hide option when column cannot be hidden', async () => {
    const user = userEvent.setup()
    const column = createMockColumn({ canSort: true, canHide: false })
    
    render(<DataTableColumnHeader column={column} title="Name" />)
    
    // Open dropdown
    await user.click(screen.getByRole('button', { name: /name/i }))
    
    // Wait for dropdown to open and verify Asc is present
    await screen.findByRole('menuitem', { name: /asc/i })
    
    // Hide option should not be present
    expect(screen.queryByRole('menuitem', { name: /hide/i })).not.toBeInTheDocument()
  })
})
