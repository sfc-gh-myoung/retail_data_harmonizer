import { useState, useEffect, useCallback, useMemo, Fragment } from 'react'
import {
  type ColumnDef,
  type SortingState,
  type PaginationState,
  type ExpandedState,
  type GroupingState,
  type RowSelectionState,
  type Row,
  flexRender,
  getCoreRowModel,
  getExpandedRowModel,
  getGroupedRowModel,
  useReactTable,
} from '@tanstack/react-table'
import {
  Check,
  X,
  ChevronDown,
  ChevronUp,
  SkipForward,
  ThumbsUp,
  ThumbsDown,
  Search,
  ChevronRight,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Checkbox } from '@/components/ui/checkbox'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Label } from '@/components/ui/label'
import { PageHeader } from '@/components/page-header'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  DataTableColumnHeader,
  DataTablePagination,
  FilterSelect,
} from '@/components/data-table'
import {
  useMatches,
  useBulkAction,
  useUpdateMatch,
  useFilterOptions,
  useSkipMatch,
  useFeedback,
  type MatchFilters,
  type Match,
} from './hooks/use-matches'
import { ConfidenceBadge } from './components/confidence-badge'
import { ScoreBreakdown } from './components/score-breakdown'
import { AlternativesModal } from './components/alternatives-modal'

