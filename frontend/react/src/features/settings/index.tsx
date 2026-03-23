import { useState } from 'react'
import { AlertTriangle, RotateCcw, RefreshCw } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { Slider } from '@/components/ui/slider'
import { Switch } from '@/components/ui/switch'
import { Skeleton } from '@/components/ui/skeleton'
import { Separator } from '@/components/ui/separator'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'
import { PageHeader } from '@/components/page-header'
import { useSettings, useUpdateSettings, useResetPipeline, useReEvaluate, type Settings } from './hooks/use-settings'
import { getErrorMessage } from '@/lib/api'

// Section skeletons
function WeightsSkeleton() {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-6 w-48" />
        <Skeleton className="h-4 w-72 mt-1" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="space-y-2">
              <div className="flex justify-between">
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-4 w-8" />
              </div>
              <Skeleton className="h-2 w-full" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function ThresholdsSkeleton() {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-6 w-36" />
        <Skeleton className="h-4 w-64 mt-1" />
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="space-y-2">
              <div className="flex justify-between">
                <div>
                  <Skeleton className="h-4 w-32" />
                  <Skeleton className="h-3 w-48 mt-1" />
                </div>
                <Skeleton className="h-4 w-10" />
              </div>
              <Skeleton className="h-2 w-full" />
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function PerformanceSkeleton() {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-6 w-44" />
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          {[1, 2].map((i) => (
            <div key={i} className="space-y-2">
              <Skeleton className="h-4 w-20" />
              <Skeleton className="h-10 w-full" />
            </div>
          ))}
        </div>
        <div className="flex items-center justify-between">
          <div>
            <Skeleton className="h-4 w-28" />
            <Skeleton className="h-3 w-48 mt-1" />
          </div>
          <Skeleton className="h-6 w-11" />
        </div>
      </CardContent>
    </Card>
  )
}

function DangerZoneSkeleton() {
  return (
    <Card className="border-destructive">
      <CardHeader>
        <Skeleton className="h-6 w-28" />
        <Skeleton className="h-4 w-52 mt-1" />
      </CardHeader>
      <CardContent className="space-y-4">
        {[1, 2].map((i) => (
          <div key={i} className="flex items-center justify-between">
            <div>
              <Skeleton className="h-4 w-32" />
              <Skeleton className="h-3 w-64 mt-1" />
            </div>
            <Skeleton className="h-9 w-24" />
          </div>
        ))}
      </CardContent>
    </Card>
  )
}

export function Settings() {
  const { data, isLoading, error, refetch, isFetching } = useSettings()
  const updateSettings = useUpdateSettings()
  const resetPipeline = useResetPipeline()
  const reEvaluate = useReEvaluate()

  const [localSettings, setLocalSettings] = useState<Partial<Settings>>({})

  const handleWeightChange = (key: keyof Settings['weights'], value: number) => {
    const newWeights = { ...localSettings.weights, [key]: value }
    setLocalSettings({ ...localSettings, weights: newWeights as Settings['weights'] })
  }

  const handleThresholdChange = (key: keyof Settings['thresholds'], value: number) => {
    const newThresholds = { ...localSettings.thresholds, [key]: value }
    setLocalSettings({ ...localSettings, thresholds: newThresholds as Settings['thresholds'] })
  }

  const handleSave = () => {
    if (Object.keys(localSettings).length > 0) {
      updateSettings.mutate(localSettings, {
        onSuccess: () => setLocalSettings({}),
      })
    }
  }

  const weights = data ? { ...data.weights, ...localSettings.weights } : null
  const thresholds = data ? { ...data.thresholds, ...localSettings.thresholds } : null
  const hasChanges = Object.keys(localSettings).length > 0

  // Always render page structure - sections handle their own loading states
  return (
    <div className="space-y-6">
      {/* Header with refresh button (no auto-refresh for forms) */}
      <PageHeader
        title="Settings"
        storageKey="settings-refresh"
        isFetching={isLoading || isFetching}
        onRefresh={() => refetch()}
        showAutoRefresh={false}
      >
        {hasChanges && (
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => setLocalSettings({})}>
              Cancel
            </Button>
            <Button onClick={handleSave} disabled={updateSettings.isPending}>
              {updateSettings.isPending ? 'Saving...' : 'Save Changes'}
            </Button>
          </div>
        )}
      </PageHeader>

      {/* Error state */}
      {error && (
        <Alert variant="destructive">
          <AlertDescription>
            {getErrorMessage(error)}
          </AlertDescription>
        </Alert>
      )}

      {/* Signal Weights */}
      {isLoading ? (
        <WeightsSkeleton />
      ) : weights && data ? (
        <Card>
          <CardHeader>
            <CardTitle>Primary Signal Weights</CardTitle>
            <CardDescription>
              Adjust the weight of each matching algorithm in the ensemble score
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <WeightSlider
                label="Cortex Search"
                value={weights.cortexSearch}
                onChange={(v) => handleWeightChange('cortexSearch', v)}
              />
              <WeightSlider
                label="Cosine Similarity"
                value={weights.cosine}
                onChange={(v) => handleWeightChange('cosine', v)}
              />
              <WeightSlider
                label="Edit Distance"
                value={weights.editDistance}
                onChange={(v) => handleWeightChange('editDistance', v)}
              />
              <WeightSlider
                label="Jaccard"
                value={weights.jaccard}
                onChange={(v) => handleWeightChange('jaccard', v)}
              />
            </div>
          </CardContent>
        </Card>
      ) : null}

      {/* Thresholds */}
      {isLoading ? (
        <ThresholdsSkeleton />
      ) : thresholds && data ? (
        <Card>
          <CardHeader>
            <CardTitle>Score Thresholds</CardTitle>
            <CardDescription>
              Configure automatic acceptance and rejection thresholds
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <ThresholdSlider
                label="Auto-Accept Threshold"
                value={thresholds.autoAccept}
                onChange={(v) => handleThresholdChange('autoAccept', v)}
                description="Matches above this score are automatically accepted"
              />
              <ThresholdSlider
                label="Reject Threshold"
                value={thresholds.reject}
                onChange={(v) => handleThresholdChange('reject', v)}
                description="Matches below this score are automatically rejected"
              />
              <ThresholdSlider
                label="Review Range (Min)"
                value={thresholds.reviewMin}
                onChange={(v) => handleThresholdChange('reviewMin', v)}
                description="Lower bound for manual review queue"
              />
              <ThresholdSlider
                label="Review Range (Max)"
                value={thresholds.reviewMax}
                onChange={(v) => handleThresholdChange('reviewMax', v)}
                description="Upper bound for manual review queue"
              />
            </div>
          </CardContent>
        </Card>
      ) : null}

      {/* Performance */}
      {isLoading ? (
        <PerformanceSkeleton />
      ) : data ? (
        <Card>
          <CardHeader>
            <CardTitle>Performance Settings</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="batchSize">Batch Size</Label>
                <Input
                  id="batchSize"
                  type="number"
                  value={data.performance.batchSize}
                  readOnly
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="parallelism">Parallelism</Label>
                <Input
                  id="parallelism"
                  type="number"
                  value={data.performance.parallelism}
                  readOnly
                />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <Label>Cache Enabled</Label>
                <p className="text-sm text-muted-foreground">
                  Enable caching for repeated queries
                </p>
              </div>
              <Switch checked={data.performance.cacheEnabled} disabled />
            </div>
          </CardContent>
        </Card>
      ) : null}

      {/* Automation */}
      {isLoading ? (
        <PerformanceSkeleton />
      ) : data ? (
        <Card>
          <CardHeader>
            <CardTitle>Automation Settings</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <Label>Auto-Accept Enabled</Label>
                <p className="text-sm text-muted-foreground">
                  Automatically accept high-confidence matches
                </p>
              </div>
              <Switch checked={data.automation.autoAcceptEnabled} disabled />
            </div>
            <div className="flex items-center justify-between">
              <div>
                <Label>Auto-Reject Enabled</Label>
                <p className="text-sm text-muted-foreground">
                  Automatically reject low-confidence matches
                </p>
              </div>
              <Switch checked={data.automation.autoRejectEnabled} disabled />
            </div>
          </CardContent>
        </Card>
      ) : null}

      <Separator />

      {/* Danger Zone */}
      {isLoading ? (
        <DangerZoneSkeleton />
      ) : (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Danger Zone</CardTitle>
            <CardDescription>
              Irreversible and destructive actions
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Reset Pipeline</p>
                <p className="text-sm text-muted-foreground">
                  Reset the entire matching pipeline. This clears all match results and resets items to PENDING status.
                </p>
              </div>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button variant="outline">
                    <RotateCcw className="h-4 w-4 mr-2" />
                    Reset
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Reset Pipeline?</AlertDialogTitle>
                    <AlertDialogDescription>
                      This will reset ALL match results and cannot be undone. Items will be set back to PENDING status.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={() => resetPipeline.mutate()}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      Reset Pipeline
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>

            <Separator />

            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Re-evaluate All Matches</p>
                <p className="text-sm text-muted-foreground">
                  Recalculate scores for all matches using current settings
                </p>
              </div>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button variant="destructive">
                    <RefreshCw className="h-4 w-4 mr-2" />
                    Re-evaluate
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>
                      <AlertTriangle className="h-5 w-5 inline mr-2 text-destructive" />
                      Re-evaluate All Matches?
                    </AlertDialogTitle>
                    <AlertDialogDescription>
                      This will recalculate scores for all matches. This may change the status of previously reviewed items and will incur additional API costs.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={() => reEvaluate.mutate()}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      Re-evaluate All
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

interface WeightSliderProps {
  label: string
  value: number
  onChange: (value: number) => void
}

function WeightSlider({ label, value, onChange }: WeightSliderProps) {
  return (
    <div className="space-y-2">
      <div className="flex justify-between">
        <Label>{label}</Label>
        <span className="text-sm text-muted-foreground">{value.toFixed(2)}</span>
      </div>
      <Slider
        value={[value]}
        min={0}
        max={1}
        step={0.05}
        onValueChange={([v]) => onChange(v)}
      />
    </div>
  )
}

interface ThresholdSliderProps {
  label: string
  value: number
  onChange: (value: number) => void
  description?: string
}

function ThresholdSlider({ label, value, onChange, description }: ThresholdSliderProps) {
  return (
    <div className="space-y-2">
      <div className="flex justify-between">
        <div>
          <Label>{label}</Label>
          {description && (
            <p className="text-xs text-muted-foreground">{description}</p>
          )}
        </div>
        <span className="text-sm font-medium">{(value * 100).toFixed(0)}%</span>
      </div>
      <Slider
        value={[value]}
        min={0}
        max={1}
        step={0.05}
        onValueChange={([v]) => onChange(v)}
      />
    </div>
  )
}
