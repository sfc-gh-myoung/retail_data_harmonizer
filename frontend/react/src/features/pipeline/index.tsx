import { useCallback } from 'react'
import { AlertTriangle, Play } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { PageHeader } from '@/components/page-header'
import { SectionWrapper } from '@/components/section-wrapper'
import { useLocalStorage } from '@/hooks/use-local-storage'
import { usePipelineFunnel, usePipelineTasks, usePhaseProgress } from './hooks'
import { usePipelineActions } from './hooks/use-pipeline-actions'
import {
  FunnelSkeleton,
  PhasesSkeleton,
  TasksSkeleton,
} from './components/skeletons'
import { PipelineFunnelSection } from './components/pipeline-funnel-section'
import { PhaseProgressSection } from './components/phase-progress-section'
import { ScheduledTasksSection } from './components/scheduled-tasks-section'
import { ItemsBlockedWarning } from './components/items-blocked-warning'

/**
 * Pipeline Management page with modular architecture.
 *
 * Each section fetches its own data with independent refresh intervals
 * (only active when auto-refresh toggle is enabled):
 * - Funnel: 15s
 * - Phases: 15s
 * - Tasks: 15s
 *
 * Sections are wrapped in SectionWrapper for error isolation -
 * if one section fails, others continue working.
 *
 * Note: Task Execution History is available on the Logs page.
 */
export function Pipeline() {
  const [autoRefresh] = useLocalStorage('pipeline-auto-refresh', false)

  const funnelQuery = usePipelineFunnel(autoRefresh)
  const tasksQuery = usePipelineTasks(autoRefresh)
  const phasesQuery = usePhaseProgress(autoRefresh)
  const { enableAllTasks } = usePipelineActions()

  const isFetching = funnelQuery.isFetching || tasksQuery.isFetching || 
    phasesQuery.isFetching

  const refetchAll = useCallback(() => {
    funnelQuery.refetch()
    tasksQuery.refetch()
    phasesQuery.refetch()
  }, [funnelQuery, tasksQuery, phasesQuery])

  return (
    <div className="space-y-6">
      {/* Header with auto-refresh toggle and refresh button */}
      <PageHeader
        title="Pipeline Management"
        storageKey="pipeline-auto-refresh"
        isFetching={isFetching}
        onRefresh={refetchAll}
      />

      {/* Pipeline Paused Warning */}
      {tasksQuery.data?.allTasksSuspended && (
        <Alert className="border-yellow-500 bg-yellow-50 dark:bg-yellow-950">
          <AlertTriangle className="h-4 w-4 text-yellow-600" />
          <AlertDescription className="flex items-center gap-2">
            <span>
              <strong>Pipeline Paused</strong> — Stream pipeline tasks are suspended.
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => enableAllTasks.mutate()}
              disabled={enableAllTasks.isPending}
            >
              <Play className="h-4 w-4 mr-1" />
              Enable Tasks
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Pipeline Funnel + Phase Progress (side-by-side on lg+) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <SectionWrapper sectionName="Pipeline Funnel" fallback={<FunnelSkeleton />}>
          <PipelineFunnelSection />
        </SectionWrapper>
        <SectionWrapper sectionName="Phase Progress" fallback={<PhasesSkeleton />}>
          <PhaseProgressSection />
        </SectionWrapper>
      </div>

      {/* Items Blocked Warning */}
      {funnelQuery.data && funnelQuery.data.blockedItems > 0 && <ItemsBlockedWarning blockedCount={funnelQuery.data.blockedItems} />}

      {/* Scheduled Tasks */}
      <SectionWrapper sectionName="Scheduled Tasks" fallback={<TasksSkeleton />}>
        <ScheduledTasksSection />
      </SectionWrapper>
    </div>
  )
}
