import { useCallback } from 'react'
import { useIsFetching, useQueryClient } from '@tanstack/react-query'
import { Skeleton } from '@/components/ui/skeleton'
import { PageHeader } from '@/components/page-header'
import { SectionWrapper } from '@/components/section-wrapper'
import { useKpis, useSources, useCategories, useSignals, useCost } from './hooks'
import { KpiCard } from './components/kpi-card'
import { BarChart } from './components/bar-chart'
import { SourceStatusChart } from './components/source-status-chart'
import { CostRoiSection } from './components/cost-roi-section'
import { ScaleProjection } from './components/scale-projection'
import { SectionGroup, SectionCard } from './components/section-group'

/**
 * Pipeline Dashboard with modular architecture.
 *
 * Each section fetches its own data with independent refresh intervals:
 * - KPIs: 10s
 * - Sources: 30s
 * - Categories: 30s
 * - Signals: 30s
 * - Cost: 60s
 *
 * Sections are wrapped in SectionWrapper for error isolation -
 * if one section fails, others continue working.
 *
 * IMPORTANT: Hooks using useSuspenseQuery must only be called inside
 * SectionWrapper children (within Suspense boundaries), not at this level.
 * This allows each section to show its skeleton independently while loading.
 */
export function Dashboard() {
  const queryClient = useQueryClient()
  // useIsFetching returns count of fetching queries - doesn't suspend
  const isFetching = useIsFetching({ queryKey: ['dashboard'] }) > 0

  const refetchAll = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }, [queryClient])

  return (
    <div className="space-y-4">
      {/* Header with auto-refresh toggle and refresh button */}
      <PageHeader
        title="Pipeline Dashboard"
        storageKey="dashboard-auto-refresh"
        isFetching={isFetching}
        onRefresh={refetchAll}
      />

      {/* KPIs Section */}
      <SectionWrapper sectionName="KPIs" fallback={<KpisSkeleton />}>
        <KpisSection />
      </SectionWrapper>

      {/* Match Analysis Group */}
      <SectionWrapper sectionName="Match Analysis" fallback={<ChartsSkeleton />}>
        <MatchAnalysisSection />
      </SectionWrapper>

      {/* Source Analysis Group */}
      <SectionWrapper sectionName="Source Analysis" fallback={<ChartsSkeleton />}>
        <SourceAnalysisSection />
      </SectionWrapper>

      {/* Business Metrics Group */}
      <SectionWrapper sectionName="Business Metrics" fallback={<ChartsSkeleton />}>
        <BusinessMetricsSection />
      </SectionWrapper>
    </div>
  )
}

// ============================================================================
// Section Components - each fetches its own data
// ============================================================================

function KpisSection() {
  const { data } = useKpis()

  // useSuspenseQuery guarantees data is available after Suspense resolves
  return (
    <>
      {/* Primary KPI Cards - Row 1 */}
      <div className="grid grid-cols-3 gap-4">
        <KpiCard title="Total Raw" value={data.stats.totalRaw} variant="primary" />
        <KpiCard title="Total Unique" value={data.stats.totalUnique} variant="primary" />
        <KpiCard title="Total Processed" value={data.stats.totalProcessed} variant="primary" />
      </div>

      {/* Status Breakdown - Row 2 */}
      <div className="grid grid-cols-6 gap-4 mt-4">
        <KpiCard title="Auto-Accepted" value={data.stats.autoAccepted} variant="success" />
        <KpiCard title="Confirmed" value={data.stats.confirmed} variant="primary" />
        <KpiCard title="Pending Review" value={data.stats.pendingReview} variant="warning" />
        <KpiCard title="Rejected" value={data.stats.rejected} variant="danger" />
        <KpiCard title="Need Categorized" value={data.stats.needsCategorized} variant="warning" />
        <KpiCard title="Match Rate" value={`${data.stats.matchRate}%`} variant="success" />
      </div>
    </>
  )
}

