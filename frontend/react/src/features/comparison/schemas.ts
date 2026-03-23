import { z } from 'zod'

// ============================================================================
// Algorithms Schema
// ============================================================================

const algorithmSchema = z.object({
  name: z.string(),
  description: z.string(),
  features: z.array(z.string()),
})
export type Algorithm = z.infer<typeof algorithmSchema>

export const algorithmsResponseSchema = z.object({
  algorithms: z.array(algorithmSchema),
})
export type AlgorithmsData = z.infer<typeof algorithmsResponseSchema>

// ============================================================================
// Agreement Schema
// ============================================================================

const agreementDataSchema = z.object({
  level: z.string(),
  count: z.number(),
  avgConfidence: z.number(),
})
export type AgreementData = z.infer<typeof agreementDataSchema>

export const agreementResponseSchema = z.object({
  agreement: z.array(agreementDataSchema),
})
export type AgreementResponse = z.infer<typeof agreementResponseSchema>

// ============================================================================
// Source Performance Schema
// ============================================================================

const sourcePerformanceSchema = z.object({
  source: z.string(),
  itemCount: z.number(),
  avgSearch: z.number(),
  avgCosine: z.number(),
  avgEdit: z.number(),
  avgJaccard: z.number(),
  avgEnsemble: z.number(),
})
export type SourcePerformance = z.infer<typeof sourcePerformanceSchema>

export const sourcePerformanceResponseSchema = z.object({
  sourcePerformance: z.array(sourcePerformanceSchema),
})
export type SourcePerformanceResponse = z.infer<typeof sourcePerformanceResponseSchema>

// ============================================================================
// Method Accuracy Schema
// ============================================================================

const methodAccuracySchema = z.object({
  totalConfirmed: z.number(),
  searchCorrect: z.number(),
  searchAccuracyPct: z.number(),
  cosineCorrect: z.number(),
  cosineAccuracyPct: z.number(),
  editCorrect: z.number(),
  editAccuracyPct: z.number(),
  jaccardCorrect: z.number(),
  jaccardAccuracyPct: z.number(),
  ensembleCorrect: z.number(),
  ensembleAccuracyPct: z.number(),
})
export type MethodAccuracy = z.infer<typeof methodAccuracySchema>

export const methodAccuracyResponseSchema = z.object({
  methodAccuracy: methodAccuracySchema,
})
export type MethodAccuracyResponse = z.infer<typeof methodAccuracyResponseSchema>