// Section skeletons
function FilterBarSkeleton() {
  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex flex-wrap gap-3 items-end">
          <Skeleton className="h-4 w-12" />
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div key={i} className="space-y-1">
              <Skeleton className="h-3 w-16" />
              <Skeleton className="h-9 w-32" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function ReviewTableSkeleton() {
  return (
    <Card>
      <CardContent className="p-0">
        <div className="border rounded-md">
          <div className="p-2 border-b bg-muted/50">
            <div className="flex gap-4">
              {[1, 2, 3, 4, 5, 6, 7].map((i) => (
                <Skeleton key={i} className="h-4 w-20" />
              ))}
            </div>
          </div>
          <div className="divide-y">
            {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
              <div key={i} className="p-3 flex gap-4 items-center">
                <Skeleton className="h-4 w-4" />
                <Skeleton className="h-4 w-48" />
                <Skeleton className="h-4 w-16" />
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-4 w-32" />
                <Skeleton className="h-5 w-14" />
                <Skeleton className="h-5 w-14" />
              </div>
            ))}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

const statusOptions = [
  { value: 'PENDING_REVIEW', label: 'Pending Review' },
  { value: 'AUTO_ACCEPTED', label: 'Auto Accepted' },
  { value: 'CONFIRMED', label: 'Confirmed' },
  { value: 'REJECTED', label: 'Rejected' },
]

const statusVariants: Record<string, 'default' | 'secondary' | 'success' | 'warning' | 'destructive'> = {
  PENDING_REVIEW: 'warning',
  AUTO_ACCEPTED: 'success',
  CONFIRMED: 'default',
  REJECTED: 'destructive',
  PENDING: 'secondary',
}

const groupByFieldMap: Record<string, { field: keyof Match; format: (value: unknown) => string }> = {
  source_system: {
    field: 'source',
    format: (v) => String(v || 'Unknown'),
  },
  category: {
    field: 'category',
    format: (v) => String(v || 'Uncategorized'),
  },
  match_source: {
    field: 'matchSource',
    format: (v) => String(v || 'Unknown'),
  },

  agreement: {
    field: 'agreementLevel',
    format: (v) => {
      const level = Number(v) || 0
      if (level >= 4) return '4+ Way Agreement'
      if (level === 3) return '3-Way Agreement'
      if (level === 2) return '2-Way Agreement'
      return 'Single Method'
    },
  },
}

// ── Column definitions ──────────────────────────────────────────────────

function useMatchColumns() {
  return useMemo<ColumnDef<Match>[]>(() => [
    {
      id: 'select',
      header: ({ table }) => (
        <Checkbox
          checked={
            table.getIsAllPageRowsSelected() ||
            (table.getIsSomePageRowsSelected() && 'indeterminate')
          }
          onCheckedChange={(value: boolean) =>
            table.toggleAllPageRowsSelected(!!value)
          }
          aria-label="Select all"
        />
      ),
      cell: ({ row }) => {
        const isActionable =
          row.original.status === 'PENDING_REVIEW' ||
          row.original.status === 'PENDING'
        if (!isActionable) return null
        return (
          <Checkbox
            checked={row.getIsSelected()}
            onCheckedChange={(value: boolean) => row.toggleSelected(!!value)}
            aria-label="Select row"
            onClick={(e) => e.stopPropagation()}
          />
        )
      },
      enableSorting: false,
      enableHiding: false,
      size: 40,
    },
    {
      accessorKey: 'rawName',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="POS Item" />
      ),
      cell: ({ row }) => (
        <div className="flex items-center gap-2 min-w-[200px]">
          <span className="truncate font-medium" title={row.original.rawName}>
            {row.original.rawName}
          </span>
          {row.original.duplicateCount > 1 && (
            <Badge variant="secondary" className="text-xs shrink-0">
              {row.original.duplicateCount} items
            </Badge>
          )}
        </div>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'source',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Source" />
      ),
      cell: ({ getValue }) => (
        <span className="text-xs text-muted-foreground">
          {getValue<string>()}
        </span>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'category',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Category" />
      ),
      cell: ({ getValue }) => (
        <span className="text-xs">{getValue<string>() || '\u2014'}</span>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'subcategory',
      header: 'Subcat',
      cell: ({ getValue }) => (
        <span className="text-xs text-muted-foreground">
          {getValue<string>() || '\u2014'}
        </span>
      ),
      enableSorting: false,
    },
    {
      accessorKey: 'matchedName',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Matched Product" />
      ),
      cell: ({ row }) => (
        <div className="max-w-[250px]">
          {row.original.matchedName ? (
            <span className="truncate block" title={row.original.matchedName}>
              {row.original.matchedName}
            </span>
          ) : row.original.status === 'PENDING' ? (
            <span className="text-muted-foreground italic">Processing...</span>
          ) : (
            '\u2014'
          )}
        </div>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'maxRawScore',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Match" className="text-right" />
      ),
      cell: ({ getValue }) => (
        <div className="text-right">
          <ConfidenceBadge score={getValue<number>()} />
        </div>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'ensembleScore',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Ensemble" className="text-right" />
      ),
      cell: ({ getValue }) => (
        <div className="text-right">
          <ConfidenceBadge score={getValue<number>()} />
        </div>
      ),
      enableSorting: true,
    },
    {
      accessorKey: 'matchSource',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Match Src" />
      ),
      cell: ({ getValue }) => {
        const value = getValue<string>()
        return (
          <Badge
            variant={
              value === 'SEARCH' ? 'default' :
              value === 'COSINE' ? 'secondary' :
              value === 'EDIT' ? 'warning' :
              'outline'
            }
            className="text-xs"
          >
            {value}
          </Badge>
        )
      },
      enableSorting: true,
    },
    {
      accessorKey: 'agreementLevel',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Agreement" />
      ),
      cell: ({ row }) => {
        const level = row.original.agreementLevel
        const pct = row.original.boostPercent
        if (level < 2) {
          return <span className="text-xs text-muted-foreground">{'\u2014'}</span>
        }
        return (
          <Badge
            variant={level >= 4 ? 'success' : level >= 3 ? 'secondary' : 'outline'}
            className="text-xs"
          >
            {level}-way: {pct}%
          </Badge>
        )
      },
      enableSorting: true,
    },
    {
      id: 'expand',
      header: '',
      cell: ({ row }) => (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 w-7 p-0"
          onClick={(e) => {
            e.stopPropagation()
            row.toggleExpanded()
          }}
        >
          {row.getIsExpanded() ? (
            <ChevronUp className="h-4 w-4" />
          ) : (
            <ChevronDown className="h-4 w-4" />
          )}
        </Button>
      ),
      enableSorting: false,
      enableHiding: false,
      size: 40,
    },
  ], [])
}

