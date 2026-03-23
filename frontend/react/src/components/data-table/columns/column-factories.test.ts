import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import {
  createSelectColumn,
  createSortableColumn,
  createBadgeColumn,
  createDateColumn,
  createNumberColumn,
  createActionsColumn,
} from './column-factories'

describe('column-factories', () => {
  describe('createSelectColumn', () => {
    it('creates a column with id "select"', () => {
      const column = createSelectColumn()
      expect(column.id).toBe('select')
    })

    it('disables sorting and hiding', () => {
      const column = createSelectColumn()
      expect(column.enableSorting).toBe(false)
      expect(column.enableHiding).toBe(false)
    })

    it('renders header checkbox', () => {
      const column = createSelectColumn()
      const mockTable = {
        getIsAllPageRowsSelected: vi.fn(() => false),
        getIsSomePageRowsSelected: vi.fn(() => false),
        toggleAllPageRowsSelected: vi.fn(),
      }
      
      const HeaderComponent = column.header as (props: { table: typeof mockTable }) => React.ReactElement
      render(HeaderComponent({ table: mockTable }))
      expect(screen.getByLabelText('Select all')).toBeInTheDocument()
    })

    it('header checkbox calls toggleAllPageRowsSelected', () => {
      const column = createSelectColumn()
      const mockTable = {
        getIsAllPageRowsSelected: vi.fn(() => false),
        getIsSomePageRowsSelected: vi.fn(() => false),
        toggleAllPageRowsSelected: vi.fn(),
      }
      
      const HeaderComponent = column.header as (props: { table: typeof mockTable }) => React.ReactElement
      render(HeaderComponent({ table: mockTable }))
      fireEvent.click(screen.getByLabelText('Select all'))
      expect(mockTable.toggleAllPageRowsSelected).toHaveBeenCalled()
    })

    it('renders cell checkbox', () => {
      const column = createSelectColumn()
      const mockRow = {
        getIsSelected: vi.fn(() => false),
        toggleSelected: vi.fn(),
      }
      
      const CellComponent = column.cell as (props: { row: typeof mockRow }) => React.ReactElement
      render(CellComponent({ row: mockRow }))
      expect(screen.getByLabelText('Select row')).toBeInTheDocument()
    })

    it('cell checkbox calls toggleSelected', () => {
      const column = createSelectColumn()
      const mockRow = {
        getIsSelected: vi.fn(() => false),
        toggleSelected: vi.fn(),
      }
      
      const CellComponent = column.cell as (props: { row: typeof mockRow }) => React.ReactElement
      render(CellComponent({ row: mockRow }))
      fireEvent.click(screen.getByLabelText('Select row'))
      expect(mockRow.toggleSelected).toHaveBeenCalled()
    })

    it('shows indeterminate state when some rows selected', () => {
      const column = createSelectColumn()
      const mockTable = {
        getIsAllPageRowsSelected: vi.fn(() => false),
        getIsSomePageRowsSelected: vi.fn(() => true),
        toggleAllPageRowsSelected: vi.fn(),
      }
      
      const HeaderComponent = column.header as (props: { table: typeof mockTable }) => React.ReactElement
      render(HeaderComponent({ table: mockTable }))
      // Checkbox should render in indeterminate state
      expect(screen.getByLabelText('Select all')).toBeInTheDocument()
    })
  })

  describe('createSortableColumn', () => {
    it('creates a column with accessorKey and header', () => {
      const column = createSortableColumn({
        accessorKey: 'name',
        header: 'Name',
      })
      expect(column.accessorKey).toBe('name')
      expect(column.header).toBe('Name')
    })

    it('enables sorting by default', () => {
      const column = createSortableColumn({
        accessorKey: 'name',
        header: 'Name',
      })
      expect(column.enableSorting).toBe(true)
    })

    it('allows disabling sorting', () => {
      const column = createSortableColumn({
        accessorKey: 'name',
        header: 'Name',
        enableSorting: false,
      })
      expect(column.enableSorting).toBe(false)
    })
  })

  describe('createBadgeColumn', () => {
    it('creates a column with accessorKey and header', () => {
      const column = createBadgeColumn({
        accessorKey: 'status',
        header: 'Status',
      })
      expect(column.accessorKey).toBe('status')
      expect(column.header).toBe('Status')
    })

    it('enables sorting', () => {
      const column = createBadgeColumn({
        accessorKey: 'status',
        header: 'Status',
      })
      expect(column.enableSorting).toBe(true)
    })

    it('renders BadgeCell in cell', () => {
      const column = createBadgeColumn({
        accessorKey: 'status',
        header: 'Status',
      })
      
      const CellComponent = column.cell as (props: { getValue: () => string }) => React.ReactElement
      render(CellComponent({ getValue: () => 'active' }))
      expect(screen.getByText('active')).toBeInTheDocument()
    })
  })

  describe('createDateColumn', () => {
    it('creates a column with accessorKey and header', () => {
      const column = createDateColumn({
        accessorKey: 'createdAt',
        header: 'Created',
      })
      expect(column.accessorKey).toBe('createdAt')
      expect(column.header).toBe('Created')
    })

    it('enables sorting', () => {
      const column = createDateColumn({
        accessorKey: 'createdAt',
        header: 'Created',
      })
      expect(column.enableSorting).toBe(true)
    })

    it('renders DateCell in cell', () => {
      const column = createDateColumn({
        accessorKey: 'createdAt',
        header: 'Created',
      })
      
      const CellComponent = column.cell as (props: { getValue: () => string }) => React.ReactElement
      render(CellComponent({ getValue: () => '2024-03-15T10:30:00Z' }))
      // DateCell formats the date
      expect(screen.getByText(/2024/)).toBeInTheDocument()
    })
  })

  describe('createNumberColumn', () => {
    it('creates a column with accessorKey and header', () => {
      const column = createNumberColumn({
        accessorKey: 'amount',
        header: 'Amount',
      })
      expect(column.accessorKey).toBe('amount')
      expect(column.header).toBe('Amount')
    })

    it('enables sorting', () => {
      const column = createNumberColumn({
        accessorKey: 'amount',
        header: 'Amount',
      })
      expect(column.enableSorting).toBe(true)
    })

    it('renders NumberCell in cell', () => {
      const column = createNumberColumn({
        accessorKey: 'amount',
        header: 'Amount',
      })
      
      const CellComponent = column.cell as (props: { getValue: () => number }) => React.ReactElement
      render(CellComponent({ getValue: () => 1234.56 }))
      // NumberCell formats the number
      expect(screen.getByText(/1.*234/)).toBeInTheDocument()
    })
  })

  describe('createActionsColumn', () => {
    it('creates a column with id "actions"', () => {
      const column = createActionsColumn([])
      expect(column.id).toBe('actions')
    })

    it('has empty header', () => {
      const column = createActionsColumn([])
      expect(column.header).toBe('')
    })

    it('disables sorting and hiding', () => {
      const column = createActionsColumn([])
      expect(column.enableSorting).toBe(false)
      expect(column.enableHiding).toBe(false)
    })

    it('renders ActionCell in cell', () => {
      const actions = [
        { label: 'Edit', onClick: vi.fn() },
        { label: 'Delete', onClick: vi.fn() },
      ]
      const column = createActionsColumn(actions)
      
      const mockRow = { original: { id: 1, name: 'Test' } }
      const CellComponent = column.cell as (props: { row: typeof mockRow }) => React.ReactElement
      render(CellComponent({ row: mockRow }))
      // ActionCell renders a trigger button
      expect(screen.getByRole('button')).toBeInTheDocument()
    })
  })
})
