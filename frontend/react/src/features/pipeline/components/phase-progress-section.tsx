import { usePhaseProgress, usePipelineFunnel, usePipelineTasks } from '../hooks'
import { PhaseProgressList } from './phase-progress'
import { Card, CardContent } from '@/components/ui/card'

/**
 * Self-contained phase progress section that fetches its own data.
 * Uses usePhaseProgress (5s refresh) for phase data.
 */
export function PhaseProgressSection() {
  const { data: phases } = usePhaseProgress()
  const { data: funnel } = usePipelineFunnel()
  const { data: tasks } = usePipelineTasks()

  if (!phases || phases.phases.length === 0 || !funnel) return null

  return (
    <Card className="h-full">
      <CardContent className="pt-6">
        <PhaseProgressList
          phases={phases.phases}
          pipelineItems={funnel.pipelineItems}
          ensembleWaitingFor={phases.ensembleWaitingFor}
          allTasksSuspended={tasks?.allTasksSuspended}
        />
      </CardContent>
    </Card>
  )
}
