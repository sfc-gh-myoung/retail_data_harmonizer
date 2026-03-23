import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { NumberCell } from './number-cell'

describe('NumberCell', () => {
  it('renders null value as dash', () => {
    render(<NumberCell value={null} />)
    
    expect(screen.getByText('—')).toBeInTheDocument()
  })

  it('renders number in default format', () => {
    render(<NumberCell value={1234.567} />)
    
    const element = screen.getByText(/1,234\.57/)
    expect(element).toBeInTheDocument()
    expect(element).toHaveClass('tabular-nums')
  })

  it('renders number with custom decimals', () => {
    render(<NumberCell value={1234.5678} decimals={3} />)
    
    expect(screen.getByText(/1,234\.568/)).toBeInTheDocument()
  })

  it('renders number with zero decimals', () => {
    render(<NumberCell value={1234.567} decimals={0} />)
    
    expect(screen.getByText(/1,235/)).toBeInTheDocument()
  })

  it('renders percent format', () => {
    render(<NumberCell value={0.456} format="percent" />)
    
    expect(screen.getByText(/45\.60%/)).toBeInTheDocument()
  })

  it('renders percent with custom decimals', () => {
    render(<NumberCell value={0.12345} format="percent" decimals={1} />)
    
    expect(screen.getByText(/12\.3%/)).toBeInTheDocument()
  })

  it('renders currency format', () => {
    render(<NumberCell value={99.99} format="currency" />)
    
    // Currency format should include $ symbol
    expect(screen.getByText(/\$99\.99/)).toBeInTheDocument()
  })

  it('renders currency with custom decimals', () => {
    render(<NumberCell value={1234.5} format="currency" decimals={0} />)
    
    expect(screen.getByText(/\$1,235/)).toBeInTheDocument()
  })

  it('renders zero value', () => {
    render(<NumberCell value={0} />)
    
    expect(screen.getByText(/0\.00/)).toBeInTheDocument()
  })

  it('renders negative number', () => {
    render(<NumberCell value={-500.25} />)
    
    expect(screen.getByText(/-500\.25/)).toBeInTheDocument()
  })

  it('renders large number with separators', () => {
    render(<NumberCell value={1000000} decimals={0} />)
    
    expect(screen.getByText(/1,000,000/)).toBeInTheDocument()
  })
})
