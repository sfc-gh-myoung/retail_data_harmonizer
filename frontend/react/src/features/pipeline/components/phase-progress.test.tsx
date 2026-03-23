import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { PhaseProgressList } from './phase-progress'
import type { PhaseProgress } from '../hooks/use-pipeline-status'

const mockPhases: PhaseProgress[] = [
  { name: 'Exact Match', pct: 100, done: 500, total: 500, color: '#10b981', state: 'COMPLETE' },
  { name: 'Fuzzy Match', pct: 75, done: 375, total: 500, color: '#3b82f6', state: 'PROCESSING' },
  { name: 'Embedding', pct: 0, done: 0, total: 500, color: '#8b5cf6', state: 'WAITING' },
  { name: 'Ensemble', pct: 0, done: 0, total: 0, color: '#ec4899', state: 'SKIPPED' },
]

describe('PhaseProgressList', () => {
  it('renders phase progress header', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Phase Progress')).toBeInTheDocument()
  })

  it('shows pipeline items count', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('1,000 items through matchers')).toBeInTheDocument()
  })

  it('renders all phase names', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Exact Match')).toBeInTheDocument()
    expect(screen.getByText('Fuzzy Match')).toBeInTheDocument()
    expect(screen.getByText('Embedding')).toBeInTheDocument()
    expect(screen.getByText('Ensemble')).toBeInTheDocument()
  })

  it('displays phase counts', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('500/500')).toBeInTheDocument()
    expect(screen.getByText('375/500')).toBeInTheDocument()
    expect(screen.getByText('0/500')).toBeInTheDocument()
    expect(screen.getByText('0/0')).toBeInTheDocument()
  })

  it('shows Complete badge for complete phases', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Complete')).toBeInTheDocument()
  })

  it('shows Processing badge for processing phases', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Processing')).toBeInTheDocument()
  })

  it('shows Waiting badge for waiting phases', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Waiting')).toBeInTheDocument()
  })

  it('shows Skipped badge for skipped phases', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('Skipped')).toBeInTheDocument()
  })

  it('shows Paused badge when processing and suspended', () => {
    render(
      <PhaseProgressList 
        phases={mockPhases} 
        pipelineItems={1000} 
        allTasksSuspended={true}
      />
    )
    
    expect(screen.getByText('Paused')).toBeInTheDocument()
  })

  it('shows ensemble dependency note when provided', () => {
    render(
      <PhaseProgressList 
        phases={mockPhases} 
        pipelineItems={1000}
        ensembleWaitingFor="Embedding completes"
      />
    )
    
    expect(screen.getByText(/Ensemble will start automatically when Embedding completes/)).toBeInTheDocument()
  })

  it('does not show dependency note when not provided', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.queryByText(/Ensemble will start automatically/)).not.toBeInTheDocument()
  })

  it('renders percentage in progress bar', () => {
    render(<PhaseProgressList phases={mockPhases} pipelineItems={1000} />)
    
    expect(screen.getByText('100%')).toBeInTheDocument()
    expect(screen.getByText('75%')).toBeInTheDocument()
    expect(screen.getAllByText('0%').length).toBeGreaterThan(0)
  })
})
