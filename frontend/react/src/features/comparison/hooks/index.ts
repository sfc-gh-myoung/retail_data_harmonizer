import { useSuspenseQuery } from '@tanstack/react-query'
import { fetchApi } from '@/lib/api'
import {
  algorithmsResponseSchema,
  agreementResponseSchema,
  sourcePerformanceResponseSchema,
  methodAccuracyResponseSchema,
  type AlgorithmsData,
  type AgreementResponse,
  type SourcePerformanceResponse,
  type MethodAccuracyResponse,
} from '../schemas'

// Re-export types for convenience
export type {
  Algorithm,
  AgreementData,
  SourcePerformance,
  MethodAccuracy,
} from '../schemas'

/**
 * Fetch algorithm descriptions.
 * Static data - no refetch needed.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useAlgorithms() {
  return useSuspenseQuery({
    queryKey: ['comparison', 'algorithms'],
    queryFn: () => fetchApi('/v2/comparison/algorithms', algorithmsResponseSchema),
    staleTime: Infinity, // Static data, never stale
  })
}

/**
 * Fetch algorithm agreement analysis.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useAgreement() {
  return useSuspenseQuery({
    queryKey: ['comparison', 'agreement'],
    queryFn: () => fetchApi('/v2/comparison/agreement', agreementResponseSchema),
    refetchInterval: 60000, // 60s
  })
}

/**
 * Fetch source performance metrics.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useSourcePerformance() {
  return useSuspenseQuery({
    queryKey: ['comparison', 'source-performance'],
    queryFn: () => fetchApi('/v2/comparison/source-performance', sourcePerformanceResponseSchema),
    refetchInterval: 60000, // 60s
  })
}

/**
 * Fetch method accuracy metrics.
 * Uses useSuspenseQuery to integrate with Suspense boundaries.
 */
export function useMethodAccuracy() {
  return useSuspenseQuery({
    queryKey: ['comparison', 'method-accuracy'],
    queryFn: () => fetchApi('/v2/comparison/method-accuracy', methodAccuracyResponseSchema),
    refetchInterval: 60000, // 60s
  })
}

// Re-export types
export type { AlgorithmsData, AgreementResponse, SourcePerformanceResponse, MethodAccuracyResponse }
