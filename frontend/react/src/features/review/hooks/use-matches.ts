import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fetchApi, postApi, postFormApi } from '@/lib/api'
import {
  matchesResponseSchema,
  filterOptionsSchema,
  alternativesResponseSchema,
  updateMatchResponseSchema,
  voidResponseSchema,
  type Match,
  type MatchesResponse,
  type FilterOptions,
  type Alternative,
  type UpdateMatchResponse,
} from '@/lib/schemas'

// Re-export types from schemas
export type { Match, MatchesResponse, FilterOptions, Alternative, UpdateMatchResponse }

export interface MatchFilters {
  status?: string
  source?: string
  category?: string
  subcategory?: string
  matchSource?: string
  agreement?: string
  groupBy?: string
  page?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
}

export function useMatches(filters: MatchFilters) {
  return useQuery({
    queryKey: ['matches', filters],
    queryFn: () => postApi('/v2/matches/search', filters, matchesResponseSchema),
  })
}

export function useFilterOptions() {
  return useQuery({
    queryKey: ['matches', 'filter-options'],
    queryFn: () => fetchApi('/v2/matches/filter-options', filterOptionsSchema),
    staleTime: 5 * 60 * 1000, // Cache for 5 minutes
  })
}

export function useAlternatives(itemId: string | null) {
  return useQuery({
    queryKey: ['alternatives', itemId],
    queryFn: () => fetchApi(`/v2/matches/${itemId}/alternatives`, alternativesResponseSchema),
    enabled: !!itemId,
  })
}

export function useBulkAction() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ action, ids }: { action: 'accept' | 'reject'; ids: string[] }) =>
      postApi('/v2/matches/bulk', { action, ids }, voidResponseSchema),
    onSuccess: (_, { action, ids }) => {
      queryClient.invalidateQueries({ queryKey: ['matches'] })
      const actionLabel = action === 'accept' ? 'confirmed' : 'rejected'
      toast.success(`${ids.length} match${ids.length > 1 ? 'es' : ''} ${actionLabel}`)
    },
    onError: (error) => {
      toast.error(`Failed to update matches: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
  })
}

export interface UpdateMatchParams {
  id: string
  status: string
  rawName?: string
  updateRelated?: boolean
}

// Normalize description the same way as backend: UPPER(TRIM(REGEXP_REPLACE(description, '\s+', ' ')))
function normalizeDescription(desc: string): string {
  return desc.toUpperCase().trim().replace(/\s+/g, ' ')
}

export function useUpdateMatch() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, status, updateRelated }: UpdateMatchParams) =>
      postApi(`/v2/matches/${id}/status`, { status, updateRelated }, updateMatchResponseSchema),
    onMutate: async ({ id, rawName, updateRelated }) => {
      // Cancel outgoing refetches to prevent them from overwriting our optimistic update
      await queryClient.cancelQueries({ queryKey: ['matches'] })

      // Snapshot previous data for rollback
      const previousData = queryClient.getQueriesData<MatchesResponse>({ queryKey: ['matches'] })

      // Optimistically remove items from all cached match lists
      queryClient.setQueriesData<MatchesResponse>({ queryKey: ['matches'] }, (old) => {
        if (!old?.items) return old
        
        let filteredItems: Match[]
        let removedCount: number
        
        if (updateRelated && rawName) {
          // When updating related items, filter by normalized description
          const normalizedDesc = normalizeDescription(rawName)
          filteredItems = old.items.filter(
            (item) => normalizeDescription(item.rawName) !== normalizedDesc
          )
          removedCount = old.items.length - filteredItems.length
        } else {
          // Single item update
          filteredItems = old.items.filter((item) => item.id !== id)
          removedCount = 1
        }
        
        return {
          ...old,
          items: filteredItems,
          total: Math.max(0, old.total - removedCount),
        }
      })

      return { previousData }
    },
    onError: (error, _variables, context) => {
      // Rollback on error
      context?.previousData?.forEach(([queryKey, data]) => {
        queryClient.setQueryData(queryKey, data)
      })
      toast.error(`Failed to update match: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
    onSuccess: (response, { status }) => {
      const statusLabel = status === 'CONFIRMED' ? 'confirmed' : status === 'REJECTED' ? 'rejected' : status.toLowerCase()
      const count = response?.updatedCount ?? 1
      const variants = response?.variantCount ?? 1
      if (count > 1) {
        const variantText = variants > 1 ? ` (${variants} variants)` : ''
        toast.success(`${count} matches ${statusLabel}${variantText}`)
      } else {
        toast.success(`Match ${statusLabel}`)
      }
    },
    onSettled: () => {
      // Mark queries as stale without immediate refetch to prevent
      // race condition where item reappears before DB commit completes
      queryClient.invalidateQueries({ queryKey: ['matches'], refetchType: 'none' })
    },
  })
}

export function useSkipMatch() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ itemId, matchId }: { itemId: string; matchId: string }) =>
      postFormApi('/ui/review/action', new URLSearchParams({
        item_id: itemId,
        match_id: matchId,
        action: 'SKIP',
      }).toString()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['matches'], refetchType: 'none' })
      toast.success('Match skipped')
    },
    onError: (error) => {
      toast.error(`Failed to skip match: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
  })
}

export function useFeedback() {
  return useMutation({
    mutationFn: ({ matchId, itemId, feedback }: { matchId: string; itemId: string; feedback: 'up' | 'down' }) =>
      postFormApi('/ui/review/feedback', new URLSearchParams({
        match_id: matchId,
        item_id: itemId,
        feedback,
      }).toString()),
  })
}

export function useSelectAlternative() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ itemId, matchId, standardId }: { itemId: string; matchId: string; standardId: string }) =>
      postFormApi('/ui/review/select-alternative', new URLSearchParams({
        item_id: itemId,
        match_id: matchId,
        standard_id: standardId,
      }).toString()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['matches'], refetchType: 'none' })
      toast.success('Alternative selected')
    },
    onError: (error) => {
      toast.error(`Failed to select alternative: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
  })
}
