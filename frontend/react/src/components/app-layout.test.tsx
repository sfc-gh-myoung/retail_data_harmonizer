import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AppLayout } from './app-layout'

vi.mock('@/stores/theme-store', () => ({
  useThemeStore: () => ({
    theme: 'light',
    toggleTheme: vi.fn(),
    setTheme: vi.fn(),
  }),
}))

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
}

function renderWithProviders(ui: React.ReactElement, { route = '/' } = {}) {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[route]}>
        {ui}
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('AppLayout', () => {
  it('renders the application title', () => {
    renderWithProviders(<AppLayout />)

    expect(screen.getByText('Retail Data Harmonizer')).toBeInTheDocument()
  })

  it('renders the header element', () => {
    const { container } = renderWithProviders(<AppLayout />)

    const header = container.querySelector('header')
    expect(header).toBeInTheDocument()
  })

  it('renders the sidebar', () => {
    renderWithProviders(<AppLayout />)

    // Sidebar contains navigation items
    expect(screen.getByText('Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Pipeline')).toBeInTheDocument()
    expect(screen.getByText('Review')).toBeInTheDocument()
  })

  it('renders the theme toggle', () => {
    renderWithProviders(<AppLayout />)

    // ThemeToggle button is present
    expect(screen.getByRole('button', { name: /switch to dark mode/i })).toBeInTheDocument()
  })

  it('renders main content area', () => {
    const { container } = renderWithProviders(<AppLayout />)

    const main = container.querySelector('main')
    expect(main).toBeInTheDocument()
  })

  it('has proper layout structure with flex container', () => {
    const { container } = renderWithProviders(<AppLayout />)

    // Check for header followed by flex container
    const header = container.querySelector('header')
    expect(header).toBeInTheDocument()

    // The main flex container should exist
    const flexContainer = container.querySelector('.flex')
    expect(flexContainer).toBeInTheDocument()
  })
})
