import { useCallback } from 'react'
import { type ColumnDef } from '@tanstack/react-table'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { DataTable, DataTableColumnHeader, NumberCell } from '@/components/data-table'
import { PageHeader } from '@/components/page-header'
import { SectionWrapper } from '@/components/section-wrapper'
import { SectionSkeleton } from '@/components/section-skeleton'
import { useAlgorithms, useAgreement, useSourcePerformance, useMethodAccuracy } from './hooks'
import type { AgreementData, SourcePerformance } from './hooks'

// Column definitions
const agreementColumns: ColumnDef<AgreementData>[] = [
  {
    accessorKey: 'level',
    header: 'Agreement Level',
    enableSorting: false,
  },
  {
    accessorKey: 'count',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Count" />
    ),
    cell: ({ row }) => <NumberCell value={row.getValue('count')} decimals={0} />,
  },
  {
    accessorKey: 'avgConfidence',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Avg Confidence" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgConfidence')} />,
  },
]

const sourcePerformanceColumns: ColumnDef<SourcePerformance>[] = [
  {
    accessorKey: 'source',
    header: 'Source',
    enableSorting: false,
  },
  {
    accessorKey: 'itemCount',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Items" />
    ),
    cell: ({ row }) => <NumberCell value={row.getValue('itemCount')} decimals={0} />,
  },
  {
    accessorKey: 'avgSearch',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Search" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgSearch')} />,
  },
  {
    accessorKey: 'avgCosine',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Cosine" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgCosine')} />,
  },
  {
    accessorKey: 'avgEdit',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Edit" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgEdit')} />,
  },
  {
    accessorKey: 'avgJaccard',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Jaccard" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgJaccard')} />,
  },
  {
    accessorKey: 'avgEnsemble',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Ensemble" />
    ),
    cell: ({ row }) => <ConfidenceBadge value={row.getValue('avgEnsemble')} />,
  },
]

// Inner components that use suspense hooks - must be wrapped in SectionWrapper

