import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { phasesResponseSchema, type PhasesData, type PhaseProgress, type PhaseState } from '../schemas'

export function usePhaseProgress(autoRefresh = false) {
  return useSuspenseQuery({
    queryKey: ['pipeline', 'phases'],
    queryFn: () => fetchApi('/v2/pipeline/phases', phasesResponseSchema),
    refetchInterval: autoRefresh ? 15000 : false, // 15s when enabled
  })
}

export type { PhasesData, PhaseProgress, PhaseState }
