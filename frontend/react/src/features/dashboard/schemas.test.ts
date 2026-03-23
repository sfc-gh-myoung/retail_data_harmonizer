import { describe, it, expect } from 'vitest'
import {
  kpisResponseSchema,
  sourcesResponseSchema,
  categoriesResponseSchema,
  signalsResponseSchema,
  costResponseSchema,
} from './schemas'

describe('kpisResponseSchema', () => {
  const validKpisData = {
    stats: {
      totalRaw: 1000,
      totalUnique: 500,
      totalProcessed: 450,
      autoAccepted: 200,
      confirmed: 150,
      pendingReview: 80,
      rejected: 20,
      needsCategorized: 0,
      matchRate: 0.9,
      total: 450,
    },
    statuses: [
      { label: 'Confirmed', count: 150, color: 'green' },
      { label: 'Pending', count: 80, color: 'yellow' },
    ],
    status_colors_map: {
      CONFIRMED: 'green',
      PENDING_REVIEW: 'yellow',
      REJECTED: 'red',
    },
  }

  it('parses valid kpis response', () => {
    const result = kpisResponseSchema.safeParse(validKpisData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case status_colors_map to camelCase statusColorsMap', () => {
    const result = kpisResponseSchema.parse(validKpisData)
    expect(result.statusColorsMap).toEqual({
      CONFIRMED: 'green',
      PENDING_REVIEW: 'yellow',
      REJECTED: 'red',
    })
    expect('status_colors_map' in result).toBe(false)
  })

  it('rejects missing stats field', () => {
    const invalid = { ...validKpisData, stats: undefined }
    const result = kpisResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects missing statuses field', () => {
    const invalid = { ...validKpisData, statuses: undefined }
    const result = kpisResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects invalid stats number types', () => {
    const invalid = {
      ...validKpisData,
      stats: { ...validKpisData.stats, totalRaw: 'not-a-number' },
    }
    const result = kpisResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('sourcesResponseSchema', () => {
  const validSourcesData = {
    source_systems: {
      POS_A: { CONFIRMED: 100, PENDING: 50 },
      POS_B: { CONFIRMED: 80, REJECTED: 20 },
    },
    source_rates: [
      { source: 'POS_A', total: 150, matched: 140, rate: 0.93 },
      { source: 'POS_B', total: 100, matched: 80, rate: 0.80 },
    ],
    source_max: 150,
  }

  it('parses valid sources response', () => {
    const result = sourcesResponseSchema.safeParse(validSourcesData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case fields to camelCase', () => {
    const result = sourcesResponseSchema.parse(validSourcesData)
    expect(result.sourceSystems).toBeDefined()
    expect(result.sourceRates).toBeDefined()
    expect(result.sourceMax).toBe(150)
    expect('source_systems' in result).toBe(false)
    expect('source_rates' in result).toBe(false)
    expect('source_max' in result).toBe(false)
  })

  it('rejects missing source_systems', () => {
    const invalid = { ...validSourcesData, source_systems: undefined }
    const result = sourcesResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects invalid source_rates array items', () => {
    const invalid = {
      ...validSourcesData,
      source_rates: [{ source: 'POS_A' }], // missing required fields
    }
    const result = sourcesResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('categoriesResponseSchema', () => {
  const validCategoriesData = {
    category_rates: [
      { category: 'Beverages', total: 200, matched: 180, rate: 0.9 },
      { category: 'Snacks', total: 150, matched: 120, rate: 0.8 },
    ],
  }

  it('parses valid categories response', () => {
    const result = categoriesResponseSchema.safeParse(validCategoriesData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case category_rates to camelCase categoryRates', () => {
    const result = categoriesResponseSchema.parse(validCategoriesData)
    expect(result.categoryRates).toHaveLength(2)
    expect(result.categoryRates[0].category).toBe('Beverages')
    expect('category_rates' in result).toBe(false)
  })

  it('rejects missing category_rates', () => {
    const result = categoriesResponseSchema.safeParse({})
    expect(result.success).toBe(false)
  })

  it('accepts empty category_rates array', () => {
    const result = categoriesResponseSchema.safeParse({ category_rates: [] })
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.categoryRates).toHaveLength(0)
    }
  })
})

describe('signalsResponseSchema', () => {
  const validSignalsData = {
    signal_dominance: [
      { method: 'search', count: 500, pct: 50, color: 'blue' },
      { method: 'cosine', count: 300, pct: 30, color: 'purple' },
    ],
    signal_alignment: [
      { method: 'ensemble', count: 400, pct: 40, color: 'green' },
    ],
    agreements: [
      { level: 'High', count: 200, pct: 20, color: 'green' },
      { level: 'Medium', count: 150, pct: 15, color: 'yellow' },
    ],
  }

  it('parses valid signals response', () => {
    const result = signalsResponseSchema.safeParse(validSignalsData)
    expect(result.success).toBe(true)
  })

  it('transforms all snake_case fields to camelCase', () => {
    const result = signalsResponseSchema.parse(validSignalsData)
    expect(result.signalDominance).toBeDefined()
    expect(result.signalAlignment).toBeDefined()
    expect(result.agreements).toBeDefined()
    expect('signal_dominance' in result).toBe(false)
    expect('signal_alignment' in result).toBe(false)
  })

  it('rejects missing signal_dominance', () => {
    const invalid = { ...validSignalsData, signal_dominance: undefined }
    const result = signalsResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects invalid signal item structure', () => {
    const invalid = {
      ...validSignalsData,
      signal_dominance: [{ method: 'search' }], // missing count, pct, color
    }
    const result = signalsResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('costResponseSchema', () => {
  const validCostData = {
    cost_data: {
      totalRuns: 10,
      totalUsd: 5.5,
      totalCredits: 55,
      totalItems: 1000,
      costPerItem: 0.0055,
      baselineWeeklyCost: 100,
      hoursSaved: 20,
      roiPercentage: 250,
      creditRateUsd: 0.1,
      manualHourlyRate: 25,
      manualMinutesPerItem: 5,
    },
    scale_data: {
      total: 1000,
      uniqueCount: 500,
      dedupRatio: 2.0,
      fastPathCount: 200,
      fastPathRate: 0.4,
    },
  }

  it('parses valid cost response', () => {
    const result = costResponseSchema.safeParse(validCostData)
    expect(result.success).toBe(true)
  })

  it('transforms snake_case fields to camelCase', () => {
    const result = costResponseSchema.parse(validCostData)
    expect(result.costData).toBeDefined()
    expect(result.scaleData).toBeDefined()
    expect('cost_data' in result).toBe(false)
    expect('scale_data' in result).toBe(false)
  })

  it('handles nullable cost_data (when no cost tracking)', () => {
    const noCostData = {
      cost_data: null,
      scale_data: validCostData.scale_data,
    }
    const result = costResponseSchema.safeParse(noCostData)
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.costData).toBeNull()
      expect(result.data.scaleData).toBeDefined()
    }
  })

  it('rejects missing scale_data', () => {
    const invalid = { cost_data: validCostData.cost_data }
    const result = costResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects invalid cost_data structure', () => {
    const invalid = {
      cost_data: { totalRuns: 'not-a-number' },
      scale_data: validCostData.scale_data,
    }
    const result = costResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})
