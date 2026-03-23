import type { SourceSystems, StatusColorsMap } from '../types'

interface SourceStatusChartProps {
  sourceSystems: SourceSystems
  sourceMax: number
  statusColorsMap: StatusColorsMap
}

const STATUS_ORDER = ['AUTO_ACCEPTED', 'CONFIRMED', 'PENDING_REVIEW', 'PENDING', 'REJECTED']

export function SourceStatusChart({ 
  sourceSystems, 
  sourceMax, 
  statusColorsMap 
}: SourceStatusChartProps) {
  const sources = Object.entries(sourceSystems)

  return (
    <div className="space-y-4">
      {sources.map(([source, statuses]) => {
        const srcTotal = Object.values(statuses).reduce((a, b) => a + b, 0)
        
        return (
          <div key={source} className="space-y-1">
            <div className="text-sm font-medium">
              {source}{' '}
              <span className="text-muted-foreground font-normal">
                ({srcTotal.toLocaleString()})
              </span>
            </div>
            <div 
              className="h-6 rounded overflow-hidden flex"
              style={{ backgroundColor: 'var(--muted)' }}
            >
              {STATUS_ORDER.map((statusName) => {
                const count = statuses[statusName] || 0
                if (count === 0) return null
                const widthPct = (count / sourceMax) * 100
                return (
                  <div
                    key={statusName}
                    className="h-full"
                    style={{
                      width: `${widthPct}%`,
                      backgroundColor: statusColorsMap[statusName] || '#9E9E9E',
                      minWidth: count > 0 ? '2px' : 0,
                    }}
                    title={`${statusName.replace('_', ' ')}: ${count.toLocaleString()}`}
                  />
                )
              })}
            </div>
          </div>
        )
      })}
      
      {/* Legend */}
      <div className="flex flex-wrap gap-3 pt-2">
        {STATUS_ORDER.map((statusName) => (
          <span 
            key={statusName}
            className="text-xs text-muted-foreground inline-flex items-center gap-1"
          >
            <span 
              className="inline-block w-3 h-3 rounded-sm"
              style={{ backgroundColor: statusColorsMap[statusName] || '#9E9E9E' }}
            />
            {statusName.replace(/_/g, ' ').toLowerCase().replace(/\b\w/g, c => c.toUpperCase())}
          </span>
        ))}
      </div>
    </div>
  )
}
