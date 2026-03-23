import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { FilterDateRange, DateRange } from './filter-date-range'

describe('FilterDateRange', () => {
  it('renders date inputs', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    expect(screen.getByLabelText('Start date')).toBeInTheDocument()
    expect(screen.getByLabelText('End date')).toBeInTheDocument()
  })

  it('renders with initial values', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: '2024-01-01', to: '2024-01-31' }}
        onChange={onChange}
      />
    )
    expect(screen.getByLabelText('Start date')).toHaveValue('2024-01-01')
    expect(screen.getByLabelText('End date')).toHaveValue('2024-01-31')
  })

  it('calls onChange when start date changes', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    fireEvent.change(screen.getByLabelText('Start date'), {
      target: { value: '2024-02-15' },
    })
    expect(onChange).toHaveBeenCalledWith({ from: '2024-02-15', to: undefined })
  })

  it('calls onChange when end date changes', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: '2024-01-01', to: undefined }}
        onChange={onChange}
      />
    )
    fireEvent.change(screen.getByLabelText('End date'), {
      target: { value: '2024-01-31' },
    })
    expect(onChange).toHaveBeenCalledWith({ from: '2024-01-01', to: '2024-01-31' })
  })

  it('sets from to undefined when input is cleared', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: '2024-01-01', to: '2024-01-31' }}
        onChange={onChange}
      />
    )
    fireEvent.change(screen.getByLabelText('Start date'), {
      target: { value: '' },
    })
    expect(onChange).toHaveBeenCalledWith({ from: undefined, to: '2024-01-31' })
  })

  it('renders default presets', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    expect(screen.getByText('Last 7 days')).toBeInTheDocument()
    expect(screen.getByText('Last 30 days')).toBeInTheDocument()
    expect(screen.getByText('Last 90 days')).toBeInTheDocument()
  })

  it('applies preset when clicked', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    fireEvent.click(screen.getByText('Last 7 days'))
    expect(onChange).toHaveBeenCalled()
    const call = onChange.mock.calls[0][0] as DateRange
    expect(call.from).toBeDefined()
    expect(call.to).toBeDefined()
  })

  it('renders custom presets when provided', () => {
    const onChange = vi.fn()
    const customPresets = [
      { label: 'This week', value: { from: '2024-03-11', to: '2024-03-17' } },
      { label: 'This month', value: { from: '2024-03-01', to: '2024-03-31' } },
    ]
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
        presets={customPresets}
      />
    )
    expect(screen.getByText('This week')).toBeInTheDocument()
    expect(screen.getByText('This month')).toBeInTheDocument()
    expect(screen.queryByText('Last 7 days')).not.toBeInTheDocument()
  })

  it('shows clear button when value is set', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: '2024-01-01', to: undefined }}
        onChange={onChange}
      />
    )
    expect(screen.getByLabelText('Clear date range')).toBeInTheDocument()
  })

  it('does not show clear button when no value is set', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    expect(screen.queryByLabelText('Clear date range')).not.toBeInTheDocument()
  })

  it('clears date range when clear button is clicked', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: '2024-01-01', to: '2024-01-31' }}
        onChange={onChange}
      />
    )
    fireEvent.click(screen.getByLabelText('Clear date range'))
    expect(onChange).toHaveBeenCalledWith({ from: undefined, to: undefined })
  })

  it('applies custom className', () => {
    const onChange = vi.fn()
    const { container } = render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
        className="custom-filter"
      />
    )
    expect(container.firstChild).toHaveClass('custom-filter')
  })

  it('renders separator text between inputs', () => {
    const onChange = vi.fn()
    render(
      <FilterDateRange
        value={{ from: undefined, to: undefined }}
        onChange={onChange}
      />
    )
    expect(screen.getByText('to')).toBeInTheDocument()
  })
})
