import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'
import { Suspense, type ReactNode } from 'react'
import { AppErrorAlert } from '@/components/app-error-alert'

interface SectionWrapperProps {
  /** Display name for error messages */
  sectionName: string
  /** Loading fallback (skeleton) */
  fallback: ReactNode
  /** Section content */
  children: ReactNode
}

/**
 * Wraps a section with Suspense for loading states and ErrorBoundary
 * for error isolation. Each section can fail/load independently.
 *
 * Uses QueryErrorResetBoundary to enable retry of failed queries.
 * Uses AppErrorAlert for consistent error display with envelope support.
 */
export function SectionWrapper({ sectionName, fallback, children }: SectionWrapperProps) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ resetErrorBoundary, error }) => (
            <AppErrorAlert
              error={error}
              onRetry={resetErrorBoundary}
              context={sectionName}
              showSetupHint={false}
              reportError={false}
            />
          )}
        >
          <Suspense fallback={fallback}>{children}</Suspense>
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  )
}
