import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { FeatureErrorBoundary } from './feature-error-boundary'
import { ApiError } from '@/lib/api'

// Component that throws an error for testing
function ThrowError({ shouldThrow, message = 'Test error' }: { shouldThrow: boolean; message?: string }) {
  if (shouldThrow) {
    throw new Error(message)
  }
  return <div>Child content</div>
}

// Component that throws an ApiError for testing
function ThrowApiError({ 
  shouldThrow, 
  status = 500,
  message = 'API Error'
}: { 
  shouldThrow: boolean
  status?: number
  message?: string
}) {
  if (shouldThrow) {
    throw new ApiError(status, message)
  }
  return <div>Child content</div>
}

// Component that throws a TypeError with fetch message
function ThrowTypeError({ shouldThrow }: { shouldThrow: boolean }) {
  if (shouldThrow) {
    throw new TypeError('Failed to fetch')
  }
  return <div>Child content</div>
}

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
}

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
  )
}

describe('FeatureErrorBoundary', () => {
  beforeEach(() => {
    // Suppress console.error for cleaner test output
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  it('renders children when no error occurs', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <div>Test content</div>
      </FeatureErrorBoundary>
    )

    expect(screen.getByText('Test content')).toBeInTheDocument()
  })

  it('renders error alert when child throws', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <ThrowError shouldThrow={true} />
      </FeatureErrorBoundary>
    )

    // Component shows "Error" title and the actual error message
    expect(screen.getByText('Error')).toBeInTheDocument()
    expect(screen.getByText('Test error')).toBeInTheDocument()
  })

  it('accepts featureName prop (used for context)', () => {
    renderWithProviders(
      <FeatureErrorBoundary featureName="dashboard">
        <ThrowError shouldThrow={true} />
      </FeatureErrorBoundary>
    )

    // Component shows "Error" title regardless of featureName
    expect(screen.getByText('Error')).toBeInTheDocument()
  })

  it('displays the error message from Error instance', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <ThrowError shouldThrow={true} message="Custom error message" />
      </FeatureErrorBoundary>
    )

    expect(screen.getByText('Custom error message')).toBeInTheDocument()
  })

  it('renders try again button', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <ThrowError shouldThrow={true} />
      </FeatureErrorBoundary>
    )

    expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument()
  })

  it('resets error state when try again is clicked', () => {
    // Use a stateful approach with a ref to track throws
    const throwTracker = { shouldThrow: true }
    
    function ConditionalThrow() {
      if (throwTracker.shouldThrow) {
        throw new Error('First render error')
      }
      return <div>Success after retry</div>
    }

    renderWithProviders(
      <FeatureErrorBoundary>
        <ConditionalThrow />
      </FeatureErrorBoundary>
    )

    // Error UI should be shown
    expect(screen.getByText('Error')).toBeInTheDocument()

    // Update the tracker so next render doesn't throw
    throwTracker.shouldThrow = false

    // Click retry
    fireEvent.click(screen.getByRole('button', { name: /try again/i }))

    // Should re-render children successfully
    expect(screen.getByText('Success after retry')).toBeInTheDocument()
  })

  it('shows generic Error title when featureName is not provided', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <ThrowError shouldThrow={true} />
      </FeatureErrorBoundary>
    )

    // Component shows generic "Error" title for standard Error instances
    expect(screen.getByText('Error')).toBeInTheDocument()
    expect(screen.getByText('Test error')).toBeInTheDocument()
  })

  it('renders destructive alert variant', () => {
    renderWithProviders(
      <FeatureErrorBoundary>
        <ThrowError shouldThrow={true} />
      </FeatureErrorBoundary>
    )

    // The alert should be present with the error content
    expect(screen.getByRole('alert')).toBeInTheDocument()
  })

  describe('ApiError handling', () => {
    it('shows "Backend Not Available" for network errors (status 0)', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={0} message="Network error: Unable to reach the server" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('Backend Not Available')).toBeInTheDocument()
      expect(screen.getByText('Unable to connect to the server. Please check if the backend is running.')).toBeInTheDocument()
    })

    it('shows setup hint for backend unavailable errors', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={0} message="Network error" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('To start the backend:')).toBeInTheDocument()
      expect(screen.getByText('make api-serve')).toBeInTheDocument()
    })

    it('shows "Feature Not Available" for 404 errors', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={404} message="Not found" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('Feature Not Available')).toBeInTheDocument()
      expect(screen.getByText('This feature is not available yet. You may need to run the demo setup first.')).toBeInTheDocument()
    })

    it('shows setup hint for 404 errors', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={404} message="Not found" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('To start the backend:')).toBeInTheDocument()
    })

    it('shows "API Error" for other API errors (e.g., 500)', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={500} message="Internal server error" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('API Error')).toBeInTheDocument()
      expect(screen.getByText('The server encountered an error. Please try again later.')).toBeInTheDocument()
    })

    it('does not show setup hint for generic API errors', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={500} message="Server error" />
        </FeatureErrorBoundary>
      )

      expect(screen.queryByText('To start the backend:')).not.toBeInTheDocument()
    })

    it('shows "API Error" for validation errors (422)', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowApiError shouldThrow={true} status={422} message="Validation failed" />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('API Error')).toBeInTheDocument()
      expect(screen.getByText('The request was invalid. Please check your input and try again.')).toBeInTheDocument()
    })
  })

  describe('TypeError handling', () => {
    it('shows "Connection Error" for TypeError with fetch message', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowTypeError shouldThrow={true} />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('Connection Error')).toBeInTheDocument()
      expect(screen.getByText('Unable to connect to the server. The backend may not be running.')).toBeInTheDocument()
    })

    it('shows setup hint for connection errors', () => {
      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowTypeError shouldThrow={true} />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('To start the backend:')).toBeInTheDocument()
    })
  })

  describe('Unknown error handling', () => {
    it('shows generic error for non-Error thrown values', () => {
      function ThrowNonError({ shouldThrow }: { shouldThrow: boolean }) {
        if (shouldThrow) {
          throw 'string error'
        }
        return <div>Child content</div>
      }

      renderWithProviders(
        <FeatureErrorBoundary>
          <ThrowNonError shouldThrow={true} />
        </FeatureErrorBoundary>
      )

      expect(screen.getByText('Error')).toBeInTheDocument()
      expect(screen.getByText('An unexpected error occurred')).toBeInTheDocument()
    })
  })
})