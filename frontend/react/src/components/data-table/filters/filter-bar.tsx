import type { ReactNode } from "react"
import { X } from "lucide-react"

import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"

export interface FilterBarProps {
  children: ReactNode
  onReset?: () => void
  className?: string
}

export function FilterBar({ children, onReset, className }: FilterBarProps) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-3",
        className
      )}
    >
      {children}
      {onReset && (
        <Button
          variant="ghost"
          size="sm"
          className="h-8 px-2 text-xs text-muted-foreground"
          onClick={onReset}
        >
          <X className="mr-1 h-3 w-3" />
          Reset all
        </Button>
      )}
    </div>
  )
}
