import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { FilterMultiSelect } from './filter-multi-select'

describe('FilterMultiSelect', () => {
  const defaultOptions = [
    { value: 'option1', label: 'Option 1' },
    { value: 'option2', label: 'Option 2', count: 5 },
    { value: 'option3', label: 'Option 3', count: 10 },
  ]

  it('renders with placeholder when no value selected', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
        placeholder="Select items"
      />
    )
    expect(screen.getByText('Select items')).toBeInTheDocument()
  })

  it('renders default placeholder when none provided', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    expect(screen.getByText('Select...')).toBeInTheDocument()
  })

  it('shows badge with count when values are selected', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={['option1', 'option2']}
        onChange={onChange}
        options={defaultOptions}
        placeholder="Select items"
      />
    )
    expect(screen.getByText('2')).toBeInTheDocument()
  })

  it('shows clear button when values are selected', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={['option1']}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    expect(screen.getByLabelText('Clear filter')).toBeInTheDocument()
  })

  it('does not show clear button when no values selected', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    expect(screen.queryByLabelText('Clear filter')).not.toBeInTheDocument()
  })

  it('clears all values when clear button is clicked', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={['option1', 'option2']}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    fireEvent.click(screen.getByLabelText('Clear filter'))
    expect(onChange).toHaveBeenCalledWith([])
  })

  it('opens dropdown when button is clicked', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: /select/i }))
    expect(screen.getByText('Option 1')).toBeInTheDocument()
    expect(screen.getByText('Option 2')).toBeInTheDocument()
    expect(screen.getByText('Option 3')).toBeInTheDocument()
  })

  it('shows count for options that have it', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: /select/i }))
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText('10')).toBeInTheDocument()
  })

  it('toggles option selection when clicked', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: /select/i }))
    fireEvent.click(screen.getByText('Option 1'))
    expect(onChange).toHaveBeenCalledWith(['option1'])
  })

  it('removes option when already selected', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={['option1', 'option2']}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    fireEvent.click(screen.getByRole('button', { name: /select/i }))
    fireEvent.click(screen.getByText('Option 1'))
    expect(onChange).toHaveBeenCalledWith(['option2'])
  })

  it('closes dropdown when clicking outside', () => {
    const onChange = vi.fn()
    render(
      <div>
        <FilterMultiSelect
          value={[]}
          onChange={onChange}
          options={defaultOptions}
        />
        <div data-testid="outside">Outside</div>
      </div>
    )
    fireEvent.click(screen.getByRole('button', { name: /select/i }))
    expect(screen.getByText('Option 1')).toBeInTheDocument()
    
    fireEvent.mouseDown(screen.getByTestId('outside'))
    expect(screen.queryByText('Option 1')).not.toBeInTheDocument()
  })

  it('applies custom className', () => {
    const onChange = vi.fn()
    const { container } = render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
        className="custom-class"
      />
    )
    expect(container.firstChild).toHaveClass('custom-class')
  })

  it('sets aria-expanded attribute on trigger button', () => {
    const onChange = vi.fn()
    render(
      <FilterMultiSelect
        value={[]}
        onChange={onChange}
        options={defaultOptions}
      />
    )
    const button = screen.getByRole('button', { name: /select/i })
    expect(button).toHaveAttribute('aria-expanded', 'false')
    
    fireEvent.click(button)
    expect(button).toHaveAttribute('aria-expanded', 'true')
  })
})