function AlgorithmsSection() {
  const { data } = useAlgorithms()
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
      {data.algorithms.map((algo) => (
        <Card key={algo.name} className="p-3">
          <CardHeader className="p-0 pb-2">
            <CardTitle className="text-sm font-medium">{algo.name}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <p className="text-xs text-muted-foreground mb-2">{algo.description}</p>
            <ul className="text-xs text-muted-foreground space-y-1">
              {algo.features.map((feature, idx) => (
                <li key={idx}>• {feature}</li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

function AgreementSection() {
  const { data } = useAgreement()
  return (
    <Card>
      <CardHeader>
        <CardTitle>Agreement Analysis</CardTitle>
        <CardDescription>
          How often do the four primary matchers (Search, Cosine, Edit, Jaccard) agree on the best match?
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.agreement.length > 0 ? (
          <DataTable columns={agreementColumns} data={data.agreement} />
        ) : (
          <p className="text-muted-foreground">No agreement data available. Run the pipeline first.</p>
        )}
      </CardContent>
    </Card>
  )
}

function SourcePerformanceSection() {
  const { data } = useSourcePerformance()
  return (
    <Card>
      <CardHeader>
        <CardTitle>Performance by Source System</CardTitle>
        <CardDescription>
          Average confidence scores for each matching algorithm, grouped by data source.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.sourcePerformance.length > 0 ? (
          <DataTable columns={sourcePerformanceColumns} data={data.sourcePerformance} />
        ) : (
          <p className="text-muted-foreground">No source performance data available.</p>
        )}
      </CardContent>
    </Card>
  )
}

function MethodAccuracySection() {
  const { data } = useMethodAccuracy()
  const accuracy = data.methodAccuracy
  return (
    <Card>
      <CardHeader>
        <CardTitle>Method Accuracy vs Confirmed Matches</CardTitle>
        <CardDescription>
          How accurate is each algorithm compared to human-confirmed matches?
        </CardDescription>
      </CardHeader>
      <CardContent>
        {accuracy.totalConfirmed > 0 ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
            <AccuracyCard
              label="Search"
              accuracyPct={accuracy.searchAccuracyPct}
              correct={accuracy.searchCorrect}
              total={accuracy.totalConfirmed}
            />
            <AccuracyCard
              label="Cosine"
              accuracyPct={accuracy.cosineAccuracyPct}
              correct={accuracy.cosineCorrect}
              total={accuracy.totalConfirmed}
            />
            <AccuracyCard
              label="Edit Distance"
              accuracyPct={accuracy.editAccuracyPct}
              correct={accuracy.editCorrect}
              total={accuracy.totalConfirmed}
            />
            <AccuracyCard
              label="Jaccard"
              accuracyPct={accuracy.jaccardAccuracyPct}
              correct={accuracy.jaccardCorrect}
              total={accuracy.totalConfirmed}
            />
            <AccuracyCard
              label="Ensemble"
              accuracyPct={accuracy.ensembleAccuracyPct}
              correct={accuracy.ensembleCorrect}
              total={accuracy.totalConfirmed}
              highlight
            />
          </div>
        ) : (
          <p className="text-muted-foreground">
            No confirmed matches yet. Confirm matches in the Review tab to see accuracy metrics.
          </p>
        )}
      </CardContent>
    </Card>
  )
}

// Algorithm cards skeleton - special layout
function AlgorithmCardsSkeleton() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
      {[1, 2, 3, 4, 5, 6].map((i) => (
        <SectionSkeleton key={i} title={`Algorithm ${i}`} lines={3} />
      ))}
    </div>
  )
}

// Table skeleton with real title
function TableSkeletonWithTitle({ title, rows = 5 }: { title: string; rows?: number }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {Array.from({ length: rows }).map((_, i) => (
            <Skeleton key={i} className="h-10 w-full" />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

export function Comparison() {
  const algorithmsQuery = useAlgorithms()
  const agreementQuery = useAgreement()
  const sourcePerformanceQuery = useSourcePerformance()
  const methodAccuracyQuery = useMethodAccuracy()

  const isFetching = algorithmsQuery.isFetching || agreementQuery.isFetching || 
    sourcePerformanceQuery.isFetching || methodAccuracyQuery.isFetching

  const refetchAll = useCallback(() => {
    algorithmsQuery.refetch()
    agreementQuery.refetch()
    sourcePerformanceQuery.refetch()
    methodAccuracyQuery.refetch()
  }, [algorithmsQuery, agreementQuery, sourcePerformanceQuery, methodAccuracyQuery])

  return (
    <div className="space-y-6">
      <PageHeader
        title="Algorithm Comparison"
        storageKey="comparison-auto-refresh"
        isFetching={isFetching}
        onRefresh={refetchAll}
      />

      {/* Method Overview Cards */}
      <SectionWrapper
        sectionName="Algorithms"
        fallback={<AlgorithmCardsSkeleton />}
      >
        <AlgorithmsSection />
      </SectionWrapper>

      {/* Agreement Analysis & Performance by Source System - Side by Side */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <SectionWrapper
          sectionName="Agreement Analysis"
          fallback={<TableSkeletonWithTitle title="Agreement Analysis" />}
        >
          <AgreementSection />
        </SectionWrapper>

        <SectionWrapper
          sectionName="Source Performance"
          fallback={<TableSkeletonWithTitle title="Performance by Source System" rows={4} />}
        >
          <SourcePerformanceSection />
        </SectionWrapper>
      </div>

      {/* Method Accuracy vs Confirmed Matches */}
      <SectionWrapper
        sectionName="Method Accuracy"
        fallback={<TableSkeletonWithTitle title="Method Accuracy vs Confirmed Matches" rows={2} />}
      >
        <MethodAccuracySection />
      </SectionWrapper>
    </div>
  )
}

function ConfidenceBadge({ value }: { value: number }) {
  const variant = value > 0.8 ? 'success' : value >= 0.7 ? 'warning' : value >= 0.6 ? 'secondary' : 'destructive'
  return <Badge variant={variant}>{value.toFixed(4)}</Badge>
}

interface AccuracyCardProps {
  label: string
  accuracyPct: number
  correct: number
  total: number
  highlight?: boolean
}

function AccuracyCard({ label, accuracyPct, correct, total, highlight }: AccuracyCardProps) {
  return (
    <div className={`p-4 rounded-lg border ${highlight ? 'bg-primary/10 border-primary' : 'bg-muted/50'}`}>
      <p className="text-xs text-muted-foreground mb-1">{label}</p>
      <p className={`text-2xl font-bold ${highlight ? 'text-primary' : ''}`}>{accuracyPct}%</p>
      <p className="text-xs text-muted-foreground">{correct}/{total} correct</p>
    </div>
  )
}
