import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchApi, patchApi, postApi } from '@/lib/api'
import {
  settingsSchema,
  voidResponseSchema,
  type Settings,
} from '@/lib/schemas'
import { z } from 'zod'

// Re-export type from schemas
export type { Settings }

const resetPipelineResponseSchema = z.object({
  success: z.boolean(),
  message: z.string(),
})

export function useSettings() {
  return useQuery({
    queryKey: ['settings'],
    queryFn: () => fetchApi('/v2/settings', settingsSchema),
  })
}

export function useUpdateSettings() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (settings: Partial<Settings>) =>
      patchApi('/v2/settings', settings, settingsSchema),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['settings'] })
    },
  })
}

export function useResetSettings() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => postApi('/settings/reset', {}, voidResponseSchema),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['settings'] })
    },
  })
}

export function useReEvaluate() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => postApi('/v2/settings/re-evaluate', {}, voidResponseSchema),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['matches'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

export function useResetPipeline() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => postApi('/v2/pipeline/reset', {}, resetPipelineResponseSchema),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['matches'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
      queryClient.invalidateQueries({ queryKey: ['pipeline'] })
    },
  })
}
