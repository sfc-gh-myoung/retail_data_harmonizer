import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { FilterBar } from './filter-bar'

describe('FilterBar', () => {
  it('renders children', () => {
    render(
      <FilterBar>
        <div>Filter Content</div>
      </FilterBar>
    )
    
    expect(screen.getByText('Filter Content')).toBeInTheDocument()
  })

  it('renders reset button when onReset provided', () => {
    const mockReset = vi.fn()
    render(
      <FilterBar onReset={mockReset}>
        <div>Filter</div>
      </FilterBar>
    )
    
    expect(screen.getByRole('button', { name: /reset all/i })).toBeInTheDocument()
  })

  it('does not render reset button when onReset not provided', () => {
    render(
      <FilterBar>
        <div>Filter</div>
      </FilterBar>
    )
    
    expect(screen.queryByRole('button', { name: /reset all/i })).not.toBeInTheDocument()
  })

  it('calls onReset when reset button clicked', () => {
    const mockReset = vi.fn()
    render(
      <FilterBar onReset={mockReset}>
        <div>Filter</div>
      </FilterBar>
    )
    
    fireEvent.click(screen.getByRole('button', { name: /reset all/i }))
    expect(mockReset).toHaveBeenCalledTimes(1)
  })

  it('applies custom className', () => {
    const { container } = render(
      <FilterBar className="custom-class">
        <div>Filter</div>
      </FilterBar>
    )
    
    expect(container.firstChild).toHaveClass('custom-class')
  })

  it('renders multiple children', () => {
    render(
      <FilterBar>
        <span>Filter 1</span>
        <span>Filter 2</span>
        <span>Filter 3</span>
      </FilterBar>
    )
    
    expect(screen.getByText('Filter 1')).toBeInTheDocument()
    expect(screen.getByText('Filter 2')).toBeInTheDocument()
    expect(screen.getByText('Filter 3')).toBeInTheDocument()
  })
})
