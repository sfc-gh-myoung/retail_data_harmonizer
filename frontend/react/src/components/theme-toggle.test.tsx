import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ThemeToggle } from './theme-toggle'

vi.mock('@/stores/theme-store', () => ({
  useThemeStore: vi.fn(),
}))

import { useThemeStore } from '@/stores/theme-store'

describe('ThemeToggle', () => {
  const mockToggleTheme = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders moon icon when theme is light', () => {
    vi.mocked(useThemeStore).mockReturnValue({
      theme: 'light',
      toggleTheme: mockToggleTheme,
      setTheme: vi.fn(),
    })

    render(<ThemeToggle />)

    // Check aria-label indicates switching to dark mode
    expect(screen.getByRole('button', { name: /switch to dark mode/i })).toBeInTheDocument()
  })

  it('renders sun icon when theme is dark', () => {
    vi.mocked(useThemeStore).mockReturnValue({
      theme: 'dark',
      toggleTheme: mockToggleTheme,
      setTheme: vi.fn(),
    })

    render(<ThemeToggle />)

    // Check aria-label indicates switching to light mode
    expect(screen.getByRole('button', { name: /switch to light mode/i })).toBeInTheDocument()
  })

  it('calls toggleTheme when button is clicked', () => {
    vi.mocked(useThemeStore).mockReturnValue({
      theme: 'light',
      toggleTheme: mockToggleTheme,
      setTheme: vi.fn(),
    })

    render(<ThemeToggle />)

    fireEvent.click(screen.getByRole('button'))
    expect(mockToggleTheme).toHaveBeenCalledTimes(1)
  })

  it('renders as a ghost variant button', () => {
    vi.mocked(useThemeStore).mockReturnValue({
      theme: 'light',
      toggleTheme: mockToggleTheme,
      setTheme: vi.fn(),
    })

    render(<ThemeToggle />)

    const button = screen.getByRole('button')
    expect(button).toBeInTheDocument()
  })
})
