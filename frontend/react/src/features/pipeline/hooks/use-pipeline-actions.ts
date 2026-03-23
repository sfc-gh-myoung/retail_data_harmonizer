import { useMutation, useQueryClient } from '@tanstack/react-query'
import { postApi } from '@/lib/api'
import { actionResponseSchema } from '../schemas'

/**
 * Provides mutation hooks for pipeline actions with automatic query invalidation.
 * All actions invalidate the 'pipeline' query key to refresh data.
 */
export function usePipelineActions() {
  const queryClient = useQueryClient()

  const invalidateAll = () => {
    queryClient.invalidateQueries({ queryKey: ['pipeline'] })
  }

  const runPipeline = useMutation({
    mutationFn: () => postApi('/v2/pipeline/run', {}, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  const stopPipeline = useMutation({
    mutationFn: (jobId: string) =>
      postApi('/v2/pipeline/stop', { job_id: jobId }, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  const toggleTask = useMutation({
    mutationFn: ({ taskName, action }: { taskName: string; action: 'resume' | 'suspend' }) =>
      postApi('/v2/pipeline/toggle', { task_name: taskName, action }, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  const enableAllTasks = useMutation({
    mutationFn: () => postApi('/v2/pipeline/tasks/enable-all', {}, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  const disableAllTasks = useMutation({
    mutationFn: () => postApi('/v2/pipeline/tasks/disable-all', {}, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  const resetPipeline = useMutation({
    mutationFn: () => postApi('/v2/pipeline/reset', {}, actionResponseSchema),
    onSuccess: invalidateAll,
  })

  return {
    runPipeline,
    stopPipeline,
    toggleTask,
    enableAllTasks,
    disableAllTasks,
    resetPipeline,
  }
}
