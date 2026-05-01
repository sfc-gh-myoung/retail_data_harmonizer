/**
 * Reusable error alert component with structured error envelope support.
 *
 * Provides consistent error display across feature boundaries and sections,
 * with support for:
 * - Backend ErrorEnvelope parsing and classification
 * - Actionable guidance and retry buttons
 * - Technical details disclosure (collapsible)
 * - Request ID display for debugging
 * - Severity-based visual variants (info/warning/error/critical)
 * - Optional client error reporting to backend
 */

import { useState, useEffect } from 'react'
import {
  AlertCircle,
  AlertTriangle,
  Info,
  XCircle,
  RefreshCw,
  ChevronDown,
  ChevronUp,
  Server,
  FileQuestion,
  WifiOff,
} from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { ApiError } from '@/lib/api'
import { reportClientError } from '@/lib/report-client-error'
import type { ApiErrorEnvelope } from '@/lib/schemas'
import {
  getErrorRenderingHints,
  getCategoryTitle,
  getErrorActions,
  normalizeErrorEnvelope,
  formatRequestId,
  isNetworkPolicyError,
} from '@/lib/error-classification'

interface AppErrorAlertProps {
  /** Error object (ApiError, Error, or unknown) */
  error: unknown
  /** Optional retry callback */
  onRetry?: () => void
  /** Optional context label (e.g., "Dashboard", "Match Review") */
  context?: string
  /** Whether to show backend setup hint for network errors */
  showSetupHint?: boolean
  /** Whether to report client-side errors to backend (for render errors) */
  reportError?: boolean
}

/**
 * Get icon component based on error type and severity.
 */
function getErrorIcon(
  error: ApiError | null,
  envelope: ApiErrorEnvelope | null
): React.ReactNode {
  // Use envelope severity/category for icon selection if available
  if (envelope) {
    const hints = getErrorRenderingHints(envelope)
    switch (hints.icon) {
      case 'x-circle':
        return <XCircle className="h-4 w-4" />
      case 'alert-triangle':
        return <AlertTriangle className="h-4 w-4" />
      case 'info':
        return <Info className="h-4 w-4" />
      case 'alert-circle':
      default:
        return <AlertCircle className="h-4 w-4" />
    }
  }

  // Fallback for ApiError without envelope
  if (error) {
    if (error.isBackendUnavailable()) {
      return <Server className="h-4 w-4" />
    }
    if (error.isNotFound()) {
      return <FileQuestion className="h-4 w-4" />
    }
  }

  // Generic fallback
  return <AlertCircle className="h-4 w-4" />
}

/**
 * Get error title from envelope or error object.
 */
function getErrorTitle(
  error: unknown,
  envelope: ApiErrorEnvelope | null,
  context?: string
): string {
  if (envelope) {
    return getCategoryTitle(envelope)
  }

  if (error instanceof ApiError) {
    if (error.isBackendUnavailable()) {
      return 'Backend Not Available'
    }
    if (error.isNotFound()) {
      return 'Feature Not Available'
    }
    return 'API Error'
  }

  if (error instanceof TypeError && error.message.includes('fetch')) {
    return 'Connection Error'
  }

  return context ? `Failed to load ${context}` : 'Error'
}

/**
 * Get error message from envelope or error object.
 */
function getErrorMessage(error: unknown, envelope: ApiErrorEnvelope | null): string {
  if (envelope) {
    return envelope.message
  }

  if (error instanceof ApiError) {
    return error.getUserMessage()
  }

  if (error instanceof TypeError && error.message.includes('fetch')) {
    return 'Unable to connect to the server. The backend may not be running.'
  }

  if (error instanceof Error) {
    return error.message
  }

  return 'An unexpected error occurred'
}

