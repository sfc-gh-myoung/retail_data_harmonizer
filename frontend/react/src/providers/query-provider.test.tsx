import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { useQueryClient } from '@tanstack/react-query'
import { QueryProvider } from './query-provider'

function TestComponent() {
  const queryClient = useQueryClient()
  return (
    <div data-testid="test-child">
      Query client exists: {queryClient ? 'yes' : 'no'}
    </div>
  )
}

describe('QueryProvider', () => {
  it('renders children', () => {
    render(
      <QueryProvider>
        <div data-testid="child">Child content</div>
      </QueryProvider>
    )
    
    expect(screen.getByTestId('child')).toBeInTheDocument()
    expect(screen.getByText('Child content')).toBeInTheDocument()
  })

  it('provides QueryClient to children', () => {
    render(
      <QueryProvider>
        <TestComponent />
      </QueryProvider>
    )
    
    expect(screen.getByTestId('test-child')).toBeInTheDocument()
    expect(screen.getByText(/Query client exists: yes/)).toBeInTheDocument()
  })

  it('allows nested components to access query client', () => {
    const NestedComponent = () => {
      const client = useQueryClient()
      return <span>Has client: {client ? 'true' : 'false'}</span>
    }

    render(
      <QueryProvider>
        <div>
          <NestedComponent />
        </div>
      </QueryProvider>
    )

    expect(screen.getByText('Has client: true')).toBeInTheDocument()
  })
})
