/**
 * Type re-exports and aliases for dashboard components.
 * These types are used by dashboard sub-components for prop typing.
 */

// CostData and ScaleData are the inner metric types (not the combined response)
export type { CostMetrics as CostData, ScaleMetrics as ScaleData } from './schemas'

export type SourceSystems = Record<string, Record<string, number>>
export type StatusColorsMap = Record<string, string>
