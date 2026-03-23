import { useState, useMemo } from 'react'
import {
  Play,
  Pause,
  Loader2,
  ChevronRight,
  ArrowRight,
  Inbox,
  CheckCircle2,
} from 'lucide-react'
import type { ColumnDef } from '@tanstack/react-table'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible'
import { DataTable } from '@/components/data-table'
import { cn } from '@/lib/utils'
import { usePipelineTasks, type TaskState } from '../hooks'
import { usePipelineActions } from '../hooks/use-pipeline-actions'

const roleBadgeVariants: Record<string, string> = {
  root: 'bg-blue-500 text-white',
  child: 'bg-cyan-500 text-white',
  sibling: 'bg-gray-500 text-white',
  parallel: 'bg-gray-500 text-white',
  finalizer: 'bg-green-500 text-white',
}

const roleLabels: Record<string, string> = {
  root: 'Root',
  child: 'Child',
  sibling: 'Parallel',
  parallel: 'Parallel',
  finalizer: 'Finalizer',
}

function useTaskColumns(
  onToggle: (taskName: string, action: 'resume' | 'suspend') => void,
  isToggling: boolean
) {
  return useMemo<ColumnDef<TaskState>[]>(
    () => [
      {
        accessorKey: 'name',
        header: 'Task',
        cell: ({ row }) => {
          const task = row.original
          const roleIcon =
            task.role === 'root' ? (
              <Inbox className="h-2.5 w-2.5 shrink-0" />
            ) : task.role === 'finalizer' ? (
              <CheckCircle2 className="h-2.5 w-2.5 shrink-0" />
            ) : (
              <ArrowRight className="h-2.5 w-2.5 shrink-0" />
            )
          return (
            <span
              style={{ marginLeft: `${task.level * 0.75}rem` }}
              className="flex items-center gap-1"
            >
              {roleIcon}
              <code className="text-[11px] truncate">{task.name}</code>
            </span>
          )
        },
      },
      {
        accessorKey: 'role',
        header: 'Role',
        cell: ({ row }) => {
          const role = row.original.role
          return (
            <Badge className={cn('text-[10px] px-1.5 py-0', roleBadgeVariants[role] || 'bg-gray-500')}>
              {roleLabels[role] || role}
            </Badge>
          )
        },
      },
      {
        accessorKey: 'state',
        header: 'Status',
        cell: ({ row }) => {
          const isRunning = row.original.state === 'started'
          return (
            <Badge variant={isRunning ? 'success' : 'secondary'} className="text-[10px] px-1.5 py-0">
              {isRunning ? (
                <>
                  <Play className="h-2.5 w-2.5 mr-0.5" /> RUNNING
                </>
              ) : (
                <>
                  <Pause className="h-2.5 w-2.5 mr-0.5" /> SUSPENDED
                </>
              )}
            </Badge>
          )
        },
      },
      {
        accessorKey: 'schedule',
        header: 'Schedule',
        cell: ({ getValue }) => (
          <span className="text-[11px] text-muted-foreground">{getValue<string>() || '--'}</span>
        ),
      },
      {
        id: 'actions',
        header: () => <span className="text-right block">Actions</span>,
        cell: ({ row }) => {
          const task = row.original
          const isRunning = task.state === 'started'
          return (
            <div className="text-right">
              <Button
                variant={isRunning ? 'outline' : 'default'}
                size="sm"
                className="h-6 px-2 text-[11px]"
                onClick={() => onToggle(task.name, isRunning ? 'suspend' : 'resume')}
                disabled={isToggling}
              >
                {isRunning ? (
                  <>
                    <Pause className="h-2.5 w-2.5 mr-0.5" /> Stop
                  </>
                ) : (
                  <>
                    <Play className="h-2.5 w-2.5 mr-0.5" /> Start
                  </>
                )}
              </Button>
            </div>
          )
        },
      },
    ],
    [onToggle, isToggling]
  )
}

/**
 * Displays scheduled tasks with controls.
 * Uses usePipelineTasks (30s refresh).
 */
