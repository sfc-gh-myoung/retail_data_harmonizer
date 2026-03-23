import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { kpisResponseSchema, type KpisData } from '../schemas'

export function useKpis() {
  return useSuspenseQuery({
    queryKey: ['dashboard', 'kpis'],
    queryFn: () => fetchApi('/v2/dashboard/kpis', kpisResponseSchema),
    refetchInterval: 10000, // 10s
  })
}

export type { KpisData }