// ── Expanded row detail ─────────────────────────────────────────────────

interface ExpandedRowDetailProps {
  match: Match
  colSpan: number
  onUpdateStatus: (match: Match, status: string) => void
  onSkip: (itemId: string, matchId: string) => void
  onFeedback: (matchId: string, itemId: string, type: 'up' | 'down') => void
  onShowAlternatives: (match: Match) => void
  isUpdating: boolean
}

function ExpandedRowDetail({
  match,
  colSpan,
  onUpdateStatus,
  onSkip,
  onFeedback,
  onShowAlternatives,
  isUpdating,
}: ExpandedRowDetailProps) {
  const isActionable = match.status === 'PENDING_REVIEW' || match.status === 'PENDING'

  return (
    <TableRow className="bg-muted/20 hover:bg-muted/20">
      <TableCell colSpan={colSpan} className="p-0">
        <div className="p-4 space-y-4">
          {/* Match Details */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Left: Item Info */}
            <div className="space-y-3">
              <h4 className="text-sm font-medium">Match Details</h4>
              <div className="space-y-2 text-sm">
                <div>
                  <span className="text-muted-foreground">Best Match: </span>
                  <span className="font-medium">{match.matchedName || '\u2014'}</span>
                  {match.brand && (
                    <span className="text-muted-foreground"> &mdash; {match.brand}</span>
                  )}
                  {match.price > 0 && (
                    <span className="text-muted-foreground">
                      {' '}
                      (${match.price.toFixed(2)})
                    </span>
                  )}
                </div>
                {match.standardItemId && (
                  <div>
                    <span className="text-muted-foreground">Standard Item ID: </span>
                    <code className="text-xs bg-muted px-1.5 py-0.5 rounded">
                      {match.standardItemId}
                    </code>
                  </div>
                )}
                <div>
                  <span className="text-muted-foreground">Status: </span>
                  <Badge variant={statusVariants[match.status] || 'secondary'}>
                    {match.status.replace('_', ' ')}
                  </Badge>
                </div>
              </div>
            </div>

            {/* Right: Score Breakdown */}
            <ScoreBreakdown
              searchScore={match.searchScore}
              cosineScore={match.cosineScore}
              editScore={match.editScore}
              jaccardScore={match.jaccardScore}
              ensembleScore={match.ensembleScore}
              agreementLevel={match.agreementLevel}
              boostPercent={match.boostPercent}
            />
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-2 pt-2 border-t">
            <Button
              size="sm"
              onClick={() => onUpdateStatus(match, 'CONFIRMED')}
              disabled={isUpdating || match.status === 'CONFIRMED'}
            >
              <Check className="h-4 w-4 mr-1" /> Confirm
            </Button>
            <Button
              size="sm"
              variant="destructive"
              onClick={() => onUpdateStatus(match, 'REJECTED')}
              disabled={isUpdating || match.status === 'REJECTED'}
            >
              <X className="h-4 w-4 mr-1" /> Reject
            </Button>
            {isActionable && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => onSkip(match.itemId, match.matchId)}
              >
                <SkipForward className="h-4 w-4 mr-1" /> Skip
              </Button>
            )}

            <div className="border-l pl-3 ml-auto flex items-center gap-1">
              <span className="text-xs text-muted-foreground mr-1">Feedback:</span>
              <Button
                size="sm"
                variant="ghost"
                className="h-7 w-7 p-0"
                onClick={() => onFeedback(match.matchId, match.itemId, 'up')}
                title="Thumbs up"
              >
                <ThumbsUp className="h-4 w-4" />
              </Button>
              <Button
                size="sm"
                variant="ghost"
                className="h-7 w-7 p-0"
                onClick={() => onFeedback(match.matchId, match.itemId, 'down')}
                title="Thumbs down"
              >
                <ThumbsDown className="h-4 w-4" />
              </Button>
            </div>

            <Button
              size="sm"
              variant="outline"
              onClick={() => onShowAlternatives(match)}
            >
              <Search className="h-4 w-4 mr-1" /> Show Alternatives
            </Button>
          </div>
        </div>
      </TableCell>
    </TableRow>
  )
}

