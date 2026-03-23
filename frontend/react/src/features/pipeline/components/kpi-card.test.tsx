import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { KpiCard } from './kpi-card'

describe('Pipeline KpiCard', () => {
  it('renders label', () => {
    render(<KpiCard label="Total Items" value="1,234" />)
    
    expect(screen.getByText('Total Items')).toBeInTheDocument()
  })

  it('renders value', () => {
    render(<KpiCard label="Items" value="5,678" />)
    
    expect(screen.getByText('5,678')).toBeInTheDocument()
  })

  it('has proper styling classes', () => {
    const { container } = render(<KpiCard label="Test" value="100" />)
    
    const card = container.firstChild
    expect(card).toHaveClass('p-3', 'bg-muted', 'rounded-lg', 'text-center')
  })

  it('displays value with larger font', () => {
    render(<KpiCard label="Label" value="Value" />)
    
    const valueEl = screen.getByText('Value')
    expect(valueEl).toHaveClass('text-lg', 'font-semibold')
  })

  it('displays label with smaller muted text', () => {
    render(<KpiCard label="Test Label" value="123" />)
    
    const labelEl = screen.getByText('Test Label')
    expect(labelEl).toHaveClass('text-xs', 'text-muted-foreground')
  })
})
