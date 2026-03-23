import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { PipelineFunnel } from './pipeline-funnel'
import type { FunnelData } from '../hooks'

const mockFunnel: FunnelData = {
  rawItems: 1000,
  categorizedItems: 800,
  blockedItems: 50,
  uniqueDescriptions: 600,
  pipelineItems: 600,
  ensembleDone: 400,
}

const emptyFunnel: FunnelData = {
  rawItems: 0,
  categorizedItems: 0,
  blockedItems: 0,
  uniqueDescriptions: 0,
  pipelineItems: 0,
  ensembleDone: 0,
}

describe('PipelineFunnel', () => {
  it('renders pipeline phase progress header', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    expect(screen.getByText('Pipeline Phase Progress')).toBeInTheDocument()
  })

  it('shows batch ID', () => {
    render(<PipelineFunnel funnel={mockFunnel} batchId="abc123def456" />)
    
    expect(screen.getByText(/Batch: abc123de/)).toBeInTheDocument()
  })

  it('shows N/A when no batch ID', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    expect(screen.getByText(/Batch: N\/A/)).toBeInTheDocument()
  })

  it('displays funnel rows when data exists', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    expect(screen.getByText('Raw Items')).toBeInTheDocument()
    expect(screen.getByText('Categorized')).toBeInTheDocument()
    expect(screen.getByText('Unique Descriptions')).toBeInTheDocument()
    expect(screen.getByText('Matched')).toBeInTheDocument()
  })

  it('shows blocked items badge when present', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    expect(screen.getByText(/50 blocked/)).toBeInTheDocument()
  })

  it('shows empty state when no items', () => {
    render(<PipelineFunnel funnel={emptyFunnel} />)
    
    expect(screen.getByText(/No items in pipeline/)).toBeInTheDocument()
  })

  it('shows processing spinner when PROCESSING state', () => {
    render(
      <PipelineFunnel 
        funnel={mockFunnel} 
        pipelineState="PROCESSING" 
        allTasksSuspended={false}
      />
    )
    
    // The loader icon has animate-spin class
    const spinners = document.querySelectorAll('.animate-spin')
    expect(spinners.length).toBeGreaterThan(0)
  })

  it('shows pause icon when all tasks suspended', () => {
    render(
      <PipelineFunnel 
        funnel={mockFunnel} 
        pipelineState="PROCESSING" 
        allTasksSuspended={true}
      />
    )
    
    expect(screen.queryByText(/animate-spin/)).not.toBeInTheDocument()
  })

  it('shows active phase banner', () => {
    render(
      <PipelineFunnel 
        funnel={mockFunnel} 
        pipelineState="PROCESSING" 
        activePhase="Embedding Matching"
        allTasksSuspended={false}
      />
    )
    
    expect(screen.getByText(/Active:/)).toBeInTheDocument()
    expect(screen.getByText(/Embedding Matching/)).toBeInTheDocument()
  })

  it('shows paused banner when suspended', () => {
    render(
      <PipelineFunnel 
        funnel={mockFunnel} 
        pipelineState="PROCESSING" 
        activePhase="Embedding Matching"
        allTasksSuspended={true}
      />
    )
    
    expect(screen.getByText(/Paused:/)).toBeInTheDocument()
    expect(screen.getByText(/Enable tasks to resume processing/)).toBeInTheDocument()
  })

  it('can be collapsed and expanded', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    // Initially open
    expect(screen.getByText('Raw Items')).toBeInTheDocument()
    
    // Click to collapse
    fireEvent.click(screen.getByText('Pipeline Phase Progress'))
    
    // Content hidden
    expect(screen.queryByText('Raw Items')).not.toBeInTheDocument()
    
    // Click to expand
    fireEvent.click(screen.getByText('Pipeline Phase Progress'))
    
    // Content visible again
    expect(screen.getByText('Raw Items')).toBeInTheDocument()
  })

  it('displays formatted numbers', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    // 1000 should be formatted as "1,000"
    expect(screen.getByText('1,000')).toBeInTheDocument()
    expect(screen.getByText('800')).toBeInTheDocument()
  })

  it('shows dedup ratio', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    // (1 - 600/800) * 100 = 25%
    expect(screen.getByText(/25.0% dedup ratio/)).toBeInTheDocument()
  })

  it('shows completion percentage', () => {
    render(<PipelineFunnel funnel={mockFunnel} />)
    
    // 400/1000 * 100 = 40%
    expect(screen.getByText(/40.0% complete/)).toBeInTheDocument()
  })
})
