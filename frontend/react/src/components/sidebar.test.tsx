import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { MemoryRouter } from 'react-router-dom'
import { Sidebar } from './sidebar'

function renderWithRouter(ui: React.ReactElement, { route = '/' } = {}) {
  return render(
    <MemoryRouter initialEntries={[route]}>
      {ui}
    </MemoryRouter>
  )
}

describe('Sidebar', () => {
  it('renders all navigation items', () => {
    renderWithRouter(<Sidebar />)

    expect(screen.getByText('Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Pipeline')).toBeInTheDocument()
    expect(screen.getByText('Review')).toBeInTheDocument()
    expect(screen.getByText('Comparison')).toBeInTheDocument()
    expect(screen.getByText('Testing')).toBeInTheDocument()
    expect(screen.getByText('Logs')).toBeInTheDocument()
    expect(screen.getByText('Settings')).toBeInTheDocument()
  })

  it('renders navigation links with correct hrefs', () => {
    renderWithRouter(<Sidebar />)

    const dashboardLink = screen.getByText('Dashboard').closest('a')
    const pipelineLink = screen.getByText('Pipeline').closest('a')
    const reviewLink = screen.getByText('Review').closest('a')
    const comparisonLink = screen.getByText('Comparison').closest('a')
    const testingLink = screen.getByText('Testing').closest('a')
    const logsLink = screen.getByText('Logs').closest('a')
    const settingsLink = screen.getByText('Settings').closest('a')

    expect(dashboardLink).toHaveAttribute('href', '/')
    expect(pipelineLink).toHaveAttribute('href', '/pipeline')
    expect(reviewLink).toHaveAttribute('href', '/review')
    expect(comparisonLink).toHaveAttribute('href', '/comparison')
    expect(testingLink).toHaveAttribute('href', '/testing')
    expect(logsLink).toHaveAttribute('href', '/logs')
    expect(settingsLink).toHaveAttribute('href', '/settings')
  })

  it('applies active styles to Dashboard when on root path', () => {
    renderWithRouter(<Sidebar />, { route: '/' })

    const dashboardLink = screen.getByText('Dashboard').closest('a')
    expect(dashboardLink).toHaveClass('bg-primary')
    expect(dashboardLink).toHaveClass('text-primary-foreground')
  })

  it('applies active styles to Pipeline when on /pipeline path', () => {
    renderWithRouter(<Sidebar />, { route: '/pipeline' })

    const pipelineLink = screen.getByText('Pipeline').closest('a')
    expect(pipelineLink).toHaveClass('bg-primary')
    expect(pipelineLink).toHaveClass('text-primary-foreground')
  })

  it('applies active styles to Review when on /review path', () => {
    renderWithRouter(<Sidebar />, { route: '/review' })

    const reviewLink = screen.getByText('Review').closest('a')
    expect(reviewLink).toHaveClass('bg-primary')
    expect(reviewLink).toHaveClass('text-primary-foreground')
  })

  it('does not apply active styles to Dashboard when on other routes', () => {
    renderWithRouter(<Sidebar />, { route: '/pipeline' })

    const dashboardLink = screen.getByText('Dashboard').closest('a')
    expect(dashboardLink).not.toHaveClass('bg-primary')
    expect(dashboardLink).toHaveClass('text-muted-foreground')
  })

  it('renders as aside element', () => {
    const { container } = renderWithRouter(<Sidebar />)

    const aside = container.querySelector('aside')
    expect(aside).toBeInTheDocument()
  })

  it('renders navigation within nav element', () => {
    const { container } = renderWithRouter(<Sidebar />)

    const nav = container.querySelector('nav')
    expect(nav).toBeInTheDocument()
    expect(nav?.querySelectorAll('a')).toHaveLength(7)
  })
})
