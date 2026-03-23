import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { FilterSelect } from './filter-select'

// Mock scrollIntoView for JSDOM (Radix Select uses this)
beforeEach(() => {
  Element.prototype.scrollIntoView = vi.fn()
})

const mockOptions = [
  { value: 'option1', label: 'Option 1' },
  { value: 'option2', label: 'Option 2' },
  { value: 'option3', label: 'Option 3' },
]

describe('FilterSelect', () => {
  it('renders with placeholder when no value selected', () => {
    render(
      <FilterSelect
        value={undefined}
        onChange={vi.fn()}
        options={mockOptions}
        placeholder="Select..."
      />
    )
    expect(screen.getByText('Select...')).toBeInTheDocument()
  })

  it('renders with default placeholder when none provided', () => {
    render(
      <FilterSelect
        value={undefined}
        onChange={vi.fn()}
        options={mockOptions}
      />
    )
    // Default placeholder from component is "Select..."
    expect(screen.getByRole('combobox')).toBeInTheDocument()
  })

  it('renders with selected value label', () => {
    render(
      <FilterSelect
        value="option1"
        onChange={vi.fn()}
        options={mockOptions}
      />
    )
    expect(screen.getByText('Option 1')).toBeInTheDocument()
  })

  it('renders combobox trigger', () => {
    render(
      <FilterSelect
        value={undefined}
        onChange={vi.fn()}
        options={mockOptions}
      />
    )
    expect(screen.getByRole('combobox')).toBeInTheDocument()
  })

  it('calls onChange with undefined when clear button clicked', () => {
    const mockOnChange = vi.fn()
    render(
      <FilterSelect
        value="option1"
        onChange={mockOnChange}
        options={mockOptions}
      />
    )

    // Find and click the clear button
    const clearButton = screen.getByRole('button', { name: /clear filter/i })
    fireEvent.click(clearButton)

    expect(mockOnChange).toHaveBeenCalledWith(undefined)
  })

  it('hides clear button when no value selected', () => {
    render(
      <FilterSelect
        value={undefined}
        onChange={vi.fn()}
        options={mockOptions}
      />
    )

    expect(screen.queryByRole('button', { name: /clear filter/i })).not.toBeInTheDocument()
  })

  it('shows clear button when value is selected', () => {
    render(
      <FilterSelect
        value="option2"
        onChange={vi.fn()}
        options={mockOptions}
      />
    )

    expect(screen.getByRole('button', { name: /clear filter/i })).toBeInTheDocument()
  })

  it('applies custom className when provided', () => {
    const { container } = render(
      <FilterSelect
        value={undefined}
        onChange={vi.fn()}
        options={mockOptions}
        className="custom-test-class"
      />
    )

    expect(container.querySelector('.custom-test-class')).toBeInTheDocument()
  })
})
