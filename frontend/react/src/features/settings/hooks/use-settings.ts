import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchApi, postApi } from '@/lib/api'
import {
  settingsSchema,
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

// Editable settings payload (cost is not user-editable from the Settings page).
export type SettingsUpdate = Pick<
  Settings,
  'weights' | 'thresholds' | 'performance' | 'automation'
>

export function useSaveSettings() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (update: SettingsUpdate) =>
      postApi('/v2/settings', update, settingsSchema),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['settings'] })
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
