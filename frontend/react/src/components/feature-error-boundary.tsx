import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'
import { AlertTriangle, RefreshCw, Server, WifiOff, FileQuestion } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { ApiError } from '@/lib/api'

interface FeatureErrorBoundaryProps {
  children: React.ReactNode
  featureName?: string
}

function getErrorInfo(error: unknown): {
  title: string
  message: string
  icon: React.ReactNode
  showSetupHint: boolean
} {
  if (error instanceof ApiError) {
    if (error.isBackendUnavailable()) {
      return {
        title: 'Backend Not Available',
        message: error.getUserMessage(),
        icon: <Server className="h-4 w-4" />,
        showSetupHint: true,
      }
    }
    if (error.isNotFound()) {
      return {
        title: 'Feature Not Available',
        message: error.getUserMessage(),
        icon: <FileQuestion className="h-4 w-4" />,
        showSetupHint: true,
      }
    }
    return {
      title: 'API Error',
      message: error.getUserMessage(),
      icon: <AlertTriangle className="h-4 w-4" />,
      showSetupHint: false,
    }
  }

  if (error instanceof TypeError && error.message.includes('fetch')) {
    return {
      title: 'Connection Error',
      message: 'Unable to connect to the server. The backend may not be running.',
      icon: <WifiOff className="h-4 w-4" />,
      showSetupHint: true,
    }
  }

  return {
    title: 'Error',
    message: error instanceof Error ? error.message : 'An unexpected error occurred',
    icon: <AlertTriangle className="h-4 w-4" />,
    showSetupHint: false,
  }
}

export function FeatureErrorBoundary({ children }: FeatureErrorBoundaryProps) {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ error, resetErrorBoundary }) => {
            const { title, message, icon, showSetupHint } = getErrorInfo(error)
            
            return (
              <Alert variant="destructive" className="my-4">
                {icon}
                <AlertTitle>{title}</AlertTitle>
                <AlertDescription className="mt-2 space-y-3">
                  <p>{message}</p>
                  
                  {showSetupHint && (
                    <div className="mt-3 p-3 bg-muted/50 rounded-md text-sm">
                      <p className="font-medium mb-1">To start the backend:</p>
                      <code className="block bg-background px-2 py-1 rounded text-xs">
                        make api-serve
                      </code>
                    </div>
                  )}
                  
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => resetErrorBoundary()}
                  >
                    <RefreshCw className="h-4 w-4 mr-2" />
                    Try Again
                  </Button>
                </AlertDescription>
              </Alert>
            )
          }}
        >
          {children}
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  )
}
