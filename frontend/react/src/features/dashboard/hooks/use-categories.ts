import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { categoriesResponseSchema, type CategoriesData } from '../schemas'

export function useCategories() {
  return useSuspenseQuery({
    queryKey: ['dashboard', 'categories'],
    queryFn: () => fetchApi('/v2/dashboard/categories', categoriesResponseSchema),
    refetchInterval: 30000, // 30s
  })
}

export type { CategoriesData }
