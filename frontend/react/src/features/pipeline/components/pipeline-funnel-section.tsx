import { usePipelineFunnel, usePhaseProgress, usePipelineTasks } from '../hooks'
import { PipelineFunnel } from './pipeline-funnel'

/**
 * Self-contained funnel section that fetches its own data.
 * Uses usePipelineFunnel (10s refresh), usePhaseProgress, and usePipelineTasks for context.
 */
export function PipelineFunnelSection() {
  const { data: funnel } = usePipelineFunnel()
  const { data: phases } = usePhaseProgress()
  const { data: tasks } = usePipelineTasks()

  if (!funnel) return null

  return (
    <PipelineFunnel
      funnel={funnel}
      batchId={phases?.batchId}
      pipelineState={phases?.pipelineState}
      activePhase={phases?.activePhase}
      allTasksSuspended={tasks?.allTasksSuspended}
    />
  )
}
