import { z } from 'zod'

// ============================================================================
// Task History Schema
// ============================================================================

const taskHistoryEntrySchema = z.object({
  taskName: z.string(),
  state: z.string(),
  scheduledTime: z.string().nullable(),
  queryStartTime: z.string().nullable(),
  durationSeconds: z.number().nullable(),
  errorMessage: z.string().nullable(),
})
export type TaskHistoryEntry = z.infer<typeof taskHistoryEntrySchema>

const paginatedTaskHistorySchema = z.object({
  entries: z.array(taskHistoryEntrySchema),
  total: z.number(),
  page: z.number(),
  pageSize: z.number(),
  totalPages: z.number(),
})

export const taskHistoryResponseSchema = z.object({
  taskHistory: paginatedTaskHistorySchema,
})
export type TaskHistoryData = z.infer<typeof taskHistoryResponseSchema>

// Task filter options schema
export const taskFilterOptionsSchema = z.object({
  taskNames: z.array(z.string()),
  states: z.array(z.string()),
})
export type TaskFilterOptions = z.infer<typeof taskFilterOptionsSchema>

// ============================================================================
// Errors Schema
// ============================================================================

const recentErrorSchema = z.object({
  logId: z.string(),
  runId: z.string(),
  stepName: z.string(),
  category: z.string().nullable(),
  errorMessage: z.string(),
  itemsFailed: z.number(),
  queryId: z.string().nullable(),
  createdAt: z.string(),
})
export type RecentError = z.infer<typeof recentErrorSchema>

const paginatedErrorsSchema = z.object({
  entries: z.array(recentErrorSchema),
  total: z.number(),
  page: z.number(),
  pageSize: z.number(),
  totalPages: z.number(),
})

export const errorsResponseSchema = z.object({
  recentErrors: paginatedErrorsSchema,
})
export type ErrorsData = z.infer<typeof errorsResponseSchema>

// ============================================================================
// Audit Schema
// ============================================================================

const auditLogEntrySchema = z.object({
  auditId: z.string(),
  actionType: z.string(),
  tableName: z.string(),
  recordId: z.string().nullable(),
  oldValue: z.string().nullable(),
  newValue: z.string().nullable(),
  changedBy: z.string(),
  changedAt: z.string(),
  changeReason: z.string().nullable(),
})
export type AuditLogEntry = z.infer<typeof auditLogEntrySchema>

const paginatedAuditLogsSchema = z.object({
  entries: z.array(auditLogEntrySchema),
  total: z.number(),
  page: z.number(),
  pageSize: z.number(),
  totalPages: z.number(),
})

export const auditResponseSchema = z.object({
  auditLogs: paginatedAuditLogsSchema,
})
export type AuditData = z.infer<typeof auditResponseSchema>
