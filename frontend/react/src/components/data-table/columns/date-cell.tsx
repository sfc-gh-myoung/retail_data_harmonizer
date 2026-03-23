const shortFormatter = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
})

const longFormatter = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "long",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
})

const relativeFormatter = new Intl.RelativeTimeFormat(undefined, {
  numeric: "auto",
})

const DIVISIONS: { amount: number; unit: Intl.RelativeTimeFormatUnit }[] = [
  { amount: 60, unit: "seconds" },
  { amount: 60, unit: "minutes" },
  { amount: 24, unit: "hours" },
  { amount: 7, unit: "days" },
  { amount: 4.345, unit: "weeks" },
  { amount: 12, unit: "months" },
  { amount: Number.POSITIVE_INFINITY, unit: "years" },
]

function formatRelative(date: Date): string {
  let diff = (date.getTime() - Date.now()) / 1000

  for (const { amount, unit } of DIVISIONS) {
    if (Math.abs(diff) < amount) {
      return relativeFormatter.format(Math.round(diff), unit)
    }
    diff /= amount
  }

  return shortFormatter.format(date)
}

export interface DateCellProps {
  value: string | Date | null
  format?: "short" | "long" | "relative"
}

export function DateCell({ value, format = "short" }: DateCellProps) {
  if (value == null) {
    return <span className="text-muted-foreground">—</span>
  }

  const date = value instanceof Date ? value : new Date(value)

  if (Number.isNaN(date.getTime())) {
    return <span className="text-muted-foreground">Invalid date</span>
  }

  let formatted: string
  switch (format) {
    case "long":
      formatted = longFormatter.format(date)
      break
    case "relative":
      formatted = formatRelative(date)
      break
    default:
      formatted = shortFormatter.format(date)
  }

  return (
    <time dateTime={date.toISOString()} title={longFormatter.format(date)}>
      {formatted}
    </time>
  )
}
