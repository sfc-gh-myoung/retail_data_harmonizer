import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { ScaleProjection } from './scale-projection'
import type { ScaleData } from '../types'

describe('ScaleProjection', () => {
  const mockScaleData: ScaleData = {
    total: 10000,
    uniqueCount: 8500,
    dedupRatio: 0.85,
    fastPathRate: 75,
    fastPathCount: 7500,
  }

  it('renders description text', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText(/projected costs at production scale/i)).toBeInTheDocument()
  })

  it('renders table headers', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText('Metric')).toBeInTheDocument()
    // Check that table has Demo and Production columns
    const table = screen.getByRole('table')
    expect(table).toBeInTheDocument()
  })

  it('displays unique descriptions row', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText('Unique Descriptions')).toBeInTheDocument()
    expect(screen.getByText('8,500')).toBeInTheDocument()
    // Production: 48M * 0.85 = 40,800,000
    expect(screen.getByText('40,800,000')).toBeInTheDocument()
  })

  it('displays dedup ratio row', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText('Dedup Ratio')).toBeInTheDocument()
    // (1 - 0.85) * 100 = 15%
    expect(screen.getByText('15.0%')).toBeInTheDocument()
  })

  it('displays fast-path rate row', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText('Fast-path Rate')).toBeInTheDocument()
    expect(screen.getByText('75%')).toBeInTheDocument()
    expect(screen.getByText('75% (projected)')).toBeInTheDocument()
  })

  it('displays items needing full pipeline row', () => {
    render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(screen.getByText('Items Needing Full Pipeline')).toBeInTheDocument()
    // Demo: 10000 - 7500 = 2500
    expect(screen.getByText('2,500')).toBeInTheDocument()
    // Production: 48M - (48M * 0.75) = 12M
    expect(screen.getByText('12,000,000')).toBeInTheDocument()
  })

  it('renders as a table element', () => {
    const { container } = render(<ScaleProjection scaleData={mockScaleData} />)
    
    expect(container.querySelector('table')).toBeInTheDocument()
    expect(container.querySelector('thead')).toBeInTheDocument()
    expect(container.querySelector('tbody')).toBeInTheDocument()
  })

  it('has correct number of rows', () => {
    const { container } = render(<ScaleProjection scaleData={mockScaleData} />)
    
    const rows = container.querySelectorAll('tbody tr')
    expect(rows.length).toBe(4) // 4 metric rows
  })
})
