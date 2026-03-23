import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { DateCell } from './date-cell'

describe('DateCell', () => {
  it('renders null value as dash', () => {
    render(<DateCell value={null} />)
    
    expect(screen.getByText('—')).toBeInTheDocument()
  })

  it('renders invalid date string', () => {
    render(<DateCell value="not a date" />)
    
    expect(screen.getByText('Invalid date')).toBeInTheDocument()
  })

  it('renders date in short format by default', () => {
    render(<DateCell value="2024-03-15T10:30:00Z" />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toBeInTheDocument()
    // Short format includes month name
    expect(timeElement.textContent).toMatch(/Mar/)
    expect(timeElement.textContent).toMatch(/15/)
    expect(timeElement.textContent).toMatch(/2024/)
  })

  it('renders date in long format', () => {
    render(<DateCell value="2024-03-15T10:30:00Z" format="long" />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toBeInTheDocument()
    // Long format includes full month name
    expect(timeElement.textContent).toMatch(/March/)
  })

  it('renders date in relative format', () => {
    // Use a date in the past
    const pastDate = new Date()
    pastDate.setDate(pastDate.getDate() - 2)
    
    render(<DateCell value={pastDate} format="relative" />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toBeInTheDocument()
    // Relative format should say something like "2 days ago"
    expect(timeElement.textContent).toMatch(/ago|day/)
  })

  it('accepts Date object as value', () => {
    const date = new Date('2024-06-20T14:00:00Z')
    render(<DateCell value={date} />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toBeInTheDocument()
  })

  it('sets datetime attribute on time element', () => {
    render(<DateCell value="2024-03-15T10:30:00Z" />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toHaveAttribute('datetime')
  })

  it('sets title attribute with long format', () => {
    render(<DateCell value="2024-03-15T10:30:00Z" />)
    
    const timeElement = screen.getByRole('time')
    expect(timeElement).toHaveAttribute('title')
    expect(timeElement.getAttribute('title')).toMatch(/March/)
  })
})
