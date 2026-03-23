import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { ScoreBreakdown } from './score-breakdown'

const defaultProps = {
  searchScore: 0.85,
  cosineScore: 0.78,
  editScore: 0.72,
  jaccardScore: 0.68,
  ensembleScore: 0.82,
  agreementLevel: 3,
  boostPercent: 10,
}

describe('ScoreBreakdown', () => {
  it('renders individual scores section', () => {
    render(<ScoreBreakdown {...defaultProps} />)
    
    expect(screen.getByText('Individual Scores')).toBeInTheDocument()
  })

  it('displays all four individual method scores', () => {
    render(<ScoreBreakdown {...defaultProps} />)
    
    expect(screen.getByText('Search')).toBeInTheDocument()
    expect(screen.getByText('Cosine')).toBeInTheDocument()
    expect(screen.getByText('Edit')).toBeInTheDocument()
    expect(screen.getByText('Jaccard')).toBeInTheDocument()
  })

  it('displays the formatted score values', () => {
    render(<ScoreBreakdown {...defaultProps} />)
    
    expect(screen.getByText('0.850')).toBeInTheDocument()
    expect(screen.getByText('0.780')).toBeInTheDocument()
    expect(screen.getByText('0.720')).toBeInTheDocument()
    expect(screen.getByText('0.680')).toBeInTheDocument()
  })

  it('displays ensemble score section', () => {
    render(<ScoreBreakdown {...defaultProps} />)
    
    expect(screen.getByText('Ensemble Score')).toBeInTheDocument()
    expect(screen.getByText('0.820')).toBeInTheDocument()
  })

  it('shows 4-way agreement label', () => {
    render(<ScoreBreakdown {...defaultProps} agreementLevel={4} />)
    
    expect(screen.getByText(/4-way agreement/)).toBeInTheDocument()
  })

  it('shows 3-way agreement label', () => {
    render(<ScoreBreakdown {...defaultProps} agreementLevel={3} />)
    
    expect(screen.getByText(/3-way agreement/)).toBeInTheDocument()
  })

  it('shows 2-way agreement label', () => {
    render(<ScoreBreakdown {...defaultProps} agreementLevel={2} />)
    
    expect(screen.getByText(/2-way agreement/)).toBeInTheDocument()
  })

  it('shows no agreement boost message when boostPercent is 0', () => {
    render(<ScoreBreakdown {...defaultProps} boostPercent={0} agreementLevel={0} />)
    
    expect(screen.getByText(/no agreement boost/)).toBeInTheDocument()
  })

  it('shows boost multiplier when boostPercent > 0', () => {
    render(<ScoreBreakdown {...defaultProps} boostPercent={15} />)
    
    // 1 + 15/100 = 1.15
    expect(screen.getByText(/× 1.15/)).toBeInTheDocument()
  })

  it('displays agreement indicator bars', () => {
    render(<ScoreBreakdown {...defaultProps} agreementLevel={3} />)
    
    expect(screen.getByText('Agreement:')).toBeInTheDocument()
  })

  it('shows boost percentage badge when boostPercent > 0', () => {
    render(<ScoreBreakdown {...defaultProps} boostPercent={10} />)
    
    expect(screen.getByText('+10%')).toBeInTheDocument()
  })

  it('hides boost percentage badge when boostPercent is 0', () => {
    render(<ScoreBreakdown {...defaultProps} boostPercent={0} />)
    
    expect(screen.queryByText(/\+\d+%/)).not.toBeInTheDocument()
  })

  it('renders agreement level 1', () => {
    render(<ScoreBreakdown {...defaultProps} agreementLevel={1} boostPercent={5} />)
    
    expect(screen.getByText(/No agreement/)).toBeInTheDocument()
  })
})
