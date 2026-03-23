import { useState, Fragment } from 'react'
import { ChevronRight, Check, X, Play } from 'lucide-react'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible'
import { FilterSearch } from '@/components/data-table/filters/filter-search'
import { FilterSelect } from '@/components/data-table/filters/filter-select'
import { cn } from '@/lib/utils'
import type { TaskHistoryEntry, TaskFilterOptions } from '../schemas'

interface PaginatedData<T> {
  entries: T[]
  total: number
  page: number
  pageSize: number
  totalPages?: number
}

interface TaskHistoryFilters {
  taskName?: string
  state?: string
}

interface TaskHistorySectionProps {
  data: PaginatedData<TaskHistoryEntry>
  filterOptions: TaskFilterOptions
  filters: TaskHistoryFilters
  onPageChange: (page: number) => void
  onFilterChange: (filters: TaskHistoryFilters) => void
}

const stateIcons: Record<string, React.ReactNode> = {
  SUCCEEDED: <Check className="h-3 w-3" />,
  FAILED: <X className="h-3 w-3" />,
  EXECUTING: <Play className="h-3 w-3" />,
}

const stateColors: Record<string, string> = {
  SUCCEEDED: 'text-green-600 dark:text-green-400',
  FAILED: 'text-red-600 dark:text-red-400',
  EXECUTING: 'text-yellow-600 dark:text-yellow-400',
  SCHEDULED: 'text-blue-600 dark:text-blue-400',
  CANCELLED: 'text-gray-600 dark:text-gray-400',
  SKIPPED: 'text-gray-500 dark:text-gray-500',
}

function formatDuration(seconds: number | null): string {
  if (seconds == null) return '--'
  if (seconds >= 60) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.round(seconds % 60)
    return `${mins}m ${secs}s`
  }
  return `${seconds.toFixed(1)}s`
}

