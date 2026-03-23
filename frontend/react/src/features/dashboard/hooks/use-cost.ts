import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { costResponseSchema, type CostData } from '../schemas'

export function useCost() {
  return useSuspenseQuery({
    queryKey: ['dashboard', 'cost'],
    queryFn: () => fetchApi('/v2/dashboard/cost', costResponseSchema),
    refetchInterval: 60000, // 60s
  })
}

export type { CostData }
