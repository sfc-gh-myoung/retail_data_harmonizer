import { RefreshCw } from 'lucide-react'
import { useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { Label } from '@/components/ui/label'
import { useLocalStorage } from '@/hooks/use-local-storage'

interface PageHeaderProps {
  /** Page title */
  title: string
  /** Optional subtitle/description */
  subtitle?: string
  /** Storage key for persisting auto-refresh state (e.g., 'dashboard-auto-refresh') */
  storageKey: string
  /** Whether data is currently being fetched */
  isFetching: boolean
  /** Callback to trigger data refresh */
  onRefresh: () => void
  /** Set to false to hide auto-refresh toggle (e.g., for Settings page) */
  showAutoRefresh?: boolean
  /** Auto-refresh interval in milliseconds (default: 30000) */
  refreshInterval?: number
  /** Additional actions to render in the header */
  children?: React.ReactNode
}

/**
 * Consistent page header with auto-refresh toggle and manual refresh button.
 * Auto-refresh state is persisted to localStorage per page.
 */
export function PageHeader({
  title,
  subtitle,
  storageKey,
  isFetching,
  onRefresh,
  showAutoRefresh = true,
  refreshInterval = 30000,
  children,
}: PageHeaderProps) {
  const [autoRefresh, setAutoRefresh] = useLocalStorage(storageKey, false)

  // Auto-refresh effect
  useEffect(() => {
    if (!autoRefresh) return
    const interval = setInterval(() => onRefresh(), refreshInterval)
    return () => clearInterval(interval)
  }, [autoRefresh, onRefresh, refreshInterval])

  return (
    <div className="flex items-center justify-between">
      <div>
        <h2 className="text-xl font-semibold">{title}</h2>
        {subtitle && (
          <p className="text-sm text-muted-foreground mt-0.5">{subtitle}</p>
        )}
      </div>
      <div className="flex items-center gap-3">
        {children}
        {showAutoRefresh && (
          <div className="flex items-center gap-2">
            <Switch
              id={`${storageKey}-toggle`}
              checked={autoRefresh}
              onCheckedChange={setAutoRefresh}
            />
            <Label htmlFor={`${storageKey}-toggle`} className="text-sm">
              Auto-refresh
            </Label>
          </div>
        )}
        <Button
          variant="outline"
          size="sm"
          onClick={onRefresh}
          disabled={isFetching}
        >
          <RefreshCw className={`h-4 w-4 mr-1 ${isFetching ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>
    </div>
  )
}
