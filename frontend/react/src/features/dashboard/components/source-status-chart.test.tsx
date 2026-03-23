import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { SourceStatusChart } from './source-status-chart'
import type { SourceSystems, StatusColorsMap } from '../types'

describe('SourceStatusChart', () => {
  const mockSourceSystems: SourceSystems = {
    'Source A': {
      AUTO_ACCEPTED: 50,
      CONFIRMED: 30,
      PENDING_REVIEW: 10,
      PENDING: 5,
      REJECTED: 5,
    },
    'Source B': {
      AUTO_ACCEPTED: 100,
      CONFIRMED: 50,
      PENDING_REVIEW: 25,
      PENDING: 15,
      REJECTED: 10,
    },
  }

  const mockStatusColorsMap: StatusColorsMap = {
    AUTO_ACCEPTED: '#22c55e',
    CONFIRMED: '#10b981',
    PENDING_REVIEW: '#f59e0b',
    PENDING: '#6b7280',
    REJECTED: '#ef4444',
  }

  it('renders all source labels', () => {
    render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    expect(screen.getByText('Source A')).toBeInTheDocument()
    expect(screen.getByText('Source B')).toBeInTheDocument()
  })

  it('displays total count for each source', () => {
    render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    // Source A total: 50+30+10+5+5 = 100
    expect(screen.getByText('(100)')).toBeInTheDocument()
    // Source B total: 100+50+25+15+10 = 200
    expect(screen.getByText('(200)')).toBeInTheDocument()
  })

  it('renders legend with all status types', () => {
    render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    expect(screen.getByText('Auto Accepted')).toBeInTheDocument()
    expect(screen.getByText('Confirmed')).toBeInTheDocument()
    expect(screen.getByText('Pending Review')).toBeInTheDocument()
    expect(screen.getByText('Pending')).toBeInTheDocument()
    expect(screen.getByText('Rejected')).toBeInTheDocument()
  })

  it('renders status bars with title attributes', () => {
    const { container } = render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    const barsWithTitle = container.querySelectorAll('[title]')
    expect(barsWithTitle.length).toBeGreaterThan(0)
    
    // Check that some title contains status info
    const titles = Array.from(barsWithTitle).map(el => el.getAttribute('title'))
    expect(titles.some(t => t?.includes('AUTO ACCEPTED'))).toBe(true)
  })

  it('applies correct background colors from statusColorsMap', () => {
    const { container } = render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    const greenBars = container.querySelectorAll('[style*="background-color: rgb(34, 197, 94)"]')
    expect(greenBars.length).toBeGreaterThan(0)
  })

  it('handles empty source systems', () => {
    const { container } = render(
      <SourceStatusChart
        sourceSystems={{}}
        sourceMax={100}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    // Should still render the legend
    expect(screen.getByText('Auto Accepted')).toBeInTheDocument()
    
    // No source entries
    expect(container.querySelector('.space-y-1')).not.toBeInTheDocument()
  })

  it('renders legend color indicators', () => {
    const { container } = render(
      <SourceStatusChart
        sourceSystems={mockSourceSystems}
        sourceMax={200}
        statusColorsMap={mockStatusColorsMap}
      />
    )
    
    const colorIndicators = container.querySelectorAll('.w-3.h-3.rounded-sm')
    expect(colorIndicators.length).toBe(5) // 5 status types
  })
})
