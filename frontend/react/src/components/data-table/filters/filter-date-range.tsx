import { Calendar, X } from "lucide-react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

export interface DateRange {
  from: string | undefined
  to: string | undefined
}

export interface DateRangePreset {
  label: string
  value: DateRange
}

export interface FilterDateRangeProps {
  value: DateRange
  onChange: (value: DateRange) => void
  presets?: DateRangePreset[]
  className?: string
}

function getDefaultPresets(): DateRangePreset[] {
  const today = new Date()
  const fmt = (d: Date) => d.toISOString().split("T")[0]

  const daysAgo = (n: number) => {
    const d = new Date(today)
    d.setDate(d.getDate() - n)
    return fmt(d)
  }

  return [
    { label: "Last 7 days", value: { from: daysAgo(7), to: fmt(today) } },
    { label: "Last 30 days", value: { from: daysAgo(30), to: fmt(today) } },
    { label: "Last 90 days", value: { from: daysAgo(90), to: fmt(today) } },
  ]
}

export function FilterDateRange({
  value,
  onChange,
  presets,
  className,
}: FilterDateRangeProps) {
  const resolvedPresets = presets ?? getDefaultPresets()
  const hasValue = value.from != null || value.to != null

  return (
    <div className={cn("flex items-center gap-2", className)}>
      <Calendar className="h-3.5 w-3.5 text-muted-foreground" />
      <Input
        type="date"
        value={value.from ?? ""}
        onChange={(e) =>
          onChange({ ...value, from: e.target.value || undefined })
        }
        className="h-8 w-32"
        aria-label="Start date"
      />
      <span className="text-xs text-muted-foreground">to</span>
      <Input
        type="date"
        value={value.to ?? ""}
        onChange={(e) =>
          onChange({ ...value, to: e.target.value || undefined })
        }
        className="h-8 w-32"
        aria-label="End date"
      />

      {resolvedPresets.length > 0 && (
        <div className="flex items-center gap-1">
          {resolvedPresets.map((preset) => (
            <Button
              key={preset.label}
              variant="ghost"
              size="sm"
              className="h-6 px-2 text-xs"
              onClick={() => onChange(preset.value)}
            >
              {preset.label}
            </Button>
          ))}
        </div>
      )}

      {hasValue && (
        <Button
          variant="ghost"
          size="icon"
          className="h-6 w-6"
          onClick={() => onChange({ from: undefined, to: undefined })}
          aria-label="Clear date range"
        >
          <X className="h-3 w-3" />
        </Button>
      )}
    </div>
  )
}
