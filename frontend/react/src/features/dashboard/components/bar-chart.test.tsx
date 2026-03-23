import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { BarChart } from './bar-chart'

describe('BarChart', () => {
  const mockItems = [
    { label: 'Item A', count: 100, color: '#ff0000' },
    { label: 'Item B', count: 50, color: '#00ff00' },
    { label: 'Item C', count: 25, color: '#0000ff' },
  ]

  it('renders all items', () => {
    render(<BarChart items={mockItems} />)
    
    expect(screen.getByText('Item A')).toBeInTheDocument()
    expect(screen.getByText('Item B')).toBeInTheDocument()
    expect(screen.getByText('Item C')).toBeInTheDocument()
  })

  it('displays count and percentage for items', () => {
    render(<BarChart items={mockItems} />)
    
    expect(screen.getByText(/100.*100\.0%/)).toBeInTheDocument()
    expect(screen.getByText(/50.*50\.0%/)).toBeInTheDocument()
    expect(screen.getByText(/25.*25\.0%/)).toBeInTheDocument()
  })

  it('uses provided maxValue for percentage calculation', () => {
    render(<BarChart items={mockItems} maxValue={200} />)
    
    // 100/200 = 50%
    expect(screen.getByText(/100.*50\.0%/)).toBeInTheDocument()
  })

  it('displays as percent when displayAsPercent is true', () => {
    const items = [
      { label: 'Match Rate', count: 85, color: '#ff0000', displayAsPercent: true, pct: 85 },
    ]
    render(<BarChart items={items} />)
    
    expect(screen.getByText(/85\.0%/)).toBeInTheDocument()
  })

  it('displays suffix when provided with displayAsPercent', () => {
    const items = [
      { label: 'Rate', count: 90, color: '#ff0000', displayAsPercent: true, pct: 90, suffix: 'accuracy' },
    ]
    render(<BarChart items={items} />)
    
    expect(screen.getByText('accuracy')).toBeInTheDocument()
  })

  it('uses pct value when provided', () => {
    const items = [
      { label: 'Custom', count: 50, color: '#ff0000', pct: 75 },
    ]
    render(<BarChart items={items} />)
    
    expect(screen.getByText(/50.*75\.0%/)).toBeInTheDocument()
  })

  it('calculates max from items when maxValue not provided', () => {
    const items = [
      { label: 'A', count: 100, color: '#ff0000' },
      { label: 'B', count: 200, color: '#00ff00' },
    ]
    render(<BarChart items={items} />)
    
    // B should be 100%, A should be 50%
    expect(screen.getByText(/200.*100\.0%/)).toBeInTheDocument()
    expect(screen.getByText(/100.*50\.0%/)).toBeInTheDocument()
  })

  it('handles empty items array', () => {
    const { container } = render(<BarChart items={[]} />)
    
    const wrapper = container.querySelector('.space-y-2')
    expect(wrapper).toBeInTheDocument()
    expect(wrapper?.children.length).toBe(0)
  })

  it('applies correct background color to bars', () => {
    const items = [
      { label: 'Red', count: 100, color: '#ff0000' },
    ]
    const { container } = render(<BarChart items={items} />)
    
    const bar = container.querySelector('[style*="background-color"]')
    expect(bar).toHaveStyle({ backgroundColor: '#ff0000' })
  })

  it('formats large numbers with locale string', () => {
    const items = [
      { label: 'Large', count: 1000000, color: '#ff0000' },
    ]
    render(<BarChart items={items} />)
    
    // Should format as 1,000,000
    expect(screen.getByText(/1,000,000/)).toBeInTheDocument()
  })
})