export function AppErrorAlert({
  error,
  onRetry,
  context,
  showSetupHint = false,
  reportError = false,
}: AppErrorAlertProps) {
  const [showDetails, setShowDetails] = useState(false)

  // Report client error to backend if requested
  useEffect(() => {
    if (reportError && error) {
      reportClientError(error, context ? { context } : undefined)
    }
  }, [error, reportError, context])

  // Parse error envelope if available
  const apiError = error instanceof ApiError ? error : null
  const envelope = apiError?.envelope || null
  const normalizedEnvelope = envelope ? normalizeErrorEnvelope(envelope) : null

  // Get rendering hints
  const hints = normalizedEnvelope
    ? getErrorRenderingHints(normalizedEnvelope)
    : {
        variant: 'destructive' as const,
        showRetry: !!onRetry,
        retryable: !!onRetry,
        showNetworkGuidance: false,
        isSetupIssue: false,
      }

  // Extract info for display
  const title = getErrorTitle(error, normalizedEnvelope, context)
  const message = getErrorMessage(error, normalizedEnvelope)
  const actions = normalizedEnvelope ? getErrorActions(normalizedEnvelope) : []
  const technicalDetails = normalizedEnvelope?.technical_details || null
  const requestId = apiError?.requestId || null
  const icon = getErrorIcon(apiError, normalizedEnvelope)

  // Determine if we should show backend setup hint
  const shouldShowSetupHint =
    showSetupHint &&
    (apiError?.isBackendUnavailable() || hints.isSetupIssue || apiError?.isNotFound())

  // Determine if we should show network/VPN guidance
  const shouldShowNetworkGuidance =
    hints.showNetworkGuidance || (normalizedEnvelope && isNetworkPolicyError(normalizedEnvelope))

  return (
    <Alert variant={hints.variant} className="my-4">
      {icon}
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription className="mt-2 space-y-3">
        <p>{message}</p>

        {/* Action items */}
        {actions.length > 0 && (
          <div className="mt-3 space-y-2">
            <p className="font-medium text-sm">Recommended actions:</p>
            <ul className="list-disc list-inside space-y-1 text-sm">
              {actions.map((action, idx) => (
                <li key={idx}>{action}</li>
              ))}
            </ul>
          </div>
        )}

        {/* Network/VPN guidance */}
        {shouldShowNetworkGuidance && (
          <div className="mt-3 p-3 bg-muted/50 rounded-md text-sm">
            <p className="font-medium mb-2">
              <WifiOff className="inline h-4 w-4 mr-1" />
              Network Policy Issue
            </p>
            <p className="mb-2">
              Your IP address may not be allowed to access Snowflake. Common causes:
            </p>
            <ul className="list-disc list-inside space-y-1">
              <li>Not connected to corporate VPN</li>
              <li>IP address not in network policy allowlist</li>
              <li>Network policy configuration changed</li>
            </ul>
          </div>
        )}

        {/* Backend setup hint */}
        {shouldShowSetupHint && (
          <div className="mt-3 p-3 bg-muted/50 rounded-md text-sm">
            <p className="font-medium mb-1">To start the backend:</p>
            <code className="block bg-background px-2 py-1 rounded text-xs">
              make api-serve
            </code>
          </div>
        )}

        {/* Technical details (collapsible) */}
        {technicalDetails && (
          <div className="mt-3 border rounded-md">
            <button
              onClick={() => setShowDetails(!showDetails)}
              className="flex items-center justify-between w-full px-3 py-2 text-sm font-medium hover:bg-muted/50 transition-colors"
            >
              <span>Technical Details</span>
              {showDetails ? (
                <ChevronUp className="h-4 w-4" />
              ) : (
                <ChevronDown className="h-4 w-4" />
              )}
            </button>
            {showDetails && (
              <div className="px-3 py-2 border-t">
                <pre className="text-xs overflow-x-auto whitespace-pre-wrap">
                  {technicalDetails}
                </pre>
              </div>
            )}
          </div>
        )}

        {/* Request ID */}
        {requestId && (
          <p className="text-xs text-muted-foreground">
            Request ID: <code className="font-mono">{formatRequestId(requestId)}</code>
          </p>
        )}

        {/* Retry button */}
        {hints.showRetry && onRetry && (
          <Button variant="outline" size="sm" onClick={onRetry}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Try Again
          </Button>
        )}
      </AlertDescription>
    </Alert>
  )
}
