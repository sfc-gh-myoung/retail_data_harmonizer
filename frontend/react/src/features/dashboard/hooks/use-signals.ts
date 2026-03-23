import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { signalsResponseSchema, type SignalsData } from '../schemas'

export function useSignals() {
  return useSuspenseQuery({
    queryKey: ['dashboard', 'signals'],
    queryFn: () => fetchApi('/v2/dashboard/signals', signalsResponseSchema),
    refetchInterval: 30000, // 30s
  })
}

export type { SignalsData }
