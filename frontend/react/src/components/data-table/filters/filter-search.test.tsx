import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, act } from '@testing-library/react'
import { FilterSearch } from './filter-search'

describe('FilterSearch', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('renders with placeholder', () => {
    render(<FilterSearch value="" onChange={vi.fn()} placeholder="Search items..." />)
    
    expect(screen.getByPlaceholderText('Search items...')).toBeInTheDocument()
  })

  it('renders with default placeholder', () => {
    render(<FilterSearch value="" onChange={vi.fn()} />)
    
    expect(screen.getByPlaceholderText('Search...')).toBeInTheDocument()
  })

  it('displays initial value', () => {
    render(<FilterSearch value="test query" onChange={vi.fn()} />)
    
    expect(screen.getByDisplayValue('test query')).toBeInTheDocument()
  })

  it('calls onChange after debounce delay', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="" onChange={onChange} debounceMs={300} />)
    
    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: 'test' } })
    
    // Should not be called immediately
    expect(onChange).not.toHaveBeenCalled()
    
    // Advance timer past debounce
    act(() => {
      vi.advanceTimersByTime(300)
    })
    
    expect(onChange).toHaveBeenCalledWith('test')
  })

  it('trims whitespace before calling onChange', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="" onChange={onChange} debounceMs={300} />)
    
    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: '  test  ' } })
    
    act(() => {
      vi.advanceTimersByTime(300)
    })
    
    expect(onChange).toHaveBeenCalledWith('test')
  })

  it('calls onChange with undefined for empty/whitespace input', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="" onChange={onChange} debounceMs={300} />)
    
    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: '   ' } })
    
    act(() => {
      vi.advanceTimersByTime(300)
    })
    
    expect(onChange).toHaveBeenCalledWith(undefined)
  })

  it('shows clear button when value is not empty', () => {
    render(<FilterSearch value="test" onChange={vi.fn()} />)
    
    expect(screen.getByRole('button', { name: /clear search/i })).toBeInTheDocument()
  })

  it('hides clear button when value is empty', () => {
    render(<FilterSearch value="" onChange={vi.fn()} />)
    
    expect(screen.queryByRole('button', { name: /clear search/i })).not.toBeInTheDocument()
  })

  it('calls onChange with undefined and resets when clear button clicked', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="test" onChange={onChange} />)
    
    const clearButton = screen.getByRole('button', { name: /clear search/i })
    fireEvent.click(clearButton)
    
    expect(onChange).toHaveBeenCalledWith(undefined)
  })

  it('debounces multiple rapid changes', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="" onChange={onChange} debounceMs={300} />)
    
    const input = screen.getByRole('textbox')
    
    fireEvent.change(input, { target: { value: 't' } })
    act(() => {
      vi.advanceTimersByTime(100)
    })
    
    fireEvent.change(input, { target: { value: 'te' } })
    act(() => {
      vi.advanceTimersByTime(100)
    })
    
    fireEvent.change(input, { target: { value: 'tes' } })
    act(() => {
      vi.advanceTimersByTime(100)
    })
    
    fireEvent.change(input, { target: { value: 'test' } })
    
    // Should not have been called yet
    expect(onChange).not.toHaveBeenCalled()
    
    // Advance past debounce
    act(() => {
      vi.advanceTimersByTime(300)
    })
    
    // Should only be called once with final value
    expect(onChange).toHaveBeenCalledTimes(1)
    expect(onChange).toHaveBeenCalledWith('test')
  })

  it('applies custom className', () => {
    const { container } = render(
      <FilterSearch value="" onChange={vi.fn()} className="custom-search" />
    )
    
    const wrapper = container.firstChild
    expect(wrapper).toHaveClass('custom-search')
  })

  it('cleans up timer on unmount', () => {
    const onChange = vi.fn()
    const { unmount } = render(
      <FilterSearch value="" onChange={onChange} debounceMs={300} />
    )
    
    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: 'test' } })
    
    // Unmount before timer fires
    unmount()
    
    // Advance timer - should not throw or call onChange
    act(() => {
      vi.advanceTimersByTime(300)
    })
    
    expect(onChange).not.toHaveBeenCalled()
  })

  it('uses default debounceMs of 300', async () => {
    const onChange = vi.fn()
    render(<FilterSearch value="" onChange={onChange} />)
    
    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: 'test' } })
    
    // Should not be called at 200ms
    act(() => {
      vi.advanceTimersByTime(200)
    })
    expect(onChange).not.toHaveBeenCalled()
    
    // Should be called after 300ms total
    act(() => {
      vi.advanceTimersByTime(100)
    })
    expect(onChange).toHaveBeenCalledWith('test')
  })

  it('renders search icon', () => {
    const { container } = render(<FilterSearch value="" onChange={vi.fn()} />)
    
    // Check for SVG icon
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
  })
})
