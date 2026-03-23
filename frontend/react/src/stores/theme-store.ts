import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

type Theme = 'light' | 'dark'

interface ThemeStore {
  theme: Theme
  setTheme: (theme: Theme) => void
  toggleTheme: () => void
}

export const useThemeStore = create<ThemeStore>()(
  persist(
    (set) => ({
      theme: 'light',
      setTheme: (theme) => {
        set({ theme })
        updateDocumentTheme(theme)
      },
      toggleTheme: () => {
        set((state) => {
          const newTheme = state.theme === 'light' ? 'dark' : 'light'
          updateDocumentTheme(newTheme)
          return { theme: newTheme }
        })
      },
    }),
    {
      name: 'theme-store',
      storage: createJSONStorage(() => {
        // SSR/private browsing safety: fall back to sessionStorage if localStorage unavailable
        try {
          return localStorage
        } catch {
          return sessionStorage
        }
      }),
      onRehydrateStorage: () => (state) => {
        // Apply theme to document after hydration
        if (state?.theme) {
          updateDocumentTheme(state.theme)
        }
      },
    }
  )
)

function updateDocumentTheme(theme: Theme) {
  if (typeof document !== 'undefined') {
    const root = document.documentElement
    root.classList.remove('light', 'dark')
    root.classList.add(theme)
  }
}

// Initialize theme on first load (client-side only)
if (typeof window !== 'undefined') {
  const stored = localStorage.getItem('theme-store')
  if (stored) {
    try {
      const { state } = JSON.parse(stored)
      if (state?.theme) {
        updateDocumentTheme(state.theme)
      }
    } catch {
      // Ignore parse errors
    }
  }
}