export function ScheduledTasksSection() {
  const { data } = usePipelineTasks()
  const { toggleTask, runPipeline, enableAllTasks, disableAllTasks } = usePipelineActions()
  const [dagOpen, setDagOpen] = useState(true)
  const [decoupledOpen, setDecoupledOpen] = useState(true)
  const [maintenanceOpen, setMaintenanceOpen] = useState(true)

  const handleToggle = useMemo(
    () => (taskName: string, action: 'resume' | 'suspend') =>
      toggleTask.mutate({ taskName, action }),
    [toggleTask]
  )
  const taskColumns = useTaskColumns(handleToggle, toggleTask.isPending)

  if (!data) return null

  const streamTasks = data.tasks.filter((t) => t.dag === 'stream_pipeline')
  const decoupledTasks = data.tasks.filter((t) => t.dag === 'decoupled_pipeline')
  const maintenanceTasks = data.tasks.filter((t) => t.dag === 'maintenance')

  return (
    <div className="space-y-4">
      {/* Manual Run Button */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <strong>Manual Pipeline Run</strong>
              <span className="text-sm text-muted-foreground ml-2 hidden md:inline">
                — Trigger the full pipeline immediately
              </span>
            </div>
            <Button
              onClick={() => runPipeline.mutate()}
              disabled={data.isRunning || runPipeline.isPending}
            >
              {runPipeline.isPending ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Play className="h-4 w-4 mr-2" />
              )}
              Run Now
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Task Sections - 3 column grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Stream Pipeline DAG */}
        <Card>
          <Collapsible open={dagOpen} onOpenChange={setDagOpen}>
            <CollapsibleTrigger asChild>
              <CardHeader className="cursor-pointer hover:bg-muted/50 rounded-t-lg">
                <CardTitle className="flex items-center gap-2 text-base">
                  <ChevronRight
                    className={cn('h-4 w-4 transition-transform', dagOpen && 'rotate-90')}
                  />
                  <span>Stream Pipeline DAG</span>
                  <Badge variant="secondary">{streamTasks.length} tasks</Badge>
                </CardTitle>
                <p className="text-sm text-muted-foreground">
                  Triggered by RAW_ITEMS_STREAM
                </p>
              </CardHeader>
            </CollapsibleTrigger>
            <CollapsibleContent>
              <CardContent className="pt-0">
                <DataTable columns={taskColumns} data={streamTasks} compact />
                <p className="text-xs text-muted-foreground mt-3">
                  <strong>Flow:</strong> DEDUP_FASTPATH (root, scheduled) → CLASSIFY_UNIQUE →
                  VECTOR_PREP → CORTEX_SEARCH | COSINE_MATCH | EDIT_MATCH | JACCARD_MATCH (parallel)
                  → STAGING_MERGE (finalizer)
                </p>
              </CardContent>
            </CollapsibleContent>
          </Collapsible>
        </Card>

        {/* Decoupled Pipeline Tasks */}
        <Card>
          <Collapsible open={decoupledOpen} onOpenChange={setDecoupledOpen}>
            <CollapsibleTrigger asChild>
              <CardHeader className="cursor-pointer hover:bg-muted/50 rounded-t-lg">
                <CardTitle className="flex items-center gap-2 text-base">
                  <ChevronRight
                    className={cn('h-4 w-4 transition-transform', decoupledOpen && 'rotate-90')}
                  />
                  <span>Decoupled Pipeline Tasks</span>
                  <Badge variant="secondary">{decoupledTasks.length} tasks</Badge>
                </CardTitle>
                <p className="text-sm text-muted-foreground">
                  Independent interval-based scoring
                </p>
              </CardHeader>
            </CollapsibleTrigger>
            <CollapsibleContent>
              <CardContent className="pt-0">
                {decoupledTasks.length > 0 ? (
                  <>
                    <DataTable columns={taskColumns} data={decoupledTasks} compact />
                    <p className="text-xs text-muted-foreground mt-3">
                      <strong>Purpose:</strong> ENSEMBLE_SCORING computes weighted scores using 4-method agreement,
                      ITEM_ROUTER routes final matches based on confidence thresholds.
                    </p>
                  </>
                ) : (
                  <p className="text-sm text-muted-foreground">No decoupled tasks configured.</p>
                )}
              </CardContent>
            </CollapsibleContent>
          </Collapsible>
        </Card>

        {/* Maintenance Tasks */}
        <Card>
          <Collapsible open={maintenanceOpen} onOpenChange={setMaintenanceOpen}>
            <CollapsibleTrigger asChild>
              <CardHeader className="cursor-pointer hover:bg-muted/50 rounded-t-lg">
                <CardTitle className="flex items-center gap-2 text-base">
                  <ChevronRight
                    className={cn('h-4 w-4 transition-transform', maintenanceOpen && 'rotate-90')}
                  />
                  <span>Maintenance Tasks</span>
                  <Badge variant="secondary">{maintenanceTasks.length} tasks</Badge>
                </CardTitle>
                <p className="text-sm text-muted-foreground">
                  Scheduled cleanup operations
                </p>
              </CardHeader>
            </CollapsibleTrigger>
            <CollapsibleContent>
              <CardContent className="pt-0">
                {maintenanceTasks.length > 0 ? (
                  <DataTable columns={taskColumns} data={maintenanceTasks} compact />
                ) : (
                  <p className="text-sm text-muted-foreground">No maintenance tasks configured.</p>
                )}
              </CardContent>
            </CollapsibleContent>
          </Collapsible>
        </Card>
      </div>

      {/* Enable/Disable All Buttons */}
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => enableAllTasks.mutate()}
          disabled={enableAllTasks.isPending}
        >
          <Play className="h-4 w-4 mr-1" />
          Enable All Tasks
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => disableAllTasks.mutate()}
          disabled={disableAllTasks.isPending}
        >
          <Pause className="h-4 w-4 mr-1" />
          Disable All Tasks
        </Button>
      </div>
    </div>
  )
}