function MatchAnalysisSection() {
  const { data: kpisData } = useKpis()
  const { data: signalsData } = useSignals()

  return (
    <SectionGroup
      title="Match Analysis"
      tooltip="Analysis of matching algorithms and their agreement patterns."
      columns={2}
    >
      {kpisData?.statuses && kpisData.statuses.length > 0 && (
        <SectionCard
          title="Status Distribution"
          tooltip="Breakdown of match outcomes. Auto-Accepted: high-confidence matches (score ≥0.85). Confirmed: manually approved by reviewers. Pending Review: moderate confidence requiring human verification. Rejected: declined matches."
        >
          <BarChart items={kpisData.statuses} maxValue={kpisData.stats.total} />
        </SectionCard>
      )}

      {signalsData?.signalDominance && signalsData.signalDominance.length > 0 && (
        <SectionCard
          title="Primary Signal Dominance"
          tooltip="Shows which matching algorithm produced the highest score for each item."
        >
          <BarChart
            items={signalsData.signalDominance.map((s) => ({
              label: s.method,
              count: s.count,
              color: s.color,
              pct: s.pct,
            }))}
          />
        </SectionCard>
      )}

      {signalsData?.signalAlignment && signalsData.signalAlignment.length > 0 && (
        <SectionCard
          title="Signal-Ensemble Alignment"
          tooltip="Measures how often each algorithm's top pick matches the final ensemble decision."
        >
          <BarChart
            items={signalsData.signalAlignment.map((s) => ({
              label: s.method,
              count: s.count,
              color: s.color,
              pct: s.pct,
            }))}
          />
        </SectionCard>
      )}

      {signalsData?.agreements && signalsData.agreements.length > 0 && (
        <SectionCard
          title="Match Agreement Distribution"
          tooltip="Counts how many algorithms agree on the same top match."
        >
          <BarChart
            items={signalsData.agreements.map((a) => ({
              label: a.level,
              count: a.count,
              color: a.color,
              pct: a.pct,
            }))}
          />
        </SectionCard>
      )}
    </SectionGroup>
  )
}

function SourceAnalysisSection() {
  const { data: kpisData } = useKpis()
  const { data: sourcesData } = useSources()
  const { data: categoriesData } = useCategories()

  return (
    <SectionGroup
      title="Source Analysis"
      tooltip="Performance and match rates broken down by data source and category."
    >
      {sourcesData?.sourceSystems &&
        kpisData?.statusColorsMap &&
        sourcesData?.sourceMax &&
        Object.keys(sourcesData.sourceSystems).length > 0 && (
          <SectionCard
            title="Status by Source System"
            tooltip="Match outcomes segmented by data source (POS, inventory, e-commerce, etc.)."
          >
            <SourceStatusChart
              sourceSystems={sourcesData.sourceSystems}
              sourceMax={sourcesData.sourceMax}
              statusColorsMap={kpisData.statusColorsMap}
            />
          </SectionCard>
        )}

      {sourcesData?.sourceRates && sourcesData.sourceRates.length > 0 && (
        <SectionCard
          title="Match Rate By Source"
          tooltip="Success rate (Auto-Accepted + Confirmed) per source system."
        >
          <BarChart
            items={sourcesData.sourceRates.map((s) => ({
              label: s.source,
              count: s.total,
              color: '#667eea',
              pct: s.rate,
            }))}
            scaleByPct
          />
        </SectionCard>
      )}

      {categoriesData?.categoryRates && categoriesData.categoryRates.length > 0 && (
        <SectionCard title="Match Rate by Category" tooltip="Percentage of items matched within each category.">
          <BarChart
            items={categoriesData.categoryRates.map((c) => ({
              label: c.category,
              count: c.total,
              color: '#29B5E8',
              pct: c.rate,
            }))}
            scaleByPct
          />
        </SectionCard>
      )}
    </SectionGroup>
  )
}

function BusinessMetricsSection() {
  const { data: costData } = useCost()

  return (
    <SectionGroup
      title="Business Metrics"
      tooltip="Cost analysis and scale projections for production deployment."
      columns={2}
    >
      {costData?.costData && (
        <SectionCard
          title="Cost & ROI"
          tooltip="Real-time cost tracking from Snowflake warehouse metering."
        >
          <CostRoiSection costData={costData.costData} />
        </SectionCard>
      )}

      {costData?.scaleData && (
        <SectionCard
          title="Scale Projection"
          tooltip="Extrapolates current demo metrics to production volume (48M items)."
        >
          <ScaleProjection scaleData={costData.scaleData} />
        </SectionCard>
      )}
    </SectionGroup>
  )
}

// ============================================================================
// Skeleton Components
// ============================================================================

function KpisSkeleton() {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-24 rounded-xl" />
        ))}
      </div>
      <div className="grid grid-cols-6 gap-4">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <Skeleton key={i} className="h-20 rounded-xl" />
        ))}
      </div>
    </div>
  )
}

function ChartsSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-48 rounded-xl" />
    </div>
  )
}
