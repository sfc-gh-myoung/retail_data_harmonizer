import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { ConfidenceBadge, ScoreBadgeRow } from './confidence-badge'

describe('ConfidenceBadge', () => {
  it('renders score in decimal format by default', () => {
    render(<ConfidenceBadge score={0.856} />)
    
    expect(screen.getByText('0.856')).toBeInTheDocument()
  })

  it('renders score in percent format when specified', () => {
    render(<ConfidenceBadge score={0.856} format="percent" />)
    
    expect(screen.getByText('86%')).toBeInTheDocument()
  })

  it('applies green styling for high scores (> 0.80)', () => {
    render(<ConfidenceBadge score={0.85} />)
    
    const badge = screen.getByText('0.850')
    expect(badge).toHaveClass('text-green-700')
  })

  it('applies yellow styling for medium scores (>= 0.70)', () => {
    render(<ConfidenceBadge score={0.75} />)
    
    const badge = screen.getByText('0.750')
    expect(badge).toHaveClass('text-yellow-700')
  })

  it('applies orange styling for low-medium scores (>= 0.60)', () => {
    render(<ConfidenceBadge score={0.65} />)
    
    const badge = screen.getByText('0.650')
    expect(badge).toHaveClass('text-orange-700')
  })

  it('applies red styling for low scores (< 0.60)', () => {
    render(<ConfidenceBadge score={0.45} />)
    
    const badge = screen.getByText('0.450')
    expect(badge).toHaveClass('text-red-700')
  })

  it('applies small size styling by default', () => {
    render(<ConfidenceBadge score={0.5} />)
    
    const badge = screen.getByText('0.500')
    expect(badge).toHaveClass('text-xs')
  })

  it('applies medium size styling when specified', () => {
    render(<ConfidenceBadge score={0.5} size="md" />)
    
    const badge = screen.getByText('0.500')
    expect(badge).toHaveClass('text-sm')
  })

  it('shows label when showLabel is true', () => {
    render(<ConfidenceBadge score={0.5} showLabel label="Score" />)
    
    expect(screen.getByText('Score')).toBeInTheDocument()
  })

  it('does not show label when showLabel is false', () => {
    render(<ConfidenceBadge score={0.5} showLabel={false} label="Score" />)
    
    expect(screen.queryByText('Score')).not.toBeInTheDocument()
  })

  it('handles boundary value 0.80', () => {
    render(<ConfidenceBadge score={0.80} />)
    
    const badge = screen.getByText('0.800')
    expect(badge).toHaveClass('text-yellow-700')
  })

  it('handles boundary value 0.70', () => {
    render(<ConfidenceBadge score={0.70} />)
    
    const badge = screen.getByText('0.700')
    expect(badge).toHaveClass('text-yellow-700')
  })

  it('handles boundary value 0.60', () => {
    render(<ConfidenceBadge score={0.60} />)
    
    const badge = screen.getByText('0.600')
    expect(badge).toHaveClass('text-orange-700')
  })
})

describe('ScoreBadgeRow', () => {
  it('renders scores for each method', () => {
    const scores = {
      search: 0.85,
      cosine: 0.72,
      edit: 0.68,
    }
    
    render(<ScoreBadgeRow scores={scores} />)
    
    expect(screen.getByText('Search:')).toBeInTheDocument()
    expect(screen.getByText('Cosine:')).toBeInTheDocument()
    expect(screen.getByText('Edit:')).toBeInTheDocument()
    expect(screen.getByText('0.850')).toBeInTheDocument()
    expect(screen.getByText('0.720')).toBeInTheDocument()
    expect(screen.getByText('0.680')).toBeInTheDocument()
  })

  it('hides zero scores by default', () => {
    const scores = {
      search: 0.85,
      cosine: 0,
      edit: 0.68,
    }
    
    render(<ScoreBadgeRow scores={scores} />)
    
    expect(screen.getByText('Search:')).toBeInTheDocument()
    expect(screen.queryByText('Cosine:')).not.toBeInTheDocument()
    expect(screen.getByText('Edit:')).toBeInTheDocument()
  })

  it('shows zero scores when showZeros is true', () => {
    const scores = {
      search: 0.85,
      cosine: 0,
    }
    
    render(<ScoreBadgeRow scores={scores} showZeros />)
    
    expect(screen.getByText('Search:')).toBeInTheDocument()
    expect(screen.getByText('Cosine:')).toBeInTheDocument()
  })

  it('renders nothing when all scores are zero', () => {
    const scores = {
      search: 0,
      cosine: 0,
    }
    
    const { container } = render(<ScoreBadgeRow scores={scores} />)
    
    expect(container).toBeEmptyDOMElement()
  })

  it('handles undefined scores', () => {
    const scores = {
      search: 0.85,
    }
    
    render(<ScoreBadgeRow scores={scores} />)
    
    expect(screen.getByText('Search:')).toBeInTheDocument()
    expect(screen.queryByText('Cosine:')).not.toBeInTheDocument()
    expect(screen.queryByText('Edit:')).not.toBeInTheDocument()
  })

  it('displays Jaccard score when present', () => {
    const scores = {
      jaccard: 0.78,
    }
    
    render(<ScoreBadgeRow scores={scores} />)
    
    expect(screen.getByText('Jaccard:')).toBeInTheDocument()
    expect(screen.getByText('0.780')).toBeInTheDocument()
  })
})
