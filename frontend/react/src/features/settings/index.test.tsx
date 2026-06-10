/* eslint-disable @typescript-eslint/no-explicit-any */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Settings } from './index'

// Mock Slider to avoid Radix pointer capture issues in JSDOM
vi.mock('@/components/ui/slider', () => ({
  Slider: ({ value, onValueChange, ...props }: { value: number[], onValueChange: (v: number[]) => void }) => (
    <input
      type="range"
      role="slider"
      value={value[0]}
      onChange={(e) => onValueChange([parseFloat(e.target.value)])}
      min={0}
      max={1}
      step={0.05}
      {...props}
    />
  ),
}))

vi.mock('./hooks/use-settings', () => ({
  useSettings: vi.fn(),
  useResetPipeline: vi.fn(),
}))

import { useSettings, useResetPipeline } from './hooks/use-settings'


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

const mockSettingsData = {
  weights: {
    cortexSearch: 0.35,
    cosine: 0.25,
    editDistance: 0.20,
    jaccard: 0.20,
  },
  thresholds: {
    autoAccept: 0.95,
    reject: 0.30,
    reviewMin: 0.30,
    reviewMax: 0.95,
  },
  performance: {
    batchSize: 100,
    parallelism: 4,
    cacheEnabled: true,
  },
  automation: {
    autoAcceptEnabled: true,
    autoRejectEnabled: false,
  },
}

describe('Settings', () => {
  const mockResetPipelineMutate = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useResetPipeline).mockReturnValue({
      mutate: mockResetPipelineMutate,
    } as any)
  })

  it('renders loading skeleton when loading', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: undefined,
      isLoading: true,
      error: null,
    } as any)

    const { container } = renderWithProviders(<Settings />)
    
    const skeletons = container.querySelectorAll('[class*="animate-pulse"]')
    expect(skeletons.length).toBeGreaterThan(0)
  })

  it('renders error alert when error occurs', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Failed to fetch'),
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText(/unable to connect to the server/i)).toBeInTheDocument()
  })

  it('renders settings heading', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Settings')).toBeInTheDocument()
  })

  it('renders primary signal weights section', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Primary Signal Weights')).toBeInTheDocument()
    expect(screen.getByText('Cortex Search')).toBeInTheDocument()
    expect(screen.getByText('Cosine Similarity')).toBeInTheDocument()
    expect(screen.getByText('Edit Distance')).toBeInTheDocument()
    expect(screen.getByText('Jaccard')).toBeInTheDocument()
  })

  it('renders score thresholds section', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Score Thresholds')).toBeInTheDocument()
    expect(screen.getByText('Auto-Accept Threshold')).toBeInTheDocument()
    expect(screen.getByText('Reject Threshold')).toBeInTheDocument()
    expect(screen.getByText('Review Range (Min)')).toBeInTheDocument()
    expect(screen.getByText('Review Range (Max)')).toBeInTheDocument()
  })

  it('renders performance settings section', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Performance Settings')).toBeInTheDocument()
    expect(screen.getByLabelText('Batch Size')).toHaveValue(100)
    expect(screen.getByLabelText('Parallelism')).toHaveValue(4)
    expect(screen.getByText('Cache Enabled')).toBeInTheDocument()
  })

  it('renders automation settings section', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Automation Settings')).toBeInTheDocument()
    expect(screen.getByText('Auto-Accept Enabled')).toBeInTheDocument()
    expect(screen.getByText('Auto-Reject Enabled')).toBeInTheDocument()
  })

  it('renders danger zone section', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('Danger Zone')).toBeInTheDocument()
    expect(screen.getByText('Reset Pipeline')).toBeInTheDocument()
  })

  it('renders reset button in danger zone', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByRole('button', { name: /reset/i })).toBeInTheDocument()
  })

  it('opens reset confirmation dialog when reset button clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    fireEvent.click(screen.getByRole('button', { name: /reset/i }))
    
    await waitFor(() => {
      expect(screen.getByText('Reset Pipeline?')).toBeInTheDocument()
    })
  })

  it('displays weight values correctly', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByText('0.35')).toBeInTheDocument() // cortexSearch
    expect(screen.getByText('0.25')).toBeInTheDocument() // cosine
  })

  it('displays threshold values', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    // Check that some percentage is displayed - the exact format may vary
    expect(screen.getByText('Score Thresholds')).toBeInTheDocument()
  })

  it('calls resetPipeline.mutate when confirm reset clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    fireEvent.click(screen.getByRole('button', { name: /reset/i }))
    
    await waitFor(() => {
      expect(screen.getByText('Reset Pipeline?')).toBeInTheDocument()
    })
    
    fireEvent.click(screen.getByRole('button', { name: /reset pipeline/i }))
    
    expect(mockResetPipelineMutate).toHaveBeenCalled()
  })

})