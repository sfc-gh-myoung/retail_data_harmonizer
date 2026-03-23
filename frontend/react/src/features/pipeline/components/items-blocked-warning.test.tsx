import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { ItemsBlockedWarning } from './items-blocked-warning'

describe('ItemsBlockedWarning', () => {
  it('renders nothing when blockedCount is 0', () => {
    const { container } = render(<ItemsBlockedWarning blockedCount={0} />)
    
    expect(container.firstChild).toBeNull()
  })

  it('renders nothing when blockedCount is negative', () => {
    const { container } = render(<ItemsBlockedWarning blockedCount={-5} />)
    
    expect(container.firstChild).toBeNull()
  })

  it('renders alert when blockedCount is positive', () => {
    render(<ItemsBlockedWarning blockedCount={100} />)
    
    expect(screen.getByRole('alert')).toBeInTheDocument()
  })

  it('displays formatted blocked count in title', () => {
    render(<ItemsBlockedWarning blockedCount={1500} />)
    
    expect(screen.getByText('1,500 Items Blocked')).toBeInTheDocument()
  })

  it('displays explanation text', () => {
    render(<ItemsBlockedWarning blockedCount={10} />)
    
    expect(screen.getByText(/missing category classification/i)).toBeInTheDocument()
    expect(screen.getByText(/excluded from pipeline progress/i)).toBeInTheDocument()
  })

  it('renders alert icon', () => {
    const { container } = render(<ItemsBlockedWarning blockedCount={5} />)
    
    const icon = container.querySelector('svg')
    expect(icon).toBeInTheDocument()
    expect(icon).toHaveClass('h-5', 'w-5')
  })
})
