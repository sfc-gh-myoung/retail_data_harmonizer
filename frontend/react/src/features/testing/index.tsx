import { useState, useMemo } from 'react'
import {
  Play,
  RefreshCw,
  ChevronUp,
  ChevronDown,
  AlertCircle,
  CheckCircle2,
  Loader2,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Checkbox } from '@/components/ui/checkbox'
import { Progress } from '@/components/ui/progress'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import {
  useTestingDashboard,
  useFailures,
  useTestRunner,
  type AccuracyByDifficulty,
  type SortColumn,
  type SortDirection,
} from './hooks/use-test-verification'
import { getErrorMessage } from '@/lib/api'

// Section skeletons
function LatestTestRunSkeleton() {
  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <Skeleton className="h-5 w-32" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="text-center p-3 rounded-lg bg-muted/50">
              <Skeleton className="h-3 w-16 mx-auto mb-1" />
              <Skeleton className="h-6 w-12 mx-auto" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function TestSetOverviewSkeleton() {
  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <Skeleton className="h-5 w-36" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="text-center p-3 rounded-lg bg-muted/50 border">
              <Skeleton className="h-3 w-20 mx-auto mb-1" />
              <Skeleton className="h-6 w-14 mx-auto" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function AccuracySummarySkeleton() {
  return (
    <Card>
      <CardHeader className="pb-2">
        <Skeleton className="h-5 w-40" />
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-10 w-full" />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function AccuracyByDifficultySkeleton() {
  return (
    <Card>
      <CardHeader className="pb-2">
        <Skeleton className="h-5 w-52" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="border rounded-lg p-4">
              <Skeleton className="h-5 w-16 mb-3" />
              <div className="space-y-2">
                {[1, 2, 3, 4].map((j) => (
                  <Skeleton key={j} className="h-6 w-full" />
                ))}
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function FailureAnalysisSkeleton() {
  return (
    <Card>
      <CardHeader className="pb-2">
        <Skeleton className="h-5 w-36" />
        <Skeleton className="h-4 w-72 mt-1" />
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Helper Components
// ---------------------------------------------------------------------------

function AccuracyProgressBar({ value, thresholds }: { value: number; thresholds: { good: number; warning: number } }) {
  const colorClass =
    value >= thresholds.good
      ? 'bg-green-500'
      : value >= thresholds.warning
        ? 'bg-yellow-500'
        : 'bg-red-500'

  return (
    <div className="flex items-center gap-2">
      <div className="relative h-2 w-24 overflow-hidden rounded-full bg-muted">
        <div
          className={`h-full transition-all ${colorClass}`}
          style={{ width: `${Math.min(value, 100)}%` }}
        />
      </div>
      <span className="text-sm font-medium w-14 text-right">{value.toFixed(1)}%</span>
    </div>
  )
}

function DifficultyBadge({ difficulty }: { difficulty: string }) {
  const variant =
    difficulty === 'EASY'
      ? 'success'
      : difficulty === 'MEDIUM'
        ? 'warning'
        : 'destructive'

  return <Badge variant={variant}>{difficulty}</Badge>
}

function MethodBadge({ method }: { method: string }) {
  return <Badge variant="default">{method}</Badge>
}

// ---------------------------------------------------------------------------
// Section 1: Latest Test Run
// ---------------------------------------------------------------------------

function LatestTestRun({
  testRun,
}: {
  testRun: {
    runId: string
    timestamp: string | null
    totalTests: number | null
    methodsTested: string | null
  } | null
}) {
  if (!testRun) {
    return (
      <Card className="h-full">
        <CardHeader className="pb-2">
          <CardTitle className="text-lg">Latest Test Run</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            No test runs found. Run accuracy tests to generate results.
          </p>
        </CardContent>
      </Card>
    )
  }

  const methodsCount = testRun.methodsTested
    ? testRun.methodsTested.split(', ').length
    : 0

  const formattedDate = testRun.timestamp
    ? new Date(testRun.timestamp).toLocaleString()
    : 'N/A'

  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <div className="flex items-baseline justify-between gap-2">
          <CardTitle className="text-lg">Latest Test Run</CardTitle>
          <span className="text-xs text-muted-foreground font-mono">{testRun.runId}</span>
        </div>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center p-3 rounded-lg bg-muted/50">
            <div className="text-xs text-muted-foreground mb-1">Timestamp</div>
            <div className="text-base font-bold">{formattedDate}</div>
          </div>
          <div className="text-center p-3 rounded-lg bg-muted/50">
            <div className="text-xs text-muted-foreground mb-1">Total Tests</div>
            <div className="text-xl font-bold">
              {testRun.totalTests?.toLocaleString() ?? 'N/A'}
            </div>
          </div>
          <div className="text-center p-3 rounded-lg bg-muted/50">
            <div className="text-xs text-muted-foreground mb-1">Methods Tested</div>
            <div className="text-xl font-bold">{methodsCount}</div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section 2: Test Set Overview
// ---------------------------------------------------------------------------

function TestSetOverview({
  testStats,
}: {
  testStats: {
    totalCases: number
    easyCount: number
    mediumCount: number
    hardCount: number
    easyPct: number
    mediumPct: number
    hardPct: number
  }
}) {
  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Test Set Overview</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center p-3 rounded-lg bg-green-500/10 border border-green-500/20">
            <div className="text-xs text-muted-foreground mb-1">
              Easy ({testStats.easyPct.toFixed(0)}%)
            </div>
            <div className="text-xl font-bold text-green-600">
              {testStats.easyCount.toLocaleString()}
            </div>
          </div>
          <div className="text-center p-3 rounded-lg bg-yellow-500/10 border border-yellow-500/20">
            <div className="text-xs text-muted-foreground mb-1">
              Medium ({testStats.mediumPct.toFixed(0)}%)
            </div>
            <div className="text-xl font-bold text-yellow-600">
              {testStats.mediumCount.toLocaleString()}
            </div>
          </div>
          <div className="text-center p-3 rounded-lg bg-red-500/10 border border-red-500/20">
            <div className="text-xs text-muted-foreground mb-1">
              Hard ({testStats.hardPct.toFixed(0)}%)
            </div>
            <div className="text-xl font-bold text-red-600">
              {testStats.hardCount.toLocaleString()}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section 3: Accuracy Summary Table
// ---------------------------------------------------------------------------

function AccuracySummaryTable({
  accuracySummary,
}: {
  accuracySummary: Array<{
    method: string
    top1AccuracyPct: number
    top3AccuracyPct: number
    top5AccuracyPct: number
  }>
}) {
  if (accuracySummary.length === 0) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg">Accuracy Summary</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            No accuracy results available. Run tests to generate metrics.
          </p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Accuracy Summary</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Method</TableHead>
              <TableHead>Top-1 Accuracy</TableHead>
              <TableHead>Top-3 Accuracy</TableHead>
              <TableHead>Top-5 Accuracy</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {accuracySummary.map((row) => (
              <TableRow key={row.method}>
                <TableCell className="font-medium">{row.method}</TableCell>
                <TableCell>
                  <AccuracyProgressBar
                    value={row.top1AccuracyPct}
                    thresholds={{ good: 80, warning: 60 }}
                  />
                </TableCell>
                <TableCell>
                  <AccuracyProgressBar
                    value={row.top3AccuracyPct}
                    thresholds={{ good: 90, warning: 75 }}
                  />
                </TableCell>
                <TableCell>
                  <AccuracyProgressBar
                    value={row.top5AccuracyPct}
                    thresholds={{ good: 95, warning: 80 }}
                  />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section 4: Accuracy by Difficulty
// ---------------------------------------------------------------------------

function AccuracyByDifficultySection({
  data,
}: {
  data: AccuracyByDifficulty[]
}) {
  const grouped = useMemo(() => {
    const easy = data
      .filter((r) => r.difficulty === 'EASY')
      .sort((a, b) => b.top1Pct - a.top1Pct)
    const medium = data
      .filter((r) => r.difficulty === 'MEDIUM')
      .sort((a, b) => b.top1Pct - a.top1Pct)
    const hard = data
      .filter((r) => r.difficulty === 'HARD')
      .sort((a, b) => b.top1Pct - a.top1Pct)
    return { easy, medium, hard }
  }, [data])

  if (data.length === 0) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg">Accuracy by Difficulty Level</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            No difficulty breakdown available.
          </p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Accuracy by Difficulty Level</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-3 gap-4">
          {/* EASY Column */}
          <div className="border rounded-lg p-4 border-green-500/30 bg-green-500/5">
            <div className="flex items-center gap-2 mb-3">
              <Badge variant="success">EASY</Badge>
              <span className="text-xs text-muted-foreground">
                {grouped.easy.length} methods
              </span>
            </div>
            <div className="space-y-2">
              {grouped.easy.map((row) => (
                <div
                  key={row.method}
                  className="flex justify-between items-center py-1 border-b last:border-0"
                >
                  <span className="text-sm font-medium">{row.method}</span>
                  <div className="flex items-center gap-2">
                    <Progress value={row.top1Pct} className="w-16 h-1.5 bg-green-200" />
                    <span className="text-sm font-semibold w-12 text-right">
                      {row.top1Pct.toFixed(1)}%
                    </span>
                  </div>
                </div>
              ))}
              {grouped.easy.length === 0 && (
                <p className="text-xs text-muted-foreground">No data</p>
              )}
            </div>
          </div>

          {/* MEDIUM Column */}
          <div className="border rounded-lg p-4 border-yellow-500/30 bg-yellow-500/5">
            <div className="flex items-center gap-2 mb-3">
              <Badge variant="warning">MEDIUM</Badge>
              <span className="text-xs text-muted-foreground">
                {grouped.medium.length} methods
              </span>
            </div>
            <div className="space-y-2">
              {grouped.medium.map((row) => (
                <div
                  key={row.method}
                  className="flex justify-between items-center py-1 border-b last:border-0"
                >
                  <span className="text-sm font-medium">{row.method}</span>
                  <div className="flex items-center gap-2">
                    <Progress value={row.top1Pct} className="w-16 h-1.5 bg-yellow-200" />
                    <span className="text-sm font-semibold w-12 text-right">
                      {row.top1Pct.toFixed(1)}%
                    </span>
                  </div>
                </div>
              ))}
              {grouped.medium.length === 0 && (
                <p className="text-xs text-muted-foreground">No data</p>
              )}
            </div>
          </div>

          {/* HARD Column */}
          <div className="border rounded-lg p-4 border-red-500/30 bg-red-500/5">
            <div className="flex items-center gap-2 mb-3">
              <Badge variant="destructive">HARD</Badge>
              <span className="text-xs text-muted-foreground">
                {grouped.hard.length} methods
              </span>
            </div>
            <div className="space-y-2">
              {grouped.hard.map((row) => (
                <div
                  key={row.method}
                  className="flex justify-between items-center py-1 border-b last:border-0"
                >
                  <span className="text-sm font-medium">{row.method}</span>
                  <div className="flex items-center gap-2">
                    <Progress value={row.top1Pct} className="w-16 h-1.5 bg-red-200" />
                    <span className="text-sm font-semibold w-12 text-right">
                      {row.top1Pct.toFixed(1)}%
                    </span>
                  </div>
                </div>
              ))}
              {grouped.hard.length === 0 && (
                <p className="text-xs text-muted-foreground">No data</p>
              )}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section 5: Failure Analysis
// ---------------------------------------------------------------------------

function SortIndicator({ 
  column, 
  currentSortCol, 
  currentSortDir 
}: { 
  column: SortColumn
  currentSortCol: SortColumn
  currentSortDir: SortDirection 
}) {
  if (currentSortCol !== column) return null
  return currentSortDir === 'ASC' ? (
    <ChevronUp className="h-4 w-4 inline" />
  ) : (
    <ChevronDown className="h-4 w-4 inline" />
  )
}

function FailureAnalysis({ totalFailures }: { totalFailures: number }) {
  const [page, setPage] = useState(1)
  const [pageSize] = useState(10)
  const [sortCol, setSortCol] = useState<SortColumn>('METHOD')
  const [sortDir, setSortDir] = useState<SortDirection>('ASC')
  const [methodFilter, setMethodFilter] = useState('All')
  const [difficultyFilter, setDifficultyFilter] = useState('All')

  const { data, isLoading, error } = useFailures({
    page,
    pageSize,
    sortCol,
    sortDir,
    methodFilter,
    difficultyFilter,
  })

  const handleSort = (column: SortColumn) => {
    if (sortCol === column) {
      setSortDir(sortDir === 'ASC' ? 'DESC' : 'ASC')
    } else {
      setSortCol(column)
      setSortDir('ASC')
    }
    setPage(1)
  }

  if (totalFailures === 0) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg">Failure Analysis</CardTitle>
        </CardHeader>
        <CardContent>
          <Alert>
            <CheckCircle2 className="h-4 w-4" />
            <AlertDescription>
              No failures found - all tests passed!
            </AlertDescription>
          </Alert>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Failure Analysis</CardTitle>
        <p className="text-sm text-muted-foreground">
          Test cases where the algorithm failed to find the correct match in Top-1
        </p>
      </CardHeader>
      <CardContent>
        {/* Filter Bar */}
        <div className="flex flex-wrap gap-4 mb-4 p-3 bg-muted/50 rounded-lg">
          <div className="flex flex-col gap-1">
            <label className="text-xs text-muted-foreground">Method</label>
            <Select
              value={methodFilter}
              onValueChange={(v) => {
                setMethodFilter(v)
                setPage(1)
              }}
            >
              <SelectTrigger className="w-40 h-8">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="All">All Methods</SelectItem>
                {data?.filterOptions.methods.map((m) => (
                  <SelectItem key={m} value={m}>
                    {m}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs text-muted-foreground">Difficulty</label>
            <Select
              value={difficultyFilter}
              onValueChange={(v) => {
                setDifficultyFilter(v)
                setPage(1)
              }}
            >
              <SelectTrigger className="w-32 h-8">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="All">All</SelectItem>
                {data?.filterOptions.difficulties.map((d) => (
                  <SelectItem key={d} value={d}>
                    {d}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-2">
            {[...Array(5)].map((_, i) => (
              <Skeleton key={i} className="h-12 w-full" />
            ))}
          </div>
        ) : error ? (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>Failed to load failures</AlertDescription>
          </Alert>
        ) : (
          <>
            {/* Pagination Info */}
            <div className="flex justify-between items-center mb-2">
              <p className="text-sm text-muted-foreground">
                Showing{' '}
                <strong>
                  {(data?.currentPage ?? 1 - 1) * pageSize + 1}-
                  {Math.min((data?.currentPage ?? 1) * pageSize, data?.totalFailures ?? 0)}
                </strong>{' '}
                of <strong>{data?.totalFailures ?? 0}</strong> failures
              </p>
            </div>

            {/* Table */}
            <div className="border rounded-lg overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead
                      className="cursor-pointer hover:bg-muted/50"
                      onClick={() => handleSort('METHOD')}
                    >
                      Method <SortIndicator column="METHOD" currentSortCol={sortCol} currentSortDir={sortDir} />
                    </TableHead>
                    <TableHead
                      className="cursor-pointer hover:bg-muted/50"
                      onClick={() => handleSort('TEST_INPUT')}
                    >
                      Input <SortIndicator column="TEST_INPUT" currentSortCol={sortCol} currentSortDir={sortDir} />
                    </TableHead>
                    <TableHead>Expected Match</TableHead>
                    <TableHead>Actual Match</TableHead>
                    <TableHead
                      className="cursor-pointer hover:bg-muted/50 text-right"
                      onClick={() => handleSort('SCORE')}
                    >
                      Score <SortIndicator column="SCORE" currentSortCol={sortCol} currentSortDir={sortDir} />
                    </TableHead>
                    <TableHead
                      className="cursor-pointer hover:bg-muted/50"
                      onClick={() => handleSort('DIFFICULTY')}
                    >
                      Difficulty <SortIndicator column="DIFFICULTY" currentSortCol={sortCol} currentSortDir={sortDir} />
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data?.failures.map((row, idx) => (
                    <TableRow key={idx}>
                      <TableCell>
                        <MethodBadge method={row.method} />
                      </TableCell>
                      <TableCell
                        className="max-w-[200px] truncate"
                        title={row.testInput}
                      >
                        {row.testInput}
                      </TableCell>
                      <TableCell
                        className="max-w-[180px] truncate"
                        title={row.expectedMatch}
                      >
                        {row.expectedMatch}
                      </TableCell>
                      <TableCell
                        className="max-w-[180px] truncate"
                        title={row.actualMatch ?? 'No match'}
                      >
                        {row.actualMatch ?? 'No match'}
                      </TableCell>
                      <TableCell className="text-right">
                        {row.score !== null ? row.score.toFixed(3) : 'N/A'}
                      </TableCell>
                      <TableCell>
                        <DifficultyBadge difficulty={row.difficulty} />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* Pagination Controls */}
            {(data?.totalPages ?? 1) > 1 && (
              <div className="flex justify-between items-center mt-4">
                <p className="text-sm text-muted-foreground">
                  Page {data?.currentPage} of {data?.totalPages}
                </p>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={!data?.hasPrev}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => p + 1)}
                    disabled={!data?.hasNext}
                  >
                    Next
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Section 6: Run Accuracy Tests
// ---------------------------------------------------------------------------

const AVAILABLE_METHODS = [
  { id: 'cortex_search', label: 'Include Cortex Search', defaultChecked: true },
  { id: 'cosine', label: 'Include Cosine Similarity', defaultChecked: true },
  { id: 'edit_distance', label: 'Include Edit Distance', defaultChecked: true },
  { id: 'jaccard', label: 'Include Jaccard Similarity', defaultChecked: true },
  { id: 'ensemble', label: 'Include Ensemble', defaultChecked: false },
]

interface RunTestsSectionProps {
  onRefresh: () => void
  startTests: (methods: string[]) => Promise<unknown>
  isStarting: boolean
  isRunning: boolean
  error: Error | null
}

function RunTestsSection({
  onRefresh,
  startTests,
  isStarting,
  isRunning,
  error,
}: RunTestsSectionProps) {
  const [selectedMethods, setSelectedMethods] = useState<Set<string>>(
    new Set(AVAILABLE_METHODS.filter((m) => m.defaultChecked).map((m) => m.id))
  )

  const toggleMethod = (methodId: string) => {
    setSelectedMethods((prev) => {
      const next = new Set(prev)
      if (next.has(methodId)) {
        next.delete(methodId)
      } else {
        next.add(methodId)
      }
      return next
    })
  }

  const handleRunTests = async () => {
    if (selectedMethods.size === 0) return
    await startTests(Array.from(selectedMethods))
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Run Accuracy Tests</CardTitle>
        <p className="text-sm text-muted-foreground">
          Execute accuracy tests against the test set to measure algorithm performance.
        </p>
      </CardHeader>
      <CardContent>
        {/* Method Checkboxes */}
        <div className="flex flex-wrap gap-4 mb-4">
          {AVAILABLE_METHODS.map((method) => (
            <label
              key={method.id}
              className="flex items-center gap-2 cursor-pointer"
            >
              <Checkbox
                checked={selectedMethods.has(method.id)}
                onCheckedChange={() => toggleMethod(method.id)}
                disabled={isStarting || isRunning}
              />
              <span className="text-sm">{method.label}</span>
            </label>
          ))}
        </div>

        {/* Action Buttons */}
        <div className="flex gap-2">
          <Button
            onClick={handleRunTests}
            disabled={selectedMethods.size === 0 || isStarting || isRunning}
            size="sm"
          >
            {isStarting || isRunning ? (
              <>
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                {isStarting ? 'Starting...' : 'Running...'}
              </>
            ) : (
              <>
                <Play className="h-4 w-4 mr-2" />
                Run Tests
              </>
            )}
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={onRefresh}
            disabled={isStarting || isRunning}
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh Results
          </Button>
        </div>

        {/* Status Messages */}
        {isRunning && (
          <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg">
            <div className="flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin text-blue-500" />
              <span className="font-medium text-blue-600">Tests Running</span>
            </div>
            <p className="text-sm text-muted-foreground mt-1">
              Tests are executing in the background. This may take a few minutes.
            </p>
          </div>
        )}

        {error && (
          <Alert variant="destructive" className="mt-4">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              {error instanceof Error ? error.message : 'Test execution failed'}
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Main Component
// ---------------------------------------------------------------------------

export function Testing() {
  const { data, isLoading, error, refetch, isFetching } = useTestingDashboard()
  const {
    startTests,
    cancelAndReset,
    isStarting,
    isCancelling,
    isRunning,
    isStuck,
    runningCount,
    error: testRunnerError,
  } = useTestRunner()

  // Always render page structure - sections handle their own loading states
  return (
    <div className="space-y-4">
      {/* Header with auto-refresh toggle and refresh button */}
      <PageHeader
        title="Test Verification"
        subtitle="Accuracy testing results for matching algorithms"
        storageKey="testing-auto-refresh"
        isFetching={isLoading || isFetching}
        onRefresh={() => refetch()}
      />

      {/* Error state */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            {getErrorMessage(error)}
          </AlertDescription>
        </Alert>
      )}

      {/* Page-level Test Running Banner */}
      {(isRunning || isStarting) && (
        <Alert className={isStuck ? "border-amber-500/50 bg-amber-500/10" : "border-blue-500/50 bg-blue-500/10"}>
          <Loader2 className={`h-4 w-4 animate-spin ${isStuck ? 'text-amber-500' : 'text-blue-500'}`} />
          <AlertDescription className="flex items-center justify-between">
            <div>
              <span className={`font-semibold ${isStuck ? 'text-amber-600' : 'text-blue-600'}`}>
                {isStarting ? 'Starting Tests...' : isStuck ? 'Tests May Be Stuck' : 'Tests Running'}
              </span>
              {runningCount > 0 && (
                <span className="ml-2 text-muted-foreground">
                  ({runningCount} method{runningCount !== 1 ? 's' : ''} in progress)
                </span>
              )}
              <p className="text-sm text-muted-foreground mt-1">
                {isStuck 
                  ? 'Tests have been running for over 15 minutes. You can cancel and restart.'
                  : 'Results shown below may be incomplete until testing finishes.'}
              </p>
            </div>
            <div className="flex items-center gap-2 ml-4">
              {(isRunning || isStuck) && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => cancelAndReset()}
                  disabled={isCancelling}
                  className={isStuck ? "border-amber-500 text-amber-600 hover:bg-amber-50" : ""}
                >
                  {isCancelling ? (
                    <>
                      <Loader2 className="h-3 w-3 mr-1 animate-spin" />
                      Cancelling...
                    </>
                  ) : (
                    'Cancel Tests'
                  )}
                </Button>
              )}
              <Badge variant="secondary">
                <Loader2 className="h-3 w-3 mr-1 animate-spin" />
                {isStuck ? 'Possibly Stuck' : 'In Progress'}
              </Badge>
            </div>
          </AlertDescription>
        </Alert>
      )}

      {/* Section 1 & 2: Latest Test Run + Test Set Overview (side by side) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {isLoading ? (
          <>
            <LatestTestRunSkeleton />
            <TestSetOverviewSkeleton />
          </>
        ) : data ? (
          <>
            <LatestTestRun testRun={data.testRun} />
            <TestSetOverview testStats={data.testStats} />
          </>
        ) : null}
      </div>

      {/* Section 3: Accuracy Summary */}
      {isLoading ? (
        <AccuracySummarySkeleton />
      ) : data ? (
        <AccuracySummaryTable accuracySummary={data.accuracySummary} />
      ) : null}

      {/* Section 4: Accuracy by Difficulty */}
      {isLoading ? (
        <AccuracyByDifficultySkeleton />
      ) : data ? (
        <AccuracyByDifficultySection data={data.accuracyByDifficulty} />
      ) : null}

      {/* Section 5: Failure Analysis */}
      {isLoading ? (
        <FailureAnalysisSkeleton />
      ) : data ? (
        <FailureAnalysis totalFailures={data.totalFailures} />
      ) : null}

      {/* Section 6: Run Accuracy Tests */}
      <RunTestsSection
        onRefresh={() => refetch()}
        startTests={startTests}
        isStarting={isStarting}
        isRunning={isRunning}
        error={testRunnerError}
      />
    </div>
  )
}
