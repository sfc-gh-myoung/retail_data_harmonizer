import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import { tasksResponseSchema, type TasksData, type TaskState } from '../schemas'

export function usePipelineTasks(autoRefresh = false) {
  return useSuspenseQuery({
    queryKey: ['pipeline', 'tasks'],
    queryFn: () => fetchApi('/v2/pipeline/tasks', tasksResponseSchema),
    refetchInterval: autoRefresh ? 15000 : false, // 15s when enabled
  })
}

export type { TasksData, TaskState }
