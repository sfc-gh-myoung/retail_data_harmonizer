export interface NumberCellProps {
  value: number | null
  format?: "number" | "percent" | "currency"
  decimals?: number
}

function getFormatter(
  format: "number" | "percent" | "currency",
  decimals: number
): Intl.NumberFormat {
  switch (format) {
    case "percent":
      return new Intl.NumberFormat(undefined, {
        style: "percent",
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      })
    case "currency":
      return new Intl.NumberFormat(undefined, {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      })
    default:
      return new Intl.NumberFormat(undefined, {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      })
  }
}

export function NumberCell({
  value,
  format = "number",
  decimals = 2,
}: NumberCellProps) {
  if (value == null) {
    return <span className="text-muted-foreground">—</span>
  }

  const formatted = getFormatter(format, decimals).format(value)

  return <span className="tabular-nums">{formatted}</span>
}
