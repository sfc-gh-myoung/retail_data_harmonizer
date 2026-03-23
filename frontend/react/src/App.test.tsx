import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Outlet } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

// Mock the lazy-loaded features
vi.mock('@/features/dashboard', () => ({
  Dashboard: () => <div data-testid="dashboard">Dashboard</div>,
}))

vi.mock('@/features/pipeline', () => ({
  Pipeline: () => <div data-testid="pipeline">Pipeline</div>,
}))

vi.mock('@/features/review', () => ({
  Review: () => <div data-testid="review">Review</div>,
}))

vi.mock('@/features/comparison', () => ({
  Comparison: () => <div data-testid="comparison">Comparison</div>,
}))

vi.mock('@/features/testing', () => ({
  Testing: () => <div data-testid="testing">Testing</div>,
}))

vi.mock('@/features/logs', () => ({
  Logs: () => <div data-testid="logs">Logs</div>,
}))

vi.mock('@/features/settings', () => ({
  Settings: () => <div data-testid="settings">Settings</div>,
}))

// Mock the providers and components
vi.mock('@/providers/query-provider', () => ({
  QueryProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))

vi.mock('@/components/app-layout', () => ({
  AppLayout: () => (
    <div data-testid="app-layout">
      <Outlet />
    </div>
  ),
}))

vi.mock('@/components/feature-error-boundary', () => ({
  FeatureErrorBoundary: ({ children, featureName }: { children: React.ReactNode; featureName: string }) => (
    <div data-testid={`error-boundary-${featureName.toLowerCase()}`}>{children}</div>
  ),
}))

vi.mock('@/components/loading-fallback', () => ({
  LoadingFallback: () => <div data-testid="loading-fallback">Loading...</div>,
}))

vi.mock('@/stores/theme-store', () => ({}))

import { App } from './App'

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
}

function renderWithRouter(initialRoute = '/') {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialRoute]}>
        <App />
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders app layout', async () => {
    renderWithRouter('/')
    
    await waitFor(() => {
      expect(screen.getByTestId('app-layout')).toBeInTheDocument()
    })
  })

  it('renders dashboard on root path', async () => {
    renderWithRouter('/')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-dashboard')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('dashboard')).toBeInTheDocument()
    })
  })

  it('renders pipeline on /pipeline path', async () => {
    renderWithRouter('/pipeline')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-pipeline')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('pipeline')).toBeInTheDocument()
    })
  })

  it('renders review on /review path', async () => {
    renderWithRouter('/review')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-review')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('review')).toBeInTheDocument()
    })
  })

  it('renders comparison on /comparison path', async () => {
    renderWithRouter('/comparison')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-comparison')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('comparison')).toBeInTheDocument()
    })
  })

  it('renders testing on /testing path', async () => {
    renderWithRouter('/testing')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-testing')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('testing')).toBeInTheDocument()
    })
  })

  it('renders logs on /logs path', async () => {
    renderWithRouter('/logs')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-logs')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('logs')).toBeInTheDocument()
    })
  })

  it('renders settings on /settings path', async () => {
    renderWithRouter('/settings')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-settings')).toBeInTheDocument()
    })
    
    await waitFor(() => {
      expect(screen.getByTestId('settings')).toBeInTheDocument()
    })
  })

  it('wraps routes with error boundaries', async () => {
    renderWithRouter('/')
    
    await waitFor(() => {
      expect(screen.getByTestId('error-boundary-dashboard')).toBeInTheDocument()
    })
  })
})
