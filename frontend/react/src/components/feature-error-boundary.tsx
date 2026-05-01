import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'
import { AppErrorAlert } from '@/components/app-error-alert'

interface FeatureErrorBoundaryProps {
  children: React.ReactNode
  featureName?: string
}

export function FeatureErrorBoundary({ children, featureName }: FeatureErrorBoundaryProps) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ error, resetErrorBoundary }) => (
            <AppErrorAlert
              error={error}
              onRetry={resetErrorBoundary}
              context={featureName}
              showSetupHint={true}
              reportError={true}
            />
          )}
        >
          {children}
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  )
}
