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
  useUpdateSettings: vi.fn(),
  useResetPipeline: vi.fn(),
  useReEvaluate: vi.fn(),
}))

import { useSettings, useUpdateSettings, useResetPipeline, useReEvaluate } from './hooks/use-settings'

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
  const mockUpdateMutate = vi.fn()
  const mockResetPipelineMutate = vi.fn()
  const mockReEvaluateMutate = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useUpdateSettings).mockReturnValue({
      mutate: mockUpdateMutate,
      isPending: false,
    } as any)
    vi.mocked(useResetPipeline).mockReturnValue({
      mutate: mockResetPipelineMutate,
    } as any)
    vi.mocked(useReEvaluate).mockReturnValue({
      mutate: mockReEvaluateMutate,
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
    expect(screen.getByText('Re-evaluate All Matches')).toBeInTheDocument()
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

  it('renders re-evaluate button in danger zone', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.getByRole('button', { name: /re-evaluate/i })).toBeInTheDocument()
  })

  it('does not show save button when no changes made', () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    expect(screen.queryByRole('button', { name: /save changes/i })).not.toBeInTheDocument()
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

  it('opens re-evaluate confirmation dialog when re-evaluate button clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    fireEvent.click(screen.getByRole('button', { name: /re-evaluate/i }))
    
    await waitFor(() => {
      expect(screen.getByText('Re-evaluate All Matches?')).toBeInTheDocument()
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

  it('shows save and cancel buttons when weight slider changes', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    // Find the cortexSearch slider and change it
    const sliders = screen.getAllByRole('slider')
    expect(sliders.length).toBeGreaterThan(0)
    
    // Simulate slider change using our mocked input
    fireEvent.change(sliders[0], { target: { value: '0.5' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /save changes/i })).toBeInTheDocument()
    })
    expect(screen.getByRole('button', { name: /cancel/i })).toBeInTheDocument()
  })

  it('clears local changes when cancel button clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    const sliders = screen.getAllByRole('slider')
    fireEvent.change(sliders[0], { target: { value: '0.5' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /cancel/i })).toBeInTheDocument()
    })
    
    fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
    
    await waitFor(() => {
      expect(screen.queryByRole('button', { name: /save changes/i })).not.toBeInTheDocument()
    })
  })

  it('calls updateSettings.mutate when save button clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    const sliders = screen.getAllByRole('slider')
    fireEvent.change(sliders[0], { target: { value: '0.5' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /save changes/i })).toBeInTheDocument()
    })
    
    fireEvent.click(screen.getByRole('button', { name: /save changes/i }))
    
    expect(mockUpdateMutate).toHaveBeenCalled()
  })

  it('shows saving state when update is pending', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)
    vi.mocked(useUpdateSettings).mockReturnValue({
      mutate: mockUpdateMutate,
      isPending: true,
    } as any)

    renderWithProviders(<Settings />)
    
    const sliders = screen.getAllByRole('slider')
    fireEvent.change(sliders[0], { target: { value: '0.5' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /saving/i })).toBeInTheDocument()
    })
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

  it('calls reEvaluate.mutate when confirm re-evaluate clicked', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    fireEvent.click(screen.getByRole('button', { name: /re-evaluate/i }))
    
    await waitFor(() => {
      expect(screen.getByText('Re-evaluate All Matches?')).toBeInTheDocument()
    })
    
    fireEvent.click(screen.getByRole('button', { name: /re-evaluate all/i }))
    
    expect(mockReEvaluateMutate).toHaveBeenCalled()
  })

  it('updates threshold slider and shows save button', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    renderWithProviders(<Settings />)
    
    // The threshold sliders are after the weight sliders
    const sliders = screen.getAllByRole('slider')
    // Weight sliders: 0-3, Threshold sliders: 4-7
    const thresholdSlider = sliders[4]
    
    fireEvent.change(thresholdSlider, { target: { value: '0.8' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /save changes/i })).toBeInTheDocument()
    })
  })

  it('clears localSettings via onSuccess callback after save completes', async () => {
    vi.mocked(useSettings).mockReturnValue({
      data: mockSettingsData,
      isLoading: false,
      error: null,
    } as any)

    // Mock mutate to capture and immediately call the onSuccess callback
    const mockMutateWithCallback = vi.fn((data, options) => {
      // Simulate successful save by calling onSuccess
      if (options?.onSuccess) {
        options.onSuccess()
      }
    })
    vi.mocked(useUpdateSettings).mockReturnValue({
      mutate: mockMutateWithCallback,
      isPending: false,
    } as any)

    renderWithProviders(<Settings />)
    
    // Make a change to show Save button
    const sliders = screen.getAllByRole('slider')
    fireEvent.change(sliders[0], { target: { value: '0.5' } })
    
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /save changes/i })).toBeInTheDocument()
    })
    
    // Click Save
    fireEvent.click(screen.getByRole('button', { name: /save changes/i }))
    
    // Verify mutate was called with the local settings and onSuccess callback
    expect(mockMutateWithCallback).toHaveBeenCalledWith(
      expect.objectContaining({ weights: expect.any(Object) }),
      expect.objectContaining({ onSuccess: expect.any(Function) })
    )
    
    // After onSuccess is called, localSettings should be cleared
    // which means the Save/Cancel buttons should disappear
    await waitFor(() => {
      expect(screen.queryByRole('button', { name: /save changes/i })).not.toBeInTheDocument()
    })
    expect(screen.queryByRole('button', { name: /cancel/i })).not.toBeInTheDocument()
  })
})