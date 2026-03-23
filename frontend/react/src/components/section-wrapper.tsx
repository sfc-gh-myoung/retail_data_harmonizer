import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'
import { Suspense, type ReactNode } from 'react'
import { AlertCircle, RefreshCw, Server, FileQuestion } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { ApiError } from '@/lib/api'

interface SectionErrorProps {
  sectionName: string
  onRetry: () => void
  error: unknown
}

function SectionErrorFallback({ sectionName, onRetry, error }: SectionErrorProps) {
  const isBackendError = error instanceof ApiError && error.isBackendUnavailable()
  const isNotFoundError = error instanceof ApiError && error.isNotFound()
  const message = error instanceof ApiError 
    ? error.getUserMessage() 
    : 'Something went wrong loading this section.'

  let icon = <AlertCircle className="h-4 w-4" />
  let title = `Failed to load ${sectionName}`

  if (isBackendError) {
    icon = <Server className="h-4 w-4" />
    title = 'Backend Not Available'
  } else if (isNotFoundError) {
    icon = <FileQuestion className="h-4 w-4" />
    title = 'Feature Not Available'
  }

  return (
    <Alert variant="destructive" className="my-2">
      {icon}
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription className="flex items-center gap-3 mt-2">
        <span className="text-sm">{message}</span>
        <Button variant="outline" size="sm" onClick={onRetry}>
          <RefreshCw className="h-3 w-3 mr-1" />
          Retry
        </Button>
      </AlertDescription>
    </Alert>
  )
}

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
 */
export function SectionWrapper({ sectionName, fallback, children }: SectionWrapperProps) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ resetErrorBoundary, error }) => (
            <SectionErrorFallback sectionName={sectionName} onRetry={resetErrorBoundary} error={error} />
          )}
        >
          <Suspense fallback={fallback}>{children}</Suspense>
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  )
}