function formatTime(dateStr: string | null, format: 'date' | 'time' = 'date'): string {
  if (!dateStr) return '--'
  const date = new Date(dateStr)
  if (format === 'time') {
    return date.toLocaleTimeString('en-US', { hour12: false })
  }
  return date.toLocaleDateString('en-US', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

export function TaskHistorySection({ data, filterOptions, filters, onPageChange, onFilterChange }: TaskHistorySectionProps) {
  const [isOpen, setIsOpen] = useState(true)
  const [expandedRows, setExpandedRows] = useState<Set<number>>(new Set())

  const toggleRow = (index: number) => {
    setExpandedRows((prev) => {
      const next = new Set(prev)
      if (next.has(index)) {
        next.delete(index)
      } else {
        next.add(index)
      }
      return next
    })
  }

  const succeededCount = data.entries.filter((t) => t.state === 'SUCCEEDED').length
  const failedCount = data.entries.filter((t) => t.state === 'FAILED').length
  const totalPages = data.totalPages ?? Math.ceil(data.total / data.pageSize)

  const stateOptions = filterOptions.states.map((s) => ({ value: s, label: s }))

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen} className="mb-3">
      <CollapsibleTrigger className="flex items-center gap-2 w-full p-4 bg-secondary/50 rounded-lg hover:bg-secondary/70 transition-colors">
        <ChevronRight
          className={cn('h-4 w-4 transition-transform', isOpen && 'rotate-90')}
        />
        <span className="font-semibold">Task Execution History</span>
      </CollapsibleTrigger>
      <CollapsibleContent className="px-4 pb-4 bg-secondary/50 rounded-b-lg">
        {/* Filter bar */}
        <div className="flex flex-wrap items-center gap-3 py-3 border-b border-border/50 mb-3">
          <FilterSearch
            value={filters.taskName}
            onChange={(v) => onFilterChange({ ...filters, taskName: v })}
            placeholder="Search task name..."
          />
          <FilterSelect
            value={filters.state}
            onChange={(v) => onFilterChange({ ...filters, state: v })}
            options={stateOptions}
            placeholder="All states"
          />
        </div>
        {data.entries.length === 0 ? (
          <p className="text-muted-foreground py-4">
            No task execution history matches the current filters.
          </p>
        ) : (
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <div className="text-sm text-muted-foreground">
                Showing {(data.page - 1) * data.pageSize + 1}-
                {Math.min(data.page * data.pageSize, data.total)} of {data.total} items
              </div>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Task</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Scheduled</TableHead>
                    <TableHead>Started</TableHead>
                    <TableHead className="text-right">Duration</TableHead>
                    <TableHead>Error</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.entries.map((task, index) => (
                    <Fragment key={index}>
                      <TableRow
                        className="cursor-pointer hover:bg-muted/50"
                        onClick={() => toggleRow(index)}
                      >
                        <TableCell className="text-sm">
                          <span className="flex items-center gap-1">
                            <ChevronRight
                              className={cn(
                                'h-3 w-3 transition-transform',
                                expandedRows.has(index) && 'rotate-90'
                              )}
                            />
                            <code className="text-xs">{task.taskName}</code>
                          </span>
                        </TableCell>
                        <TableCell>
                          <span className={cn('flex items-center gap-1 font-semibold', stateColors[task.state])}>
                            {stateIcons[task.state]}
                            {task.state}
                          </span>
                        </TableCell>
                        <TableCell className="text-sm">
                          {formatTime(task.scheduledTime)}
                        </TableCell>
                        <TableCell className="text-sm">
                          {formatTime(task.queryStartTime, 'time')}
                        </TableCell>
                        <TableCell className="text-right text-sm">
                          {formatDuration(task.durationSeconds)}
                        </TableCell>
                        <TableCell>
                          {task.errorMessage ? (
                            <span className="text-red-600 dark:text-red-400" title={task.errorMessage}>
                              ⚠ Error
                            </span>
                          ) : (
                            '--'
                          )}
                        </TableCell>
                      </TableRow>
                      {expandedRows.has(index) && (
                        <TableRow className="bg-muted/30">
                          <TableCell colSpan={6} className="p-4">
                            <div className="space-y-3">
                              <div className="flex flex-wrap gap-4 text-sm">
                                <div>
                                  <span className="text-muted-foreground">Task:</span>{' '}
                                  <code className="text-xs font-semibold">{task.taskName}</code>
                                </div>
                                <div>
                                  <span className="text-muted-foreground">State:</span>{' '}
                                  <span className={cn('font-semibold', stateColors[task.state])}>
                                    {task.state}
                                  </span>
                                </div>
                                <div>
                                  <span className="text-muted-foreground">Scheduled:</span>{' '}
                                  {formatTime(task.scheduledTime)}
                                </div>
                                <div>
                                  <span className="text-muted-foreground">Started:</span>{' '}
                                  {formatTime(task.queryStartTime, 'time')}
                                </div>
                                <div>
                                  <span className="text-muted-foreground">Duration:</span>{' '}
                                  {formatDuration(task.durationSeconds)}
                                </div>

                              </div>


                              {task.errorMessage && (
                                <div className="border-t pt-3">
                                  <h4 className="font-semibold text-red-600 dark:text-red-400 mb-2">
                                    Error Details
                                  </h4>
                                  <pre className="bg-background p-3 rounded text-sm overflow-auto text-red-600 dark:text-red-400 max-h-48 whitespace-pre-wrap">
                                    {task.errorMessage}
                                  </pre>
                                </div>
                              )}
                            </div>
                          </TableCell>
                        </TableRow>
                      )}
                    </Fragment>
                  ))}
                </TableBody>
              </Table>
            </div>
            <div className="flex justify-between items-center">
              <div className="text-sm text-muted-foreground">
                <span className="text-green-600 dark:text-green-400">{succeededCount} succeeded</span>
                {' • '}
                <span className={failedCount > 0 ? 'text-red-600 dark:text-red-400' : ''}>
                  {failedCount} failed
                </span>
              </div>
              {totalPages > 1 && (
                <div className="flex gap-2">
                  <button
                    className="px-3 py-1 text-sm border rounded disabled:opacity-50"
                    disabled={data.page <= 1}
                    onClick={(e) => { e.stopPropagation(); onPageChange(data.page - 1) }}
                  >
                    Previous
                  </button>
                  <span className="px-3 py-1 text-sm">
                    {data.page} / {totalPages}
                  </span>
                  <button
                    className="px-3 py-1 text-sm border rounded disabled:opacity-50"
                    disabled={data.page >= totalPages}
                    onClick={(e) => { e.stopPropagation(); onPageChange(data.page + 1) }}
                  >
                    Next
                  </button>
                </div>
              )}
            </div>
          </div>
        )}
      </CollapsibleContent>
    </Collapsible>
  )
}