// ── Grouping header row ─────────────────────────────────────────────────

interface GroupHeaderRowProps {
  groupName: string
  count: number
  isExpanded: boolean
  onToggle: () => void
  colSpan: number
}

function GroupHeaderRow({ groupName, count, isExpanded, onToggle, colSpan }: GroupHeaderRowProps) {
  return (
    <TableRow
      className="cursor-pointer bg-muted/50 hover:bg-muted/70"
      onClick={onToggle}
    >
      <TableCell colSpan={colSpan} className="py-2">
        <div className="flex items-center gap-3">
          <span className="text-muted-foreground">
            {isExpanded ? (
              <ChevronDown className="h-4 w-4" />
            ) : (
              <ChevronRight className="h-4 w-4" />
            )}
          </span>
          <span className="font-medium">{groupName}</span>
          <Badge variant="secondary" className="ml-auto">
            {count} {count === 1 ? 'item' : 'items'}
          </Badge>
        </div>
      </TableCell>
    </TableRow>
  )
}

// ── Main Review component ───────────────────────────────────────────────

export function Review() {
  // Server-side filters passed to the API
  const [filters, setFilters] = useState<MatchFilters>({
    page: 1,
    pageSize: 25,
    sortBy: 'ensembleScore',
    sortOrder: 'desc',
    groupBy: 'unique_description',
    status: 'PENDING_REVIEW',
  })

  const [alternativesFor, setAlternativesFor] = useState<Match | null>(null)
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set())

  // TanStack Table state
  const [sorting, setSorting] = useState<SortingState>([
    { id: 'ensembleScore', desc: true },
  ])
  const [pagination, setPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize: 25,
  })
  const [expanded, setExpanded] = useState<ExpandedState>({})
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({})
  const [grouping] = useState<GroupingState>([])

  // Data hooks
  const { data, isLoading, error, refetch, isFetching } = useMatches(filters)
  const { data: filterOptions } = useFilterOptions()
  const bulkAction = useBulkAction()
  const updateMatch = useUpdateMatch()
  const skipMatch = useSkipMatch()
  const feedback = useFeedback()

  const isGroupingActive = filters.groupBy !== undefined &&
    filters.groupBy !== 'none' &&
    filters.groupBy !== 'unique_description'

  // Sync TanStack sorting state -> server-side filters
  useEffect(() => {
    if (sorting.length > 0) {
      const { id, desc } = sorting[0]
      setFilters((prev) => ({
        ...prev,
        sortBy: id,
        sortOrder: desc ? 'desc' : 'asc',
        page: 1,
      }))
      setPagination((prev) => ({ ...prev, pageIndex: 0 }))
    }
  }, [sorting])

  // Sync TanStack pagination state -> server-side filters
  useEffect(() => {
    setFilters((prev) => ({
      ...prev,
      page: pagination.pageIndex + 1,
      pageSize: pagination.pageSize,
    }))
  }, [pagination])

  // Compute grouped data when grouping is active
  const groupedData = useMemo(() => {
    if (!isGroupingActive || !data?.items) return null
    const config = groupByFieldMap[filters.groupBy!]
    if (!config) return null

    const groups = new Map<string, Match[]>()
    for (const item of data.items) {
      const rawValue = item[config.field]
      const groupName = config.format(rawValue)
      const existing = groups.get(groupName) || []
      existing.push(item)
      groups.set(groupName, existing)
    }

    return Array.from(groups.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, items]) => ({ name, items }))
  }, [isGroupingActive, data?.items, filters.groupBy])

  const toggleGroup = useCallback((groupName: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev)
      if (next.has(groupName)) {
        next.delete(groupName)
      } else {
        next.add(groupName)
      }
      return next
    })
  }, [])

  const handleFilterChange = useCallback((key: keyof MatchFilters, value: string | undefined) => {
    setFilters((prev) => {
      const updates: Partial<MatchFilters> = {
        [key]: value,
        page: 1,
      }
      if (key === 'category') {
        updates.subcategory = undefined
      }
      return { ...prev, ...updates }
    })
    setPagination((prev) => ({ ...prev, pageIndex: 0 }))
    if (key === 'groupBy') {
      setCollapsedGroups(new Set())
    }
  }, [])

  // Bulk actions using TanStack row selection
  const selectedIds = useMemo(() => {
    if (!data?.items) return []
    return Object.keys(rowSelection)
      .filter((key) => rowSelection[key])
      .map((key) => {
        const idx = parseInt(key, 10)
        return data.items[idx]?.id
      })
      .filter(Boolean) as string[]
  }, [rowSelection, data?.items])

  const handleBulkAction = useCallback(
    (action: 'accept' | 'reject') => {
      if (selectedIds.length > 0) {
        bulkAction.mutate(
          { action, ids: selectedIds },
          { onSuccess: () => setRowSelection({}) }
        )
      }
    },
    [selectedIds, bulkAction]
  )

  // Action callbacks
  const handleUpdateStatus = useCallback(
    (match: Match, status: string) => {
      // When grouping by unique_description, update all related items with same normalized description
      const updateRelated = filters.groupBy === 'unique_description'
      updateMatch.mutate({
        id: match.id,
        status,
        rawName: match.rawName,
        updateRelated,
      })
    },
    [updateMatch, filters.groupBy]
  )

  const handleSkip = useCallback(
    (itemId: string, matchId: string) => skipMatch.mutate({ itemId, matchId }),
    [skipMatch]
  )

  const handleFeedback = useCallback(
    (matchId: string, itemId: string, type: 'up' | 'down') =>
      feedback.mutate({ matchId, itemId, feedback: type }),
    [feedback]
  )

  // Column definitions
  const columns = useMatchColumns()

  // Row can be selected only if actionable
  const enableRowSelection = useCallback(
    (row: Row<Match>) =>
      row.original.status === 'PENDING_REVIEW' || row.original.status === 'PENDING',
    []
  )

  // eslint-disable-next-line react-hooks/incompatible-library -- standard TanStack Table usage
  const table = useReactTable({
    data: data?.items ?? [],
    columns,
    pageCount: data?.totalPages ?? -1,
    state: {
      sorting,
      pagination,
      expanded,
      rowSelection,
      grouping,
    },
    onSortingChange: setSorting,
    onPaginationChange: setPagination,
    onExpandedChange: setExpanded,
    onRowSelectionChange: setRowSelection,
    enableRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getExpandedRowModel: getExpandedRowModel(),
    getGroupedRowModel: getGroupedRowModel(),
    manualPagination: true,
    manualSorting: true,
  })

  const startItem = data ? (data.page - 1) * data.pageSize + 1 : 0
  const endItem = data ? Math.min(data.page * data.pageSize, data.total) : 0
  const colCount = columns.length

  // Always render page structure - sections handle their own loading states
  return (
    <div className="space-y-4">
      {/* Header with auto-refresh toggle and refresh button */}
      <PageHeader
        title="Review Matches"
        storageKey="review-auto-refresh"
        isFetching={isLoading || isFetching}
        onRefresh={() => refetch()}
      />

      {/* Error state */}
      {error && (
        <Alert variant="destructive">
          <AlertDescription>Failed to load matches: {error.message}</AlertDescription>
        </Alert>
      )}

      {/* Filter Bar */}
      {isLoading ? (
        <FilterBarSkeleton />
      ) : (
        <Card>
        <CardContent className="p-4">
          <div className="flex flex-wrap gap-3 items-end">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
              Filters
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Status</Label>
              <FilterSelect
                value={filters.status}
                onChange={(v) => handleFilterChange('status', v)}
                options={statusOptions}
                placeholder="All Statuses"
              />
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Source System</Label>
              <FilterSelect
                value={filters.source}
                onChange={(v) => handleFilterChange('source', v)}
                options={
                  filterOptions?.sources.map((s) => ({ value: s, label: s })) ?? []
                }
                placeholder="All Sources"
              />
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Category</Label>
              <FilterSelect
                value={filters.category}
                onChange={(v) => handleFilterChange('category', v)}
                options={
                  filterOptions?.categories.map((c) => ({ value: c, label: c })) ?? []
                }
                placeholder="All Categories"
              />
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Sub Category</Label>
              <FilterSelect
                value={filters.subcategory}
                onChange={(v) => handleFilterChange('subcategory', v)}
                options={
                  (filters.category && filterOptions?.subcategoriesByCategory?.[filters.category]
                    ? filterOptions.subcategoriesByCategory[filters.category].map((s) => ({ value: s, label: s }))
                    : []
                  )
                }
                placeholder={filters.category ? 'All Sub Categories' : 'Select Category First'}
                disabled={!filters.category}
              />
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Match Source</Label>
              <FilterSelect
                value={filters.matchSource}
                onChange={(v) => handleFilterChange('matchSource', v)}
                options={
                  filterOptions?.matchSources.map((s) => ({ value: s, label: s })) ?? []
                }
                placeholder="All Sources"
              />
            </div>

            <div className="space-y-1">
              <Label className="text-xs">Agreement</Label>
              <FilterSelect
                value={filters.agreement}
                onChange={(v) => handleFilterChange('agreement', v)}
                options={filterOptions?.agreementLevels ?? []}
                placeholder="All Levels"
              />
            </div>

            <div className="border-l pl-3 ml-2 space-y-1">
              <Label className="text-xs">Group By</Label>
              <FilterSelect
                value={filters.groupBy}
                onChange={(v) => handleFilterChange('groupBy', v ?? 'unique_description')}
                options={filterOptions?.groupByOptions ?? []}
                placeholder="Grouping"
              />
            </div>

            {/* Bulk Actions */}
            {selectedIds.length > 0 && (
              <div className="flex items-center gap-2 ml-auto border-l pl-4">
                <span className="text-sm text-muted-foreground">
                  {selectedIds.length} selected
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleBulkAction('accept')}
                  disabled={bulkAction.isPending}
                  className="h-8"
                >
                  <Check className="h-3 w-3 mr-1" />
                  Confirm
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleBulkAction('reject')}
                  disabled={bulkAction.isPending}
                  className="h-8"
                >
                  <X className="h-3 w-3 mr-1" />
                  Reject
                </Button>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
      )}

      {/* Pagination Header */}
      {data && (
        <div className="flex items-center justify-between text-sm text-muted-foreground">
          <span>
            Showing <strong>{startItem}-{endItem}</strong> of{' '}
            <strong>{data.total}</strong> items
          </span>
        </div>
      )}

      {/* Matches Table */}
      {isLoading ? (
        <ReviewTableSkeleton />
      ) : isGroupingActive && groupedData ? (
        /* Grouped View */
        <div className="space-y-2">
          {groupedData.length === 0 ? (
            <Card>
              <CardContent className="py-12 text-center text-muted-foreground">
                No items to display
              </CardContent>
            </Card>
          ) : (
            groupedData.map((group) => {
              const isOpen = !collapsedGroups.has(group.name)
              return (
                <Card key={group.name} className="overflow-hidden">
                  <div className="overflow-x-auto">
                    <Table>
                      <TableBody>
                        <GroupHeaderRow
                          groupName={group.name}
                          count={group.items.length}
                          isExpanded={isOpen}
                          onToggle={() => toggleGroup(group.name)}
                          colSpan={colCount}
                        />
                        {isOpen && (
                          <>
                            {/* Column headers for group */}
                            <TableRow>
                              {table.getHeaderGroups()[0]?.headers.map((header) => (
                                <TableHead key={header.id} colSpan={header.colSpan}>
                                  {header.isPlaceholder
                                    ? null
                                    : flexRender(
                                        header.column.columnDef.header,
                                        header.getContext()
                                      )}
                                </TableHead>
                              ))}
                            </TableRow>
                            {group.items.map((match) => {
                              // Find the corresponding row from the table model
                              const row = table
                                .getRowModel()
                                .rows.find((r) => r.original.id === match.id)
                              if (!row) return null
                              return (
                                <Fragment key={match.id}>
                                  <TableRow
                                    className={`cursor-pointer hover:bg-muted/50 ${
                                      row.getIsExpanded() ? 'bg-muted/30' : ''
                                    }`}
                                    data-state={row.getIsSelected() && 'selected'}
                                    onClick={() => row.toggleExpanded()}
                                  >
                                    {row.getVisibleCells().map((cell) => (
                                      <TableCell key={cell.id}>
                                        {flexRender(
                                          cell.column.columnDef.cell,
                                          cell.getContext()
                                        )}
                                      </TableCell>
                                    ))}
                                  </TableRow>
                                  {row.getIsExpanded() && (
                                    <ExpandedRowDetail
                                      match={match}
                                      colSpan={colCount}
                                      onUpdateStatus={handleUpdateStatus}
                                      onSkip={handleSkip}
                                      onFeedback={handleFeedback}
                                      onShowAlternatives={setAlternativesFor}
                                      isUpdating={updateMatch.isPending}
                                    />
                                  )}
                                </Fragment>
                              )
                            })}
                          </>
                        )}
                      </TableBody>
                    </Table>
                  </div>
                </Card>
              )
            })
          )}
        </div>
      ) : (
        /* Flat Table View */
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  {table.getHeaderGroups().map((headerGroup) => (
                    <TableRow key={headerGroup.id}>
                      {headerGroup.headers.map((header) => (
                        <TableHead key={header.id} colSpan={header.colSpan}>
                          {header.isPlaceholder
                            ? null
                            : flexRender(
                                header.column.columnDef.header,
                                header.getContext()
                              )}
                        </TableHead>
                      ))}
                    </TableRow>
                  ))}
                </TableHeader>
                <TableBody>
                  {table.getRowModel().rows?.length ? (
                    table.getRowModel().rows.map((row) => (
                      <Fragment key={row.id}>
                        <TableRow
                          className={`cursor-pointer hover:bg-muted/50 ${
                            row.getIsExpanded() ? 'bg-muted/30' : ''
                          }`}
                          data-state={row.getIsSelected() && 'selected'}
                          onClick={() => row.toggleExpanded()}
                        >
                          {row.getVisibleCells().map((cell) => (
                            <TableCell key={cell.id}>
                              {flexRender(
                                cell.column.columnDef.cell,
                                cell.getContext()
                              )}
                            </TableCell>
                          ))}
                        </TableRow>
                        {row.getIsExpanded() && (
                          <ExpandedRowDetail
                            match={row.original}
                            colSpan={colCount}
                            onUpdateStatus={handleUpdateStatus}
                            onSkip={handleSkip}
                            onFeedback={handleFeedback}
                            onShowAlternatives={setAlternativesFor}
                            isUpdating={updateMatch.isPending}
                          />
                        )}
                      </Fragment>
                    ))
                  ) : (
                    <TableRow>
                      <TableCell colSpan={colCount} className="h-24 text-center">
                        No results.
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </div>
          </CardContent>

          {/* Pagination */}
          {data && data.totalPages > 1 && (
            <CardContent className="border-t py-3">
              <DataTablePagination table={table} pageSizeOptions={[10, 25, 50, 100]} />
            </CardContent>
          )}
        </Card>
      )}

      {/* Alternatives Modal */}
      <AlternativesModal
        itemId={alternativesFor?.itemId ?? null}
        matchId={alternativesFor?.matchId ?? ''}
        rawDescription={alternativesFor?.rawName ?? ''}
        onClose={() => setAlternativesFor(null)}
      />
    </div>
  )
}
