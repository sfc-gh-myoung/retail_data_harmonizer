import { cn } from '@/lib/utils'

interface ConfidenceBadgeProps {
  score: number
  format?: 'decimal' | 'percent'
  size?: 'sm' | 'md'
  showLabel?: boolean
  label?: string
}

/**
 * Color-coded confidence score badge.
 * - Green (high): > 0.80
 * - Yellow (medium): >= 0.70
 * - Orange (low-medium): >= 0.60
 * - Red (low): < 0.60
 */
export function ConfidenceBadge({
  score,
  format = 'decimal',
  size = 'sm',
  showLabel = false,
  label,
}: ConfidenceBadgeProps) {
  const getColorClass = (value: number) => {
    if (value > 0.80) return 'bg-green-500/15 text-green-700 dark:text-green-400 border-green-500/30'
    if (value >= 0.70) return 'bg-yellow-500/15 text-yellow-700 dark:text-yellow-400 border-yellow-500/30'
    if (value >= 0.60) return 'bg-orange-500/15 text-orange-700 dark:text-orange-400 border-orange-500/30'
    return 'bg-red-500/15 text-red-700 dark:text-red-400 border-red-500/30'
  }

  const displayValue = format === 'percent'
    ? `${(score * 100).toFixed(0)}%`
    : score.toFixed(3)

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded border font-mono',
        getColorClass(score),
        size === 'sm' ? 'px-1.5 py-0.5 text-xs' : 'px-2 py-1 text-sm'
      )}
    >
      {showLabel && label && (
        <span className="font-sans font-medium opacity-70">{label}</span>
      )}
      {displayValue}
    </span>
  )
}

interface ScoreBadgeRowProps {
  scores: {
    search?: number
    cosine?: number
    edit?: number
    jaccard?: number
  }
  showZeros?: boolean
}

/**
 * Horizontal row of score badges for each matching method.
 */
export function ScoreBadgeRow({ scores, showZeros = false }: ScoreBadgeRowProps) {
  const entries = [
    { key: 'search', label: 'Search', value: scores.search ?? 0 },
    { key: 'cosine', label: 'Cosine', value: scores.cosine ?? 0 },
    { key: 'edit', label: 'Edit', value: scores.edit ?? 0 },
    { key: 'jaccard', label: 'Jaccard', value: scores.jaccard ?? 0 },
  ].filter(e => showZeros || e.value > 0)

  if (entries.length === 0) return null

  return (
    <div className="flex flex-wrap gap-2">
      {entries.map(({ key, label, value }) => (
        <div key={key} className="flex items-center gap-1">
          <span className="text-xs text-muted-foreground">{label}:</span>
          <ConfidenceBadge score={value} />
        </div>
      ))}
    </div>
  )
}
