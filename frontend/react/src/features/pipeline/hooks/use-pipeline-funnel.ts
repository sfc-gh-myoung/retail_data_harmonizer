import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { funnelSchema, type FunnelData } from '../schemas'

export function usePipelineFunnel(autoRefresh = false) {
  return useSuspenseQuery({
    queryKey: ['pipeline', 'funnel'],
    queryFn: () => fetchApi('/v2/pipeline/funnel', funnelSchema),
    refetchInterval: autoRefresh ? 15000 : false, // 15s when enabled
  })
}

export type { FunnelData }
