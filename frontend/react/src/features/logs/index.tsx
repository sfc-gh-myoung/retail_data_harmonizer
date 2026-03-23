import { useState, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { PageHeader } from '@/components/page-header'
import { SectionWrapper } from '@/components/section-wrapper'
import { useTaskHistory, useTaskFilterOptions, useErrors, useAudit } from './hooks'
import { TaskHistorySection } from './components/task-history-section'
import { RecentErrorsSection } from './components/recent-errors-section'
import { AuditTrailSection } from './components/audit-trail-section'

// Inner components that use suspense hooks - must be wrapped in SectionWrapper

function TaskHistorySectionWrapper() {
  const [page, setPage] = useState(1)
  const [filters, setFilters] = useState<{ taskName?: string; state?: string }>({})
  
  const { data } = useTaskHistory(page, 10, filters)
  const { data: filterOptions } = useTaskFilterOptions()
  const taskHistory = data.taskHistory
  const totalPages = Math.ceil(taskHistory.total / taskHistory.pageSize)

  const handleFilterChange = useCallback((newFilters: { taskName?: string; state?: string }) => {
    setFilters(newFilters)
    setPage(1) // Reset to first page when filters change
  }, [])

  return (
    <TaskHistorySection
      data={{ 
        entries: taskHistory.entries, 
        total: taskHistory.total, 
        page: taskHistory.page, 
        pageSize: taskHistory.pageSize,
        totalPages,
      }}
      filterOptions={filterOptions}
      filters={filters}
      onPageChange={setPage}
      onFilterChange={handleFilterChange}
    />
  )
}

function ErrorsSectionWrapper() {
  const [page, setPage] = useState(1)
  const { data } = useErrors(page)
  const errors = data.recentErrors
  const totalPages = Math.ceil(errors.total / errors.pageSize)
  return (
    <RecentErrorsSection
      data={{ 
        errors: errors.entries, 
        total: errors.total, 
        page: errors.page, 
        pageSize: errors.pageSize,
        totalPages,
      }}
      onPageChange={setPage}
    />
  )
}

function AuditSectionWrapper() {
  const [page, setPage] = useState(1)
  const { data } = useAudit(page)
  const auditLogs = data.auditLogs
  const totalPages = Math.ceil(auditLogs.total / auditLogs.pageSize)
  return (
    <AuditTrailSection
      data={{ 
        entries: auditLogs.entries, 
        total: auditLogs.total, 
        page: auditLogs.page, 
        pageSize: auditLogs.pageSize,
        totalPages,
      }}
      onPageChange={setPage}
    />
  )
}

// Skeleton components with real titles

function TableSkeletonWithTitle({ title, rows = 5 }: { title: string; rows?: number }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {Array.from({ length: rows }).map((_, i) => (
            <Skeleton key={i} className="h-10 w-full" />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

export function Logs() {
  const taskHistoryQuery = useTaskHistory()
  const errorsQuery = useErrors()
  const auditQuery = useAudit()

  const isFetching = taskHistoryQuery.isFetching || errorsQuery.isFetching || auditQuery.isFetching

  const refetchAll = useCallback(() => {
    taskHistoryQuery.refetch()
    errorsQuery.refetch()
    auditQuery.refetch()
  }, [taskHistoryQuery, errorsQuery, auditQuery])

  return (
    <div className="space-y-4">
      <PageHeader
        title="Logs & Observability"
        storageKey="logs-auto-refresh"
        isFetching={isFetching}
        onRefresh={refetchAll}
      />

      {/* Task Execution History */}
      <SectionWrapper
        sectionName="Task History"
        fallback={<TableSkeletonWithTitle title="Task Execution History" rows={5} />}
      >
        <TaskHistorySectionWrapper />
      </SectionWrapper>

      {/* Recent Errors */}
      <SectionWrapper
        sectionName="Recent Errors"
        fallback={<TableSkeletonWithTitle title="Recent Errors" rows={3} />}
      >
        <ErrorsSectionWrapper />
      </SectionWrapper>

      {/* Audit Trail */}
      <SectionWrapper
        sectionName="Audit Trail"
        fallback={<TableSkeletonWithTitle title="Audit Trail" rows={4} />}
      >
        <AuditSectionWrapper />
      </SectionWrapper>
    </div>
  )
}
