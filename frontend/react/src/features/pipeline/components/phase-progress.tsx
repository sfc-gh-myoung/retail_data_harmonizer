import { CheckCircle2, Clock, Loader2, Pause, SkipForward, Info, AlertCircle } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

// Accept either the legacy PhaseState or the new one with ERROR
type PhaseState = 'WAITING' | 'PROCESSING' | 'COMPLETE' | 'SKIPPED' | 'ERROR'

interface PhaseProgress {
  name: string
  done: number
  total: number
  pct: number
  state: PhaseState
  color: string
}

interface PhaseProgressListProps {
  phases: PhaseProgress[]
  pipelineItems: number
  ensembleWaitingFor?: string | null
  allTasksSuspended?: boolean
}

export function PhaseProgressList({
  phases,
  pipelineItems,
  ensembleWaitingFor,
  allTasksSuspended,
}: PhaseProgressListProps) {
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <span className="font-semibold">Phase Progress</span>
        <span className="text-sm text-muted-foreground">
          {pipelineItems.toLocaleString()} items through matchers
        </span>
      </div>

      <div className="space-y-2">
        {phases.map((phase) => (
          <PhaseRow
            key={phase.name}
            phase={phase}
            allTasksSuspended={allTasksSuspended}
          />
        ))}
      </div>

      {/* Ensemble dependency note */}
      {ensembleWaitingFor && (
        <div className="flex items-center gap-2 pl-4 text-sm text-muted-foreground">
          <Info className="h-4 w-4" />
          <span>Ensemble will start automatically when {ensembleWaitingFor}</span>
        </div>
      )}
    </div>
  )
}

interface PhaseRowProps {
  phase: PhaseProgress
  allTasksSuspended?: boolean
}

function PhaseRow({ phase, allTasksSuspended }: PhaseRowProps) {
  const stateIcon = getStateIcon(phase.state, allTasksSuspended)
  const stateBadge = getStateBadge(phase.state, allTasksSuspended)
  const isAnimated = phase.state === 'PROCESSING' && !allTasksSuspended

  return (
    <div className="flex items-center gap-3">
      {/* Phase name with icon */}
      <div className="w-32 flex items-center gap-2 flex-shrink-0">
        {stateIcon}
        <span className="text-sm">{phase.name}</span>
      </div>

      {/* Progress bar */}
      <div className="flex-1 max-w-[60%] lg:max-w-[70%]">
        <div className="relative h-5 bg-muted rounded overflow-hidden">
          <div
            className={cn(
              'h-full transition-all',
              isAnimated && 'animate-pulse'
            )}
            style={{
              width: `${Math.min(phase.pct, 100)}%`,
              backgroundColor: phase.color,
            }}
          >
            {/* Animated stripes for processing state */}
            {isAnimated && (
              <div
                className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent animate-shimmer"
                style={{ backgroundSize: '200% 100%' }}
              />
            )}
          </div>
          <span className="absolute inset-0 flex items-center justify-center text-xs font-medium text-gray-900 drop-shadow-[0_0_2px_rgba(255,255,255,0.8)]">
            {Math.round(phase.pct)}%
          </span>
        </div>
      </div>

      {/* State badge and counts */}
      <div className="flex items-center gap-2 min-w-44 flex-shrink-0">
        {stateBadge}
        <span className="text-sm text-muted-foreground">
          {phase.done.toLocaleString()}/{phase.total.toLocaleString()}
        </span>
      </div>
    </div>
  )
}

function getStateIcon(state: PhaseState, suspended?: boolean) {
  if (state === 'COMPLETE') {
    return <CheckCircle2 className="h-4 w-4 text-green-500" />
  }
  if (state === 'ERROR') {
    return <AlertCircle className="h-4 w-4 text-destructive" />
  }
  if (state === 'PROCESSING' && suspended) {
    return <Pause className="h-4 w-4 text-yellow-500" />
  }
  if (state === 'PROCESSING') {
    return <Loader2 className="h-4 w-4 text-primary animate-spin" />
  }
  if (state === 'SKIPPED') {
    return <SkipForward className="h-4 w-4 text-muted-foreground" />
  }
  return <Clock className="h-4 w-4 text-muted-foreground" />
}

function getStateBadge(state: PhaseState, suspended?: boolean) {
  if (state === 'COMPLETE') {
    return <Badge variant="success">Complete</Badge>
  }
  if (state === 'ERROR') {
    return <Badge variant="destructive">Error</Badge>
  }
  if (state === 'PROCESSING' && suspended) {
    return <Badge variant="warning">Paused</Badge>
  }
  if (state === 'PROCESSING') {
    return <Badge variant="default">Processing</Badge>
  }
  if (state === 'SKIPPED') {
    return <Badge variant="secondary">Skipped</Badge>
  }
  return <Badge variant="secondary">Waiting</Badge>
}
