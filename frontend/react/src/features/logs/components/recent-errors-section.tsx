import { useState, Fragment } from 'react'
import { ChevronRight } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
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
import { cn } from '@/lib/utils'
import type { RecentError } from '../schemas'

interface PaginatedErrorsData {
  errors: RecentError[]
  total: number
  page: number
  pageSize: number
  totalPages?: number
}

interface RecentErrorsSectionProps {
  data: PaginatedErrorsData
  onPageChange: (page: number) => void
}

export function RecentErrorsSection({ data, onPageChange }: RecentErrorsSectionProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [expandedRows, setExpandedRows] = useState<Set<number>>(new Set())
  const totalPages = data.totalPages ?? Math.ceil(data.total / data.pageSize)

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

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen} className="mb-3">
      <CollapsibleTrigger className="flex items-center gap-2 w-full p-4 bg-secondary/50 rounded-lg hover:bg-secondary/70 transition-colors">
        <ChevronRight
          className={cn('h-4 w-4 transition-transform', isOpen && 'rotate-90')}
        />
        <span className="font-semibold">Recent Errors</span>
        {data.total > 0 && (
          <Badge variant="destructive" className="ml-2">
            {data.total} errors
          </Badge>
        )}
      </CollapsibleTrigger>
      <CollapsibleContent className="px-4 pb-4 bg-secondary/50 rounded-b-lg">
        {data.errors.length === 0 ? (
          <p className="text-muted-foreground py-4">No errors in the last 7 days.</p>
        ) : (
          <>
            <div className="flex justify-between items-center mb-3">
              <div className="text-sm text-muted-foreground">
                Showing {(data.page - 1) * data.pageSize + 1}-
                {Math.min(data.page * data.pageSize, data.total)} of {data.total} errors
              </div>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Time</TableHead>
                    <TableHead>Step</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>Error Message</TableHead>
                    <TableHead className="text-right">Items Failed</TableHead>
                    <TableHead>Query ID</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.errors.map((error: RecentError, index: number) => (
                    <Fragment key={error.logId}>
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
                            {error.createdAt?.slice(0, 16) || ''}
                          </span>
                        </TableCell>
                        <TableCell>{error.stepName}</TableCell>
                        <TableCell>{error.category || '—'}</TableCell>
                        <TableCell
                          className="text-red-600 dark:text-red-400 max-w-md truncate"
                          title={error.errorMessage}
                        >
                          {(error.errorMessage || 'Unknown error').slice(0, 80)}
                          {error.errorMessage?.length > 80 && '...'}
                        </TableCell>
                        <TableCell className="text-right">{error.itemsFailed || 0}</TableCell>
                        <TableCell>
                          <code className="text-xs">{error.queryId || '—'}</code>
                        </TableCell>
                      </TableRow>
                      {expandedRows.has(index) && (
                        <TableRow className="bg-muted/30">
                          <TableCell colSpan={6} className="p-4">
                            <h4 className="font-semibold text-red-600 dark:text-red-400 mb-2">
                              Full Error Message
                            </h4>
                            <pre className="bg-background p-3 rounded text-sm overflow-auto text-red-600 dark:text-red-400 max-h-48">
                              {error.errorMessage || 'Unknown error'}
                            </pre>
                            <div className="flex flex-wrap gap-4 mt-3 text-sm">
                              <div>
                                <span className="text-muted-foreground">Log ID:</span>{' '}
                                <code className="text-xs">{error.logId}</code>
                              </div>
                              <div>
                                <span className="text-muted-foreground">Run ID:</span>{' '}
                                <code className="text-xs">{error.runId}</code>
                              </div>
                              {error.queryId && (
                                <div>
                                  <span className="text-muted-foreground">Query ID:</span>{' '}
                                  <code className="text-xs">{error.queryId}</code>
                                </div>
                              )}
                              <div>
                                <span className="text-muted-foreground">Step:</span>{' '}
                                {error.stepName}
                              </div>
                              <div>
                                <span className="text-muted-foreground">Category:</span>{' '}
                                {error.category || '—'}
                              </div>
                              <div>
                                <span className="text-muted-foreground">Items Failed:</span>{' '}
                                {error.itemsFailed || 0}
                              </div>
                            </div>
                          </TableCell>
                        </TableRow>
                      )}
                    </Fragment>
                  ))}
                </TableBody>
              </Table>
            </div>
            {totalPages > 1 && (
              <div className="flex justify-end mt-3">
                <div className="flex gap-2">
                  <button
                    className="px-3 py-1 text-sm border rounded disabled:opacity-50"
                    disabled={data.page <= 1}
                    onClick={() => onPageChange(data.page - 1)}
                  >
                    Previous
                  </button>
                  <span className="px-3 py-1 text-sm">
                    {data.page} / {totalPages}
                  </span>
                  <button
                    className="px-3 py-1 text-sm border rounded disabled:opacity-50"
                    disabled={data.page >= totalPages}
                    onClick={() => onPageChange(data.page + 1)}
                  >
                    Next
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </CollapsibleContent>
    </Collapsible>
  )
}
