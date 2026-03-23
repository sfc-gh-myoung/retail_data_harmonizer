import { useState } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'
import type { CostData } from '../types'
import { KpiCard } from './kpi-card'

interface CostRoiSectionProps {
  costData: CostData
}

export function CostRoiSection({ costData }: CostRoiSectionProps) {
  const [showBreakdown, setShowBreakdown] = useState(false)

  if (costData.totalRuns === 0) {
    return (
      <div className="p-4 bg-blue-50 dark:bg-blue-950 rounded-lg border border-blue-200 dark:border-blue-800">
        <p className="font-semibold text-blue-900 dark:text-blue-100">No Task DAG executions yet.</p>
        <p className="text-sm text-blue-700 dark:text-blue-300 mt-1">
          Cost & ROI metrics automatically populate from Snowflake Task DAG history and warehouse metering data. 
          Metrics appear after the first batch is processed.
        </p>
      </div>
    )
  }

  const savings = costData.baselineWeeklyCost - costData.totalUsd

  return (
    <div className="space-y-4">
      {/* KPI Cards */}
      <div className="grid grid-cols-4 gap-4">
        <KpiCard 
          title="Total Cost" 
          value={`$${costData.totalUsd.toFixed(2)}`}
          variant="primary"
          subtitle={`${costData.totalCredits.toFixed(2)} credits`}
        />
        <KpiCard 
          title="Cost per Item" 
          value={`$${costData.costPerItem.toFixed(4)}`}
          variant="default"
        />
        <KpiCard 
          title="Hours Saved" 
          value={`${costData.hoursSaved.toFixed(1)}h`}
          variant="success"
          subtitle="vs Manual"
        />
        <KpiCard 
          title="ROI" 
          value={`${costData.roiPercentage.toLocaleString(undefined, { maximumFractionDigits: 0 })}%`}
          variant="accent"
        />
      </div>

      {/* Collapsible Breakdown */}
      <div className="rounded-lg border bg-muted/30">
        <button
          onClick={() => setShowBreakdown(!showBreakdown)}
          className="w-full px-4 py-3 flex items-center gap-2 text-sm font-medium hover:bg-muted/50 transition-colors"
        >
          {showBreakdown ? (
            <ChevronDown className="h-4 w-4" />
          ) : (
            <ChevronRight className="h-4 w-4" />
          )}
          How are these KPIs calculated?
        </button>
        
        {showBreakdown && (
          <div className="px-4 pb-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
              {/* Total Cost Breakdown */}
              <div className="p-3 rounded-lg bg-background border">
                <div className="font-semibold text-sm mb-2">Total Cost</div>
                <div className="text-sm space-y-1">
                  <div className="flex justify-between">
                    <span>Credits Used:</span>
                    <span>{costData.totalCredits.toFixed(4)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Credit Rate:</span>
                    <span>${costData.creditRateUsd.toFixed(2)} / credit</span>
                  </div>
                  <div className="flex justify-between font-bold border-t pt-1 mt-1">
                    <span>Total:</span>
                    <span>${costData.totalUsd.toFixed(2)}</span>
                  </div>
                </div>
              </div>

              {/* Cost per Item Breakdown */}
              <div className="p-3 rounded-lg bg-background border">
                <div className="font-semibold text-sm mb-2">Cost per Item</div>
                <div className="text-sm space-y-1">
                  <div className="flex justify-between">
                    <span>Total USD:</span>
                    <span>${costData.totalUsd.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Items Processed:</span>
                    <span>{costData.totalItems.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between font-bold border-t pt-1 mt-1">
                    <span>Per Item:</span>
                    <span>${costData.costPerItem.toFixed(4)}</span>
                  </div>
                </div>
              </div>

              {/* Hours Saved Breakdown */}
              <div className="p-3 rounded-lg bg-background border">
                <div className="font-semibold text-sm mb-2">Hours Saved</div>
                <div className="text-sm space-y-1">
                  <div className="flex justify-between">
                    <span>Baseline (Manual):</span>
                    <span>${costData.baselineWeeklyCost.toFixed(2)}/wk</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Actual (AI) Cost:</span>
                    <span>${costData.totalUsd.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Manual Rate:</span>
                    <span>${costData.manualHourlyRate.toFixed(2)}/hr</span>
                  </div>
                  <div className="flex justify-between font-bold border-t pt-1 mt-1">
                    <span>Hours Saved:</span>
                    <span>{costData.hoursSaved.toFixed(1)}h</span>
                  </div>
                </div>
              </div>

              {/* ROI Breakdown */}
              <div className="p-3 rounded-lg bg-background border">
                <div className="font-semibold text-sm mb-2">ROI Percentage</div>
                <div className="text-sm space-y-1">
                  <div className="flex justify-between">
                    <span>Savings:</span>
                    <span>${savings.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Investment:</span>
                    <span>${costData.totalUsd.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between font-bold border-t pt-1 mt-1">
                    <span>ROI:</span>
                    <span>{costData.roiPercentage.toFixed(0)}%</span>
                  </div>
                </div>
              </div>
            </div>

            <p className="text-xs text-muted-foreground mt-4">
              <em>
                Note: Credits sourced from WAREHOUSE_METERING_HISTORY. Task runs counted from TASK_HISTORY.
                Baseline assumes {costData.manualMinutesPerItem.toFixed(1)} minutes manual effort per item 
                at ${costData.manualHourlyRate.toFixed(2)}/hr rate. ROI compares AI cost vs equivalent manual labor.
              </em>
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
