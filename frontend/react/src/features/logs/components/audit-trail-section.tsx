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
import type { AuditLogEntry } from '../schemas'

interface PaginatedData {
  entries: AuditLogEntry[]
  total: number
  page: number
  pageSize: number
  totalPages?: number
}

interface AuditTrailSectionProps {
  data: PaginatedData
  onPageChange: (page: number) => void
}

export function AuditTrailSection({ data, onPageChange }: AuditTrailSectionProps) {
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
        <span className="font-semibold">Audit Trail</span>
        {data.total > 0 && (
          <Badge variant="secondary" className="ml-2">
            {data.total} events
          </Badge>
        )}
      </CollapsibleTrigger>
      <CollapsibleContent className="px-4 pb-4 bg-secondary/50 rounded-b-lg">
        {data.entries.length === 0 ? (
          <p className="text-muted-foreground py-4">No audit events in the last 7 days.</p>
        ) : (
          <>
            <div className="flex justify-between items-center mb-3">
              <div className="text-sm text-muted-foreground">
                Showing {(data.page - 1) * data.pageSize + 1}-
                {Math.min(data.page * data.pageSize, data.total)} of {data.total} items
              </div>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Time</TableHead>
                    <TableHead>Action</TableHead>
                    <TableHead>Changed By</TableHead>
                    <TableHead>Table</TableHead>
                    <TableHead>Old Value</TableHead>
                    <TableHead>New Value</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.entries.map((log: AuditLogEntry, index: number) => (
                    <Fragment key={log.auditId}>
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
                            {log.changedAt?.slice(0, 16) || ''}
                          </span>
                        </TableCell>
                        <TableCell>
                          <Badge variant="secondary">{log.actionType}</Badge>
                        </TableCell>
                        <TableCell>{log.changedBy || 'System'}</TableCell>
                        <TableCell>{log.tableName || '—'}</TableCell>
                        <TableCell className="max-w-[120px] truncate" title={log.oldValue || ''}>
                          {log.oldValue || '—'}
                        </TableCell>
                        <TableCell className="max-w-[120px] truncate" title={log.newValue || ''}>
                          {log.newValue || '—'}
                        </TableCell>
                      </TableRow>
                      {expandedRows.has(index) && (
                        <TableRow className="bg-muted/30">
                          <TableCell colSpan={6} className="p-4">
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                              <div>
                                <div className="text-muted-foreground text-xs">Action Type</div>
                                <Badge variant="secondary">{log.actionType}</Badge>
                              </div>
                              <div>
                                <div className="text-muted-foreground text-xs">Changed By</div>
                                {log.changedBy || 'System'}
                              </div>
                              <div>
                                <div className="text-muted-foreground text-xs">Table</div>
                                {log.tableName}
                              </div>
                              <div>
                                <div className="text-muted-foreground text-xs">Record ID</div>
                                <code className="text-xs">{log.recordId || '—'}</code>
                              </div>
                              <div>
                                <div className="text-muted-foreground text-xs">Audit ID</div>
                                <code className="text-xs">{log.auditId}</code>
                              </div>
                              <div>
                                <div className="text-muted-foreground text-xs">Changed At</div>
                                {log.changedAt}
                              </div>
                              {log.oldValue && (
                                <div className="col-span-full">
                                  <div className="text-muted-foreground text-xs mb-1">Old Value</div>
                                  <div className="bg-background p-2 rounded text-sm font-mono text-xs">
                                    {log.oldValue}
                                  </div>
                                </div>
                              )}
                              {log.newValue && (
                                <div className="col-span-full">
                                  <div className="text-muted-foreground text-xs mb-1">New Value</div>
                                  <div className="bg-background p-2 rounded text-sm font-mono text-xs">
                                    {log.newValue}
                                  </div>
                                </div>
                              )}
                              {log.changeReason && (
                                <div className="col-span-full">
                                  <div className="text-muted-foreground text-xs mb-1">Reason</div>
                                  <div className="bg-background p-2 rounded text-sm">
                                    {log.changeReason}
                                  </div>
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
