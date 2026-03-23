import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { SectionWrapper } from './section-wrapper'
import { ApiError } from '@/lib/api'

// Component that loads asynchronously via Suspense
function AsyncContent({ shouldResolve }: { shouldResolve: boolean }) {
  if (!shouldResolve) {
    throw new Promise(() => {}) // Never resolves - stays in loading state
  }
  return <div>Loaded content</div>
}

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

describe('SectionWrapper', () => {
  beforeEach(() => {
    // Suppress console.error for cleaner test output
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  describe('successful rendering', () => {
    it('renders children when no error occurs', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Test Section" fallback={<div>Loading...</div>}>
          <div>Section content</div>
        </SectionWrapper>
      )

      expect(screen.getByText('Section content')).toBeInTheDocument()
    })

    it('renders complex nested children', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Dashboard" fallback={<div>Loading...</div>}>
          <div>
            <h2>Title</h2>
            <p>Description</p>
          </div>
        </SectionWrapper>
      )

      expect(screen.getByText('Title')).toBeInTheDocument()
      expect(screen.getByText('Description')).toBeInTheDocument()
    })
  })

  describe('loading states', () => {
    it('shows fallback during Suspense loading', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Test Section" fallback={<div>Custom loading skeleton...</div>}>
          <AsyncContent shouldResolve={false} />
        </SectionWrapper>
      )

      expect(screen.getByText('Custom loading skeleton...')).toBeInTheDocument()
    })

    it('accepts any ReactNode as fallback', () => {
      renderWithProviders(
        <SectionWrapper 
          sectionName="Test Section" 
          fallback={
            <div className="skeleton">
              <div>Row 1</div>
              <div>Row 2</div>
            </div>
          }
        >
          <AsyncContent shouldResolve={false} />
        </SectionWrapper>
      )

      expect(screen.getByText('Row 1')).toBeInTheDocument()
      expect(screen.getByText('Row 2')).toBeInTheDocument()
    })
  })

  describe('error handling', () => {
    it('catches errors and shows error fallback', () => {
      renderWithProviders(
        <SectionWrapper sectionName="KPIs" fallback={<div>Loading...</div>}>
          <ThrowError shouldThrow={true} message="Fetch failed" />
        </SectionWrapper>
      )

      expect(screen.getByText('Failed to load KPIs')).toBeInTheDocument()
    })

    it('shows Retry button when error occurs', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Charts" fallback={<div>Loading...</div>}>
          <ThrowError shouldThrow={true} />
        </SectionWrapper>
      )

      expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument()
    })

    it('displays generic message for non-ApiError', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Data" fallback={<div>Loading...</div>}>
          <ThrowError shouldThrow={true} message="Some error" />
        </SectionWrapper>
      )

      // SectionWrapper shows generic message for non-ApiError types
      expect(screen.getByText('Something went wrong loading this section.')).toBeInTheDocument()
    })
  })

  describe('ApiError handling', () => {
    it('shows "Backend Not Available" title for network errors', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Stats" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={0} message="Network error" />
        </SectionWrapper>
      )

      expect(screen.getByText('Backend Not Available')).toBeInTheDocument()
    })

    it('shows user-friendly message for network errors', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Stats" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={0} message="Network error" />
        </SectionWrapper>
      )

      expect(screen.getByText('Unable to connect to the server. Please check if the backend is running.')).toBeInTheDocument()
    })

    it('shows "Feature Not Available" title for 404 errors', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Stats" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={404} message="Not found" />
        </SectionWrapper>
      )

      expect(screen.getByText('Feature Not Available')).toBeInTheDocument()
    })

    it('shows user-friendly message for 404 errors', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Stats" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={404} message="Not found" />
        </SectionWrapper>
      )

      expect(screen.getByText('This feature is not available yet. You may need to run the demo setup first.')).toBeInTheDocument()
    })

    it('shows default title for server errors (500)', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Metrics" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={500} message="Server error" />
        </SectionWrapper>
      )

      expect(screen.getByText('Failed to load Metrics')).toBeInTheDocument()
    })

    it('shows user-friendly message for server errors', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Stats" fallback={<div>Loading...</div>}>
          <ThrowApiError shouldThrow={true} status={500} message="Server error" />
        </SectionWrapper>
      )

      expect(screen.getByText('The server encountered an error. Please try again later.')).toBeInTheDocument()
    })
  })

  describe('retry functionality', () => {
    it('resets error state when Retry is clicked', async () => {
      const throwTracker = { shouldThrow: true }
      
      function ConditionalThrow() {
        if (throwTracker.shouldThrow) {
          throw new Error('First render error')
        }
        return <div>Success after retry</div>
      }

      renderWithProviders(
        <SectionWrapper sectionName="Test" fallback={<div>Loading...</div>}>
          <ConditionalThrow />
        </SectionWrapper>
      )

      // Error UI should be shown
      expect(screen.getByText('Failed to load Test')).toBeInTheDocument()

      // Update the tracker so next render doesn't throw
      throwTracker.shouldThrow = false

      // Click retry
      fireEvent.click(screen.getByRole('button', { name: /retry/i }))

      // Should re-render children successfully
      await waitFor(() => {
        expect(screen.getByText('Success after retry')).toBeInTheDocument()
      })
    })

    it('keeps showing error UI after retry if error persists', async () => {
      const throwTracker = { shouldThrow: true }
      
      function AlwaysThrow() {
        if (throwTracker.shouldThrow) {
          throw new Error('Persistent error')
        }
        return <div>Should not render</div>
      }

      renderWithProviders(
        <SectionWrapper sectionName="Persistent Error" fallback={<div>Loading...</div>}>
          <AlwaysThrow />
        </SectionWrapper>
      )

      // First error - shows generic message
      expect(screen.getByText('Failed to load Persistent Error')).toBeInTheDocument()

      // Click retry - still shows error
      fireEvent.click(screen.getByRole('button', { name: /retry/i }))

      // Should still show error
      await waitFor(() => {
        expect(screen.getByText('Failed to load Persistent Error')).toBeInTheDocument()
      })
    })
  })

  describe('alert styling', () => {
    it('renders destructive alert variant', () => {
      renderWithProviders(
        <SectionWrapper sectionName="Test" fallback={<div>Loading...</div>}>
          <ThrowError shouldThrow={true} />
        </SectionWrapper>
      )

      expect(screen.getByRole('alert')).toBeInTheDocument()
    })
  })

  describe('non-Error objects', () => {
    it('shows generic message for non-Error thrown values', () => {
      function ThrowNonError({ shouldThrow }: { shouldThrow: boolean }) {
        if (shouldThrow) {
          throw 'string error'
        }
        return <div>Child content</div>
      }

      renderWithProviders(
        <SectionWrapper sectionName="Test" fallback={<div>Loading...</div>}>
          <ThrowNonError shouldThrow={true} />
        </SectionWrapper>
      )

      expect(screen.getByText('Something went wrong loading this section.')).toBeInTheDocument()
    })
  })
})
