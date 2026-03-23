import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { CostRoiSection } from './cost-roi-section'
import type { CostData } from '../types'

describe('CostRoiSection', () => {
  const mockCostData: CostData = {
    totalRuns: 5,
    totalCredits: 2.5,
    creditRateUsd: 3.0,
    totalUsd: 7.5,
    totalItems: 1000,
    costPerItem: 0.0075,
    hoursSaved: 16.5,
    roiPercentage: 2800,
    baselineWeeklyCost: 220,
    manualHourlyRate: 50,
    manualMinutesPerItem: 2.0,
  }

  it('renders no data message when totalRuns is 0', () => {
    const emptyData = { ...mockCostData, totalRuns: 0 }
    render(<CostRoiSection costData={emptyData} />)
    
    expect(screen.getByText(/no task dag executions yet/i)).toBeInTheDocument()
  })

  it('renders KPI cards when data exists', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByText('Total Cost')).toBeInTheDocument()
    expect(screen.getByText('Cost per Item')).toBeInTheDocument()
    expect(screen.getByText('Hours Saved')).toBeInTheDocument()
    expect(screen.getByText('ROI')).toBeInTheDocument()
  })

  it('displays formatted total cost', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByText('$7.50')).toBeInTheDocument()
    expect(screen.getByText('2.50 credits')).toBeInTheDocument()
  })

  it('displays cost per item', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByText('$0.0075')).toBeInTheDocument()
  })

  it('displays hours saved', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByText('16.5h')).toBeInTheDocument()
    expect(screen.getByText('vs Manual')).toBeInTheDocument()
  })

  it('displays ROI percentage', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByText('2,800%')).toBeInTheDocument()
  })

  it('renders breakdown toggle button', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    expect(screen.getByRole('button', { name: /how are these kpis calculated/i })).toBeInTheDocument()
  })

  it('toggles breakdown visibility when button clicked', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    // Initially breakdown is hidden
    expect(screen.queryByText('Total Cost Breakdown')).not.toBeInTheDocument()
    
    // Click to show
    fireEvent.click(screen.getByRole('button', { name: /how are these kpis calculated/i }))
    
    expect(screen.getByText('Credits Used:')).toBeInTheDocument()
    expect(screen.getByText('Credit Rate:')).toBeInTheDocument()
  })

  it('shows all breakdown sections when expanded', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    fireEvent.click(screen.getByRole('button', { name: /how are these kpis calculated/i }))
    
    expect(screen.getByText('Cost per Item', { selector: '.font-semibold' })).toBeInTheDocument()
    expect(screen.getByText('Hours Saved', { selector: '.font-semibold' })).toBeInTheDocument()
    expect(screen.getByText('ROI Percentage')).toBeInTheDocument()
  })

  it('displays breakdown calculation details', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    fireEvent.click(screen.getByRole('button', { name: /how are these kpis calculated/i }))
    
    expect(screen.getByText('Items Processed:')).toBeInTheDocument()
    expect(screen.getByText('1,000')).toBeInTheDocument()
    expect(screen.getByText('Manual Rate:')).toBeInTheDocument()
  })

  it('displays note about data sources in breakdown', () => {
    render(<CostRoiSection costData={mockCostData} />)
    
    fireEvent.click(screen.getByRole('button', { name: /how are these kpis calculated/i }))
    
    expect(screen.getByText(/credits sourced from warehouse_metering_history/i)).toBeInTheDocument()
  })
})
