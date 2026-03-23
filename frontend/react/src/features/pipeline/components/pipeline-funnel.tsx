import { useState } from 'react'
import { ChevronDown, ChevronRight, Loader2, Pause, Info } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import type { FunnelData } from '../hooks'

interface PipelineFunnelProps {
  funnel: FunnelData
  batchId?: string | null
  pipelineState?: string | null
  activePhase?: string | null
  allTasksSuspended?: boolean
}

export function PipelineFunnel({
  funnel,
  batchId,
  pipelineState,
  activePhase,
  allTasksSuspended,
}: PipelineFunnelProps) {
  const [isOpen, setIsOpen] = useState(true)
  const isProcessing = pipelineState === 'PROCESSING'

  const catPct = funnel.rawItems > 0 ? (funnel.categorizedItems / funnel.rawItems) * 100 : 0
  const uniquePct = funnel.rawItems > 0 ? (funnel.uniqueDescriptions / funnel.rawItems) * 100 : 0
  const matchedPct = funnel.rawItems > 0 ? (funnel.ensembleDone / funnel.rawItems) * 100 : 0
  const dedupRatio =
    funnel.categorizedItems > 0
      ? ((1 - funnel.uniqueDescriptions / funnel.categorizedItems) * 100).toFixed(1)
      : '0'

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen}>
      <div className="h-full rounded-lg border bg-card text-card-foreground shadow-sm">
        <CollapsibleTrigger className="flex w-full items-center justify-between p-4 hover:bg-muted/50">
          <div className="flex items-center gap-2">
            {isOpen ? (
              <ChevronDown className="h-4 w-4" />
            ) : (
              <ChevronRight className="h-4 w-4" />
            )}
            <span className="font-semibold">Pipeline Phase Progress</span>
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger>
                  <Info className="h-4 w-4 text-muted-foreground" />
                </TooltipTrigger>
                <TooltipContent className="max-w-xs">
                  Live view of items flowing through the matching pipeline. Shows categorization,
                  fast-path (exact matches), and full pipeline processing. Phase bars indicate
                  completion per matching algorithm. Auto-refreshes during active processing.
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
            {isProcessing && allTasksSuspended && (
              <Pause className="h-4 w-4 text-yellow-500" />
            )}
            {isProcessing && !allTasksSuspended && (
              <Loader2 className="h-4 w-4 animate-spin text-primary" />
            )}
          </div>
          <span className="text-sm text-muted-foreground">
            (Batch: {batchId?.slice(0, 8) || 'N/A'})
          </span>
        </CollapsibleTrigger>

        <CollapsibleContent>
          <div className="px-4 pb-4 space-y-4">
            {funnel.rawItems > 0 ? (
              <>
                {/* Active/Paused Banner */}
                {isProcessing && activePhase && (
                  <div
                    className={cn(
                      'flex items-center gap-3 p-2 rounded-md',
                      allTasksSuspended
                        ? 'bg-yellow-500/10 text-yellow-700 dark:text-yellow-400'
                        : 'bg-blue-500/10 text-blue-700 dark:text-blue-400'
                    )}
                  >
                    {allTasksSuspended ? (
                      <Pause className="h-4 w-4" />
                    ) : (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    )}
                    <span>
                      <strong>{allTasksSuspended ? 'Paused:' : 'Active:'}</strong> {activePhase}
                      {allTasksSuspended && (
                        <span className="text-muted-foreground ml-2">
                          — Enable tasks to resume processing
                        </span>
                      )}
                    </span>
                  </div>
                )}

                {/* Pipeline Funnel */}
                <div className="p-3 rounded-md bg-muted/50 space-y-3">
                  <span className="text-xs font-semibold uppercase text-muted-foreground">
                    Pipeline Funnel
                  </span>
                  <div className="space-y-2">
                    {/* Raw Items */}
                    <FunnelRow label="Raw Items" value={funnel.rawItems} percent={100} color="bg-slate-400" />
                    
                    {/* Categorized */}
                    <FunnelRow
                      label="Categorized"
                      value={funnel.categorizedItems}
                      percent={catPct}
                      indent={1}
                      color="bg-emerald-500"
                      badge={
                        funnel.blockedItems > 0 ? (
                          <Badge variant="warning" className="text-xs">
                            {funnel.blockedItems.toLocaleString()} blocked
                          </Badge>
                        ) : undefined
                      }
                    />
                    
                    {/* Unique Descriptions */}
                    <FunnelRow
                      label="Unique Descriptions"
                      value={funnel.uniqueDescriptions}
                      percent={uniquePct}
                      indent={2}
                      color="bg-blue-500"
                      suffix={
                        <span className="text-xs text-muted-foreground">{dedupRatio}% dedup ratio</span>
                      }
                    />
                    
                    {/* Matched */}
                    <FunnelRow
                      label="Matched"
                      value={funnel.ensembleDone}
                      percent={matchedPct}
                      indent={3}
                      color="bg-cyan-500"
                      suffix={
                        <span className="text-xs text-muted-foreground">
                          {matchedPct.toFixed(1)}% complete
                        </span>
                      }
                    />
                  </div>
                </div>
              </>
            ) : (
              <p className="text-muted-foreground">
                No items in pipeline. Ingest data to see progress.
              </p>
            )}
          </div>
        </CollapsibleContent>
      </div>
    </Collapsible>
  )
}

interface FunnelRowProps {
  label: string
  value: number
  percent: number
  indent?: number
  color?: string
  icon?: string
  badge?: React.ReactNode
  suffix?: React.ReactNode
}

function FunnelRow({
  label,
  value,
  percent,
  indent = 0,
  color = 'bg-secondary',
  icon,
  badge,
  suffix,
}: FunnelRowProps) {
  const paddingLeft = indent * 12
  return (
    <div className="flex items-center gap-2">
      <div
        className="w-36 text-sm text-muted-foreground flex items-center gap-1"
        style={{ paddingLeft }}
      >
        {indent > 0 && <span className="text-xs">↳</span>}
        {icon && <span>{icon}</span>}
        {label}
      </div>
      <div className="flex-1 max-w-md lg:max-w-lg xl:max-w-xl">
        <div className="relative h-5 bg-muted rounded overflow-hidden">
          <div
            className={cn('h-full transition-all rounded', color)}
            style={{ width: `${Math.min(percent, 100)}%` }}
          />
          <span className="absolute inset-0 flex items-center justify-center text-xs font-medium text-gray-900 drop-shadow-[0_0_2px_rgba(255,255,255,0.8)]">
            {value.toLocaleString()}
          </span>
        </div>
      </div>
      {badge}
      {suffix}
    </div>
  )
}
