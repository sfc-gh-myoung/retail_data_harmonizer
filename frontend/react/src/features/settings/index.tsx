import { useState } from 'react'
import { RotateCcw, Save } from 'lucide-react'
import { toast } from 'sonner'
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
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
import {
  useSettings,
  useResetPipeline,
  useSaveSettings,
  type Settings,
  type SettingsUpdate,
} from './hooks/use-settings'
import { getErrorMessage } from '@/lib/api'

// Strip the non-editable cost section to produce the editable form shape.
function toForm(data: Settings): SettingsUpdate {
  return {
    weights: { ...data.weights },
    thresholds: { ...data.thresholds },
    performance: { ...data.performance },
    automation: { ...data.automation },
  }
}

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
        <Skeleton className="h-2 w-full" />
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
  const resetPipeline = useResetPipeline()
  const saveSettings = useSaveSettings()

  const [form, setForm] = useState<SettingsUpdate | null>(data ? toForm(data) : null)
  const [prevData, setPrevData] = useState(data)
  // Seed local form whenever fresh server data arrives (setState-during-render, no effect needed).
  if (data !== prevData) {
    setPrevData(data)
    if (data) setForm(toForm(data))
  }

  const isDirty =
    !!data && !!form && JSON.stringify(form) !== JSON.stringify(toForm(data))

  const setWeight = (key: keyof SettingsUpdate['weights'], value: number) =>
    setForm((f) => (f ? { ...f, weights: { ...f.weights, [key]: value } } : f))

  const setBand = (lo: number, hi: number) =>
    setForm((f) =>
      f
        ? {
            ...f,
            thresholds: {
              autoAccept: hi,
              reject: lo,
              reviewMin: lo,
              reviewMax: hi,
            },
          }
        : f
    )

  const setPerf = (
    key: keyof SettingsUpdate['performance'],
    value: number | boolean
  ) =>
    setForm((f) =>
      f ? { ...f, performance: { ...f.performance, [key]: value } } : f
    )

  const setAutomation = (
    key: keyof SettingsUpdate['automation'],
    value: number | boolean
  ) =>
    setForm((f) =>
      f ? { ...f, automation: { ...f.automation, [key]: value } } : f
    )

  const handleSave = () => {
    if (!form) return
    saveSettings.mutate(form, {
      onSuccess: () => toast.success('Settings saved'),
      onError: (e) => toast.error(getErrorMessage(e)),
    })
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Settings"
        storageKey="settings-refresh"
        isFetching={isLoading || isFetching}
        onRefresh={() => refetch()}
        showAutoRefresh={false}
      />

      {/* Save bar */}
      <div className="flex items-center justify-end gap-3">
        {isDirty && (
          <span className="text-sm text-muted-foreground">Unsaved changes</span>
        )}
        <Button
          onClick={handleSave}
          disabled={!isDirty || saveSettings.isPending}
        >
          <Save className="h-4 w-4 mr-2" />
          {saveSettings.isPending ? 'Saving…' : 'Save Changes'}
        </Button>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{getErrorMessage(error)}</AlertDescription>
        </Alert>
      )}

      {/* Signal Weights */}
      {isLoading || !form ? (
        <WeightsSkeleton />
      ) : (
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
                value={form.weights.cortexSearch}
                onChange={(v) => setWeight('cortexSearch', v)}
              />
              <WeightSlider
                label="Cosine Similarity"
                value={form.weights.cosine}
                onChange={(v) => setWeight('cosine', v)}
              />
              <WeightSlider
                label="Edit Distance"
                value={form.weights.editDistance}
                onChange={(v) => setWeight('editDistance', v)}
              />
              <WeightSlider
                label="Jaccard"
                value={form.weights.jaccard}
                onChange={(v) => setWeight('jaccard', v)}
              />
            </div>
          </CardContent>
        </Card>
      )}

      {/* Thresholds (derived review band via dual-handle range) */}
      {isLoading || !form ? (
        <ThresholdsSkeleton />
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>Score Thresholds</CardTitle>
            <CardDescription>
              Drag the handles to set the auto-reject and auto-accept boundaries.
              Scores between them go to manual review.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between text-sm">
              <span>
                Auto-Reject &lt;{' '}
                <span className="font-medium">
                  {Math.round(form.thresholds.reject * 100)}%
                </span>
              </span>
              <span className="text-muted-foreground">
                Review {Math.round(form.thresholds.reject * 100)}% –{' '}
                {Math.round(form.thresholds.autoAccept * 100)}%
              </span>
              <span>
                Auto-Accept ≥{' '}
                <span className="font-medium">
                  {Math.round(form.thresholds.autoAccept * 100)}%
                </span>
              </span>
            </div>
            <Slider
              value={[
                Math.round(form.thresholds.reject * 100),
                Math.round(form.thresholds.autoAccept * 100),
              ]}
              min={0}
              max={100}
              step={5}
              minStepsBetweenThumbs={1}
              onValueChange={([lo, hi]) => setBand(lo / 100, hi / 100)}
            />
          </CardContent>
        </Card>
      )}

      {/* Performance */}
      {isLoading || !form ? (
        <PerformanceSkeleton />
      ) : (
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
                  value={form.performance.batchSize}
                  onChange={(e) =>
                    setPerf('batchSize', Number(e.target.value) || 0)
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="parallelism">Parallelism</Label>
                <Input
                  id="parallelism"
                  type="number"
                  value={form.performance.parallelism}
                  onChange={(e) =>
                    setPerf('parallelism', Number(e.target.value) || 0)
                  }
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
              <Switch
                checked={form.performance.cacheEnabled}
                onCheckedChange={(v) => setPerf('cacheEnabled', v)}
              />
            </div>
          </CardContent>
        </Card>
      )}

      {/* Automation */}
      {isLoading || !form ? (
        <PerformanceSkeleton />
      ) : (
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
              <Switch
                checked={form.automation.autoAcceptEnabled}
                onCheckedChange={(v) => setAutomation('autoAcceptEnabled', v)}
              />
            </div>
            <div className="flex items-center justify-between">
              <div>
                <Label>Auto-Reject Enabled</Label>
                <p className="text-sm text-muted-foreground">
                  Automatically reject low-confidence matches
                </p>
              </div>
              <Switch
                checked={form.automation.autoRejectEnabled}
                onCheckedChange={(v) => setAutomation('autoRejectEnabled', v)}
              />
            </div>
            <div className="flex items-center justify-between">
              <div>
                <Label>Min Agreement Level</Label>
                <p className="text-sm text-muted-foreground">
                  Minimum matchers that must agree for auto-decisions
                </p>
              </div>
              <Select
                value={String(form.automation.minAgreementLevel)}
                onValueChange={(v) =>
                  setAutomation('minAgreementLevel', Number(v))
                }
              >
                <SelectTrigger className="w-24">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {[1, 2, 3, 4].map((n) => (
                    <SelectItem key={n} value={String(n)}>
                      {n}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>
      )}

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
