import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { sourcesResponseSchema, type SourcesData } from '../schemas'

export function useSources() {
  return useSuspenseQuery({
    queryKey: ['dashboard', 'sources'],
    queryFn: () => fetchApi('/v2/dashboard/sources', sourcesResponseSchema),
    refetchInterval: 30000, // 30s
  })
}

export type { SourcesData }
