import { Badge } from "@/components/ui/badge"

export interface BadgeCellProps {
  value: string
  variants?: Record<
    string,
    "default" | "secondary" | "success" | "warning" | "destructive"
  >
}

export function BadgeCell({ value, variants }: BadgeCellProps) {
  const variant = variants?.[value] ?? "default"

  return <Badge variant={variant}>{value.replace(/_/g, " ")}</Badge>
}
