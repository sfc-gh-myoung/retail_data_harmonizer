import { render } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { LoadingFallback } from './loading-fallback'

describe('LoadingFallback', () => {
  it('renders skeleton elements', () => {
    const { container } = render(<LoadingFallback />)

    // Should have multiple skeleton elements
    const skeletons = container.querySelectorAll('[class*="animate-pulse"]')
    expect(skeletons.length).toBeGreaterThan(0)
  })

  it('renders grid of three skeleton cards', () => {
    const { container } = render(<LoadingFallback />)

    // Check for grid container
    const gridContainer = container.querySelector('.grid-cols-3')
    expect(gridContainer).toBeInTheDocument()
  })

  it('renders with proper spacing', () => {
    const { container } = render(<LoadingFallback />)

    // Root element should have spacing
    const rootDiv = container.firstChild as HTMLElement
    expect(rootDiv).toHaveClass('space-y-4')
    expect(rootDiv).toHaveClass('p-4')
  })

  it('renders a header skeleton', () => {
    const { container } = render(<LoadingFallback />)

    // Check for header-sized skeleton (h-8 w-48)
    const headerSkeleton = container.querySelector('.h-8.w-48')
    expect(headerSkeleton).toBeInTheDocument()
  })

  it('renders a large content skeleton', () => {
    const { container } = render(<LoadingFallback />)

    // Check for large skeleton (h-48)
    const largeSkeleton = container.querySelector('.h-48')
    expect(largeSkeleton).toBeInTheDocument()
  })
})
