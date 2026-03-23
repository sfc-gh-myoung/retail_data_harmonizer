export interface DashboardStats {
  totalRaw: number
  totalUnique: number
  totalProcessed: number
  autoAccepted: number
  confirmed: number
  pendingReview: number
  rejected: number
  needsCategorized: number
  matchRate: number
  total: number
}

export interface StatusItem {
  label: string
  count: number
  color: string
}

export interface SignalDominance {
  method: string
  count: number
  pct: number
  color: string
}

export interface SignalAlignment {
  method: string
  count: number
  pct: number
  color: string
}

export interface AgreementLevel {
  level: string
  count: number
  pct: number
  color: string
}

export interface SourceRate {
  source: string
  rate: number
  total: number
}

export interface CategoryRate {
  category: string
  rate: number
  matched: number
  total: number
}

export interface SourceSystemStatus {
  [status: string]: number
}

export interface SourceSystems {
  [source: string]: SourceSystemStatus
}

export interface StatusColorsMap {
  [status: string]: string
}

export interface CostData {
  totalRuns: number
  totalUsd: number
  totalCredits: number
  totalItems: number
  costPerItem: number
  baselineWeeklyCost: number
  hoursSaved: number
  roiPercentage: number
  creditRateUsd: number
  manualHourlyRate: number
  manualMinutesPerItem: number
}

export interface ScaleData {
  total: number
  uniqueCount: number
  dedupRatio: number
  fastPathCount: number
  fastPathRate: number
}

export interface DashboardData {
  stats: DashboardStats
  statuses: StatusItem[]
  signalDominance?: SignalDominance[]
  signalAlignment?: SignalAlignment[]
  agreements?: AgreementLevel[]
  sourceRates?: SourceRate[]
  categoryRates?: CategoryRate[]
  sourceSystems?: SourceSystems
  sourceMax?: number
  statusColorsMap?: StatusColorsMap
  costData?: CostData | null
  scaleData?: ScaleData
}
