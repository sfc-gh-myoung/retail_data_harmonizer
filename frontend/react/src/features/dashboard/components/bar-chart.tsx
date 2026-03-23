interface BarChartItem {
  label: string
  count: number
  color: string
  pct?: number
  displayAsPercent?: boolean
  suffix?: string
}

interface BarChartProps {
  items: BarChartItem[]
  maxValue?: number
  /** Use item.pct for display and width calculation instead of count-based percentage */
  scaleByPct?: boolean
  /** When true, max value fills 100% of bar (relative comparison). 
   *  When false with scaleByPct, percentage maps directly to bar width (61.7% = 61.7% bar).
   *  Defaults to true for count-based charts, false for percentage-based charts. */
  normalizeToMax?: boolean
}

export function BarChart({ items, maxValue, scaleByPct, normalizeToMax }: BarChartProps) {
  const max = maxValue ?? Math.max(...items.map(i => i.count), 1)
  
  // Determine if we should normalize to max value
  // Default: normalize for count-based charts, absolute for percentage-based charts
  const shouldNormalize = normalizeToMax ?? !scaleByPct
  
  // Calculate max percentage for normalization
  const maxPct = shouldNormalize
    ? Math.max(...items.map(i => i.pct ?? ((i.count / max) * 100)), 1)
    : 100

  return (
    <div className="space-y-2">
      {items.map((item) => {
        const displayPct = item.pct ?? ((item.count / max) * 100)
        const widthPct = shouldNormalize ? (displayPct / maxPct) * 100 : displayPct
        
        return (
          <div key={item.label} className="flex items-center gap-3">
            <span className="w-32 text-sm text-muted-foreground truncate">
              {item.label}
            </span>
            <div className="flex-1 h-5 bg-muted rounded overflow-hidden">
              <div
                className="h-full rounded transition-all duration-300"
                style={{ 
                  width: `${widthPct}%`, 
                  backgroundColor: item.color 
                }}
              />
            </div>
            <span className="w-28 text-sm text-right tabular-nums">
              {item.displayAsPercent ? (
                <>
                  {displayPct.toFixed(1)}%
                  {item.suffix && <span className="text-muted-foreground ml-1">{item.suffix}</span>}
                </>
              ) : (
                <>
                  {item.count.toLocaleString()} ({displayPct.toFixed(1)}%)
                </>
              )}
            </span>
          </div>
        )
      })}
    </div>
  )
}
