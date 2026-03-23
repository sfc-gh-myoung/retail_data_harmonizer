import { describe, it, expect } from 'vitest'
import {
  funnelSchema,
  phaseStateSchema,
  phasesResponseSchema,
  tasksResponseSchema,
  actionResponseSchema,
} from './schemas'

describe('funnelSchema', () => {
  const validFunnelData = {
    raw_items: 1000,
    categorized_items: 950,
    blocked_items: 50,
    unique_descriptions: 500,
    pipeline_items: 450,
    ensemble_done: 400,
  }

  it('parses valid funnel response', () => {
    const result = funnelSchema.safeParse(validFunnelData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case to camelCase', () => {
    const result = funnelSchema.parse(validFunnelData)
    expect(result.rawItems).toBe(1000)
    expect(result.categorizedItems).toBe(950)
    expect(result.blockedItems).toBe(50)
    expect(result.uniqueDescriptions).toBe(500)
    expect(result.pipelineItems).toBe(450)
    expect(result.ensembleDone).toBe(400)
    expect('raw_items' in result).toBe(false)
  })

  it('uses default values for optional fields', () => {
    const minimalData = {
      raw_items: 100,
      categorized_items: 90,
      blocked_items: 10,
      unique_descriptions: 50,
      pipeline_items: 45,
    }
    const result = funnelSchema.parse(minimalData)
    expect(result.ensembleDone).toBe(0)
  })

  it('rejects missing required fields', () => {
    const invalid = { raw_items: 100 }
    const result = funnelSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('phaseStateSchema', () => {
  it('accepts valid phase states', () => {
    const validStates = ['WAITING', 'PROCESSING', 'COMPLETE', 'SKIPPED', 'ERROR']
    validStates.forEach(state => {
      const result = phaseStateSchema.safeParse(state)
      expect(result.success).toBe(true)
    })
  })

  it('rejects invalid phase state', () => {
    const result = phaseStateSchema.safeParse('INVALID_STATE')
    expect(result.success).toBe(false)
  })
})

describe('phasesResponseSchema', () => {
  const validPhasesData = {
    phases: [
      { name: 'Categorization', done: 100, total: 100, pct: 100, state: 'COMPLETE', color: 'green' },
      { name: 'Ensemble', done: 50, total: 100, pct: 50, state: 'PROCESSING', color: 'blue' },
    ],
    pipeline_state: 'RUNNING',
    active_phase: 'Ensemble',
    ensemble_waiting_for: null,
    batch_id: 'batch-123',
  }

  it('parses valid phases response', () => {
    const result = phasesResponseSchema.safeParse(validPhasesData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case to camelCase', () => {
    const result = phasesResponseSchema.parse(validPhasesData)
    expect(result.pipelineState).toBe('RUNNING')
    expect(result.activePhase).toBe('Ensemble')
    expect(result.ensembleWaitingFor).toBeNull()
    expect(result.batchId).toBe('batch-123')
    expect('pipeline_state' in result).toBe(false)
  })

  it('handles nullable fields', () => {
    const withNulls = {
      phases: [],
      pipeline_state: null,
      active_phase: null,
      ensemble_waiting_for: null,
      batch_id: null,
    }
    const result = phasesResponseSchema.parse(withNulls)
    expect(result.pipelineState).toBeNull()
    expect(result.activePhase).toBeNull()
    expect(result.batchId).toBeNull()
  })

  it('validates phase pct is between 0 and 100', () => {
    const invalidPct = {
      ...validPhasesData,
      phases: [{ name: 'Test', done: 0, total: 100, pct: 150, state: 'WAITING', color: 'gray' }],
    }
    const result = phasesResponseSchema.safeParse(invalidPct)
    expect(result.success).toBe(false)
  })
})

describe('tasksResponseSchema', () => {
  const validTasksData = {
    tasks: [
      { name: 'HARMONIZER_REFRESH', state: 'SCHEDULED', schedule: '*/5 * * * *', role: 'ADMIN', level: 1, dag: null },
      { name: 'CATEGORIZER_TASK', state: 'SUSPENDED', schedule: null, role: 'ADMIN', level: 2, dag: 'HARMONIZER_REFRESH' },
    ],
    all_tasks_suspended: false,
    pending_count: 5,
    is_running: true,
  }

  it('parses valid tasks response', () => {
    const result = tasksResponseSchema.safeParse(validTasksData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case to camelCase', () => {
    const result = tasksResponseSchema.parse(validTasksData)
    expect(result.allTasksSuspended).toBe(false)
    expect(result.pendingCount).toBe(5)
    expect(result.isRunning).toBe(true)
    expect('all_tasks_suspended' in result).toBe(false)
  })

  it('handles nullable schedule and dag fields', () => {
    const result = tasksResponseSchema.parse(validTasksData)
    expect(result.tasks[0].dag).toBeNull()
    expect(result.tasks[1].schedule).toBeNull()
  })
})

describe('actionResponseSchema', () => {
  it('parses valid action response with job_id', () => {
    const data = { success: true, message: 'Pipeline started', job_id: 'job-456' }
    const result = actionResponseSchema.safeParse(data)
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.jobId).toBe('job-456')
    }
  })

  it('parses valid action response without job_id', () => {
    const data = { success: true, message: 'Tasks resumed' }
    const result = actionResponseSchema.safeParse(data)
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.jobId).toBeNull()
    }
  })

  it('transforms snake_case job_id to camelCase jobId', () => {
    const data = { success: false, message: 'Failed to start', job_id: null }
    const result = actionResponseSchema.parse(data)
    expect(result.jobId).toBeNull()
    expect('job_id' in result).toBe(false)
  })

  it('rejects missing success field', () => {
    const invalid = { message: 'Test' }
    const result = actionResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects missing message field', () => {
    const invalid = { success: true }
    const result = actionResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})
