import { z } from 'zod'

// ============================================================================
// Funnel Schema - matches backend FunnelResponse
// Uses snake_case for API validation, transforms to camelCase for TypeScript
// ============================================================================
export const funnelSchema = z
  .object({
    raw_items: z.number(),
    categorized_items: z.number(),
    blocked_items: z.number(),
    unique_descriptions: z.number(),
    pipeline_items: z.number(),
    ensemble_done: z.number().default(0),
  })
  .transform((data) => ({
    rawItems: data.raw_items,
    categorizedItems: data.categorized_items,
    blockedItems: data.blocked_items,
    uniqueDescriptions: data.unique_descriptions,
    pipelineItems: data.pipeline_items,
    ensembleDone: data.ensemble_done,
  }))
export type FunnelData = z.infer<typeof funnelSchema>

// ============================================================================
// Phases Schema - matches backend PhasesResponse
// ============================================================================
export const phaseStateSchema = z.enum(['WAITING', 'PROCESSING', 'COMPLETE', 'SKIPPED', 'ERROR'])
export type PhaseState = z.infer<typeof phaseStateSchema>

const phaseProgressItemSchema = z
  .object({
    name: z.string(),
    done: z.number(),
    total: z.number(),
    pct: z.number().min(0).max(100),
    state: phaseStateSchema,
    color: z.string(),
  })
  .transform((data) => ({
    name: data.name,
    done: data.done,
    total: data.total,
    pct: data.pct,
    state: data.state,
    color: data.color,
  }))
export type PhaseProgress = z.infer<typeof phaseProgressItemSchema>

export const phasesResponseSchema = z
  .object({
    phases: z.array(phaseProgressItemSchema),
    pipeline_state: z.string().nullable(),
    active_phase: z.string().nullable(),
    ensemble_waiting_for: z.string().nullable(),
    batch_id: z.string().nullable(),
  })
  .transform((data) => ({
    phases: data.phases,
    pipelineState: data.pipeline_state,
    activePhase: data.active_phase,
    ensembleWaitingFor: data.ensemble_waiting_for,
    batchId: data.batch_id,
  }))
export type PhasesData = z.infer<typeof phasesResponseSchema>

// ============================================================================
// Tasks Schema - matches backend TasksResponse
// ============================================================================
const taskStateSchema = z
  .object({
    name: z.string(),
    state: z.string(),
    schedule: z.string().nullable(),
    role: z.string(),
    level: z.number(),
    dag: z.string().nullable(),
  })
  .transform((data) => ({
    name: data.name,
    state: data.state,
    schedule: data.schedule,
    role: data.role,
    level: data.level,
    dag: data.dag,
  }))
export type TaskState = z.infer<typeof taskStateSchema>

export const tasksResponseSchema = z
  .object({
    tasks: z.array(taskStateSchema),
    all_tasks_suspended: z.boolean(),
    pending_count: z.number(),
    is_running: z.boolean(),
  })
  .transform((data) => ({
    tasks: data.tasks,
    allTasksSuspended: data.all_tasks_suspended,
    pendingCount: data.pending_count,
    isRunning: data.is_running,
  }))
export type TasksData = z.infer<typeof tasksResponseSchema>

// ============================================================================
// Action Response Schema - matches backend ActionResponse
// ============================================================================
export const actionResponseSchema = z
  .object({
    success: z.boolean(),
    message: z.string(),
    job_id: z.string().nullable().optional(),
  })
  .transform((data) => ({
    success: data.success,
    message: data.message,
    jobId: data.job_id ?? null,
  }))
export type ActionResponse = z.infer<typeof actionResponseSchema>
