import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { Activity } from 'lucide-react'
import { KpiCard } from './kpi-card'

describe('KpiCard', () => {
  it('renders title and value', () => {
    render(<KpiCard title="Total Items" value={100} />)
    
    expect(screen.getByText('Total Items')).toBeInTheDocument()
    expect(screen.getByText('100')).toBeInTheDocument()
  })

  it('formats numeric values with locale string', () => {
    render(<KpiCard title="Large Number" value={1000000} />)
    
    expect(screen.getByText('1,000,000')).toBeInTheDocument()
  })

  it('renders string values as-is', () => {
    render(<KpiCard title="Status" value="Active" />)
    
    expect(screen.getByText('Active')).toBeInTheDocument()
  })

  it('renders subtitle when provided', () => {
    render(<KpiCard title="Matches" value={50} subtitle="+5 today" />)
    
    expect(screen.getByText('+5 today')).toBeInTheDocument()
  })

  it('renders icon when provided', () => {
    const { container } = render(<KpiCard title="Activity" value={10} icon={Activity} />)
    
    const icon = container.querySelector('svg')
    expect(icon).toBeInTheDocument()
    expect(icon).toHaveClass('h-8', 'w-8')
  })

  it('applies default variant style', () => {
    render(<KpiCard title="Test" value={100} />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-foreground')
  })

  it('applies success variant style', () => {
    render(<KpiCard title="Test" value={100} variant="success" />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-green-600')
  })

  it('applies warning variant style', () => {
    render(<KpiCard title="Test" value={100} variant="warning" />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-yellow-600')
  })

  it('applies danger variant style', () => {
    render(<KpiCard title="Test" value={100} variant="danger" />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-red-600')
  })

  it('applies primary variant style', () => {
    render(<KpiCard title="Test" value={100} variant="primary" />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-blue-600')
  })

  it('applies accent variant style', () => {
    render(<KpiCard title="Test" value={100} variant="accent" />)
    
    const valueEl = screen.getByText('100')
    expect(valueEl).toHaveClass('text-purple-600')
  })

  it('applies variant style to icon as well', () => {
    const { container } = render(
      <KpiCard title="Test" value={100} variant="success" icon={Activity} />
    )
    
    const icon = container.querySelector('svg')
    expect(icon).toHaveClass('text-green-600')
  })

  it('does not render subtitle when not provided', () => {
    const { container } = render(<KpiCard title="Test" value={100} />)
    
    const subtitleElements = container.querySelectorAll('.text-xs.text-muted-foreground')
    expect(subtitleElements.length).toBe(0)
  })
})
