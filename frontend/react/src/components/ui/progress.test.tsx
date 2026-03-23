import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { Progress } from './progress'

describe('Progress', () => {
  it('renders progress bar', () => {
    render(<Progress value={50} />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toBeInTheDocument()
  })

  it('applies custom className', () => {
    render(<Progress value={50} className="custom-class" />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toHaveClass('custom-class')
  })

  it('renders with a value', () => {
    render(<Progress value={75} />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toBeInTheDocument()
  })

  it('handles zero value', () => {
    render(<Progress value={0} />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toBeInTheDocument()
  })

  it('handles 100% value', () => {
    render(<Progress value={100} />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toBeInTheDocument()
  })

  it('handles undefined value', () => {
    render(<Progress />)
    
    const progressbar = screen.getByRole('progressbar')
    expect(progressbar).toBeInTheDocument()
  })
})
