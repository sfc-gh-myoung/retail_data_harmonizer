import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'

interface SectionSkeletonProps {
  /** Section title - always displayed even during loading */
  title: string
  /** Visual variant - 'card' wraps in Card component, 'plain' renders without container */
  variant?: 'card' | 'plain'
  /** Number of skeleton lines to render in the content area */
  lines?: number
  /** Custom content to render instead of default skeleton lines */
  children?: React.ReactNode
}

/**
 * Shared skeleton component for section loading states.
 * 
 * Key design: Section title is ALWAYS visible (not a skeleton placeholder).
 * This provides visual stability during loading and helps users understand
 * what content is being loaded.
 * 
 * @example
 * // Basic usage with default lines
 * <SectionSkeleton title="Task History" lines={5} />
 * 
 * @example
 * // Custom skeleton content
 * <SectionSkeleton title="KPI Metrics" variant="plain">
 *   <div className="grid grid-cols-3 gap-4">
 *     <Skeleton className="h-24" />
 *     <Skeleton className="h-24" />
 *     <Skeleton className="h-24" />
 *   </div>
 * </SectionSkeleton>
 */
export function SectionSkeleton({
  title,
  variant = 'card',
  lines = 4,
  children,
}: SectionSkeletonProps) {
  const content = children ?? (
    <div className="space-y-2">
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton key={i} className="h-4 w-full" />
      ))}
    </div>
  )

  if (variant === 'plain') {
    return (
      <div className="space-y-3">
        <h3 className="text-base font-semibold">{title}</h3>
        {content}
      </div>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent>{content}</CardContent>
    </Card>
  )
}

// ============================================================================
// Specialized skeleton variants for common patterns
// ============================================================================

interface TableSkeletonProps {
  title: string
  rows?: number
  columns?: number
}

/**
 * Skeleton for table sections with configurable rows and columns
 */
export function TableSkeleton({ title, rows = 5, columns = 4 }: TableSkeletonProps) {
  return (
    <SectionSkeleton title={title}>
      <div className="space-y-2">
        {/* Header row */}
        <div className="flex gap-4 pb-2 border-b">
          {Array.from({ length: columns }).map((_, i) => (
            <Skeleton key={i} className="h-4 flex-1" />
          ))}
        </div>
        {/* Data rows */}
        {Array.from({ length: rows }).map((_, rowIndex) => (
          <div key={rowIndex} className="flex gap-4 py-1">
            {Array.from({ length: columns }).map((_, colIndex) => (
              <Skeleton key={colIndex} className="h-4 flex-1" />
            ))}
          </div>
        ))}
      </div>
    </SectionSkeleton>
  )
}

interface MetricsSkeletonProps {
  title: string
  count?: number
}

/**
 * Skeleton for metric/stat card grids
 */
export function MetricsSkeleton({ title, count = 4 }: MetricsSkeletonProps) {
  return (
    <SectionSkeleton title={title}>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {Array.from({ length: count }).map((_, i) => (
          <div key={i} className="p-4 rounded-lg border bg-muted/50">
            <Skeleton className="h-3 w-16 mb-1" />
            <Skeleton className="h-8 w-12 mb-1" />
            <Skeleton className="h-3 w-20" />
          </div>
        ))}
      </div>
    </SectionSkeleton>
  )
}

interface ChartSkeletonProps {
  title: string
  height?: string
}

/**
 * Skeleton for chart sections
 */
export function ChartSkeleton({ title, height = 'h-48' }: ChartSkeletonProps) {
  return (
    <SectionSkeleton title={title}>
      <Skeleton className={`${height} w-full rounded-lg`} />
    </SectionSkeleton>
  )
}

interface ProgressSkeletonProps {
  title: string
  bars?: number
}

/**
 * Skeleton for progress bar sections
 */
export function ProgressSkeleton({ title, bars = 6 }: ProgressSkeletonProps) {
  return (
    <SectionSkeleton title={title}>
      <div className="space-y-3">
        {Array.from({ length: bars }).map((_, i) => (
          <div key={i} className="flex items-center gap-3">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-6 flex-1 rounded" />
            <Skeleton className="h-4 w-12" />
          </div>
        ))}
      </div>
    </SectionSkeleton>
  )
}
