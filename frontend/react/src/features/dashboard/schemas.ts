import { z } from 'zod'

// ============================================================================
// KPIs Schema - matches backend KpisResponse
// Uses snake_case for API validation, transforms to camelCase for TypeScript
// ============================================================================

const kpiDataSchema = z.object({
  totalRaw: z.number(),
  totalUnique: z.number(),
  totalProcessed: z.number(),
  autoAccepted: z.number(),
  confirmed: z.number(),
  pendingReview: z.number(),
  rejected: z.number(),
  needsCategorized: z.number(),
  matchRate: z.number(),
  total: z.number(),
})
export type KpiData = z.infer<typeof kpiDataSchema>

const statusItemSchema = z.object({
  label: z.string(),
  count: z.number(),
  color: z.string(),
})
export type StatusItem = z.infer<typeof statusItemSchema>

export const kpisResponseSchema = z
  .object({
    stats: kpiDataSchema,
    statuses: z.array(statusItemSchema),
    status_colors_map: z.record(z.string(), z.string()),
  })
  .transform((data) => ({
    stats: data.stats,
    statuses: data.statuses,
    statusColorsMap: data.status_colors_map,
  }))
export type KpisData = z.infer<typeof kpisResponseSchema>

// ============================================================================
// Sources Schema - matches backend SourcesResponse
// ============================================================================

const sourceRateSchema = z.object({
  source: z.string(),
  total: z.number(),
  matched: z.number(),
  rate: z.number(),
})
export type SourceRate = z.infer<typeof sourceRateSchema>

export const sourcesResponseSchema = z
  .object({
    source_systems: z.record(z.string(), z.record(z.string(), z.number())),
    source_rates: z.array(sourceRateSchema),
    source_max: z.number(),
  })
  .transform((data) => ({
    sourceSystems: data.source_systems,
    sourceRates: data.source_rates,
    sourceMax: data.source_max,
  }))
export type SourcesData = z.infer<typeof sourcesResponseSchema>

// ============================================================================
// Categories Schema - matches backend CategoriesResponse
// ============================================================================

const categoryRateSchema = z.object({
  category: z.string(),
  total: z.number(),
  matched: z.number(),
  rate: z.number(),
})
export type CategoryRate = z.infer<typeof categoryRateSchema>

export const categoriesResponseSchema = z
  .object({
    category_rates: z.array(categoryRateSchema),
  })
  .transform((data) => ({
    categoryRates: data.category_rates,
  }))
export type CategoriesData = z.infer<typeof categoriesResponseSchema>

// ============================================================================
// Signals Schema - matches backend SignalsResponse
// ============================================================================

const signalDominanceSchema = z.object({
  method: z.string(),
  count: z.number(),
  pct: z.number(),
  color: z.string(),
})
export type SignalDominance = z.infer<typeof signalDominanceSchema>

const signalAlignmentSchema = z.object({
  method: z.string(),
  count: z.number(),
  pct: z.number(),
  color: z.string(),
})
export type SignalAlignment = z.infer<typeof signalAlignmentSchema>

const agreementLevelSchema = z.object({
  level: z.string(),
  count: z.number(),
  pct: z.number(),
  color: z.string(),
})
export type AgreementLevel = z.infer<typeof agreementLevelSchema>

export const signalsResponseSchema = z
  .object({
    signal_dominance: z.array(signalDominanceSchema),
    signal_alignment: z.array(signalAlignmentSchema),
    agreements: z.array(agreementLevelSchema),
  })
  .transform((data) => ({
    signalDominance: data.signal_dominance,
    signalAlignment: data.signal_alignment,
    agreements: data.agreements,
  }))
export type SignalsData = z.infer<typeof signalsResponseSchema>

// ============================================================================
// Cost Schema - matches backend CostResponse
// ============================================================================

const costMetricsSchema = z.object({
  totalRuns: z.number(),
  totalUsd: z.number(),
  totalCredits: z.number(),
  totalItems: z.number(),
  costPerItem: z.number(),
  baselineWeeklyCost: z.number(),
  hoursSaved: z.number(),
  roiPercentage: z.number(),
  creditRateUsd: z.number(),
  manualHourlyRate: z.number(),
  manualMinutesPerItem: z.number(),
})
export type CostMetrics = z.infer<typeof costMetricsSchema>

const scaleMetricsSchema = z.object({
  total: z.number(),
  uniqueCount: z.number(),
  dedupRatio: z.number(),
  fastPathCount: z.number(),
  fastPathRate: z.number(),
})
export type ScaleMetrics = z.infer<typeof scaleMetricsSchema>

export const costResponseSchema = z
  .object({
    cost_data: costMetricsSchema.nullable(),
    scale_data: scaleMetricsSchema,
  })
  .transform((data) => ({
    costData: data.cost_data,
    scaleData: data.scale_data,
  }))
export type CostData = z.infer<typeof costResponseSchema>
