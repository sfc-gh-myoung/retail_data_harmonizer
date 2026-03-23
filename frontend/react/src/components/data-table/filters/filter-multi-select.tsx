import { useRef, useState, useEffect } from "react"
import { Check, ChevronsUpDown, X } from "lucide-react"

import { cn } from "@/lib/utils"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"

export interface FilterMultiSelectProps {
  value: string[]
  onChange: (value: string[]) => void
  options: { value: string; label: string; count?: number }[]
  placeholder?: string
  className?: string
}

export function FilterMultiSelect({
  value,
  onChange,
  options,
  placeholder = "Select...",
  className,
}: FilterMultiSelectProps) {
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as Node)
      ) {
        setOpen(false)
      }
    }
    document.addEventListener("mousedown", handleClickOutside)
    return () => document.removeEventListener("mousedown", handleClickOutside)
  }, [])

  function toggleOption(optionValue: string) {
    if (value.includes(optionValue)) {
      onChange(value.filter((v) => v !== optionValue))
    } else {
      onChange([...value, optionValue])
    }
  }

  return (
    <div ref={containerRef} className={cn("relative", className)}>
      <Button
        variant="outline"
        size="sm"
        className="h-8 w-44 justify-between font-normal"
        onClick={() => setOpen((prev) => !prev)}
        aria-expanded={open}
      >
        <span className="truncate">
          {value.length > 0 ? (
            <span className="flex items-center gap-1.5">
              <span className="truncate">{placeholder}</span>
              <Badge variant="secondary" className="px-1.5 py-0 text-[10px]">
                {value.length}
              </Badge>
            </span>
          ) : (
            placeholder
          )}
        </span>
        <ChevronsUpDown className="ml-1 h-3 w-3 shrink-0 opacity-50" />
      </Button>

      {value.length > 0 && (
        <Button
          variant="ghost"
          size="icon"
          className="absolute -right-7 top-0 h-8 w-6"
          onClick={() => onChange([])}
          aria-label="Clear filter"
        >
          <X className="h-3 w-3" />
        </Button>
      )}

      {open && (
        <div className="absolute top-9 z-50 min-w-[12rem] rounded-md border bg-popover p-1 shadow-md animate-in fade-in-0 zoom-in-95">
          <div className="max-h-60 overflow-auto">
            {options.map((opt) => {
              const selected = value.includes(opt.value)
              return (
                <button
                  key={opt.value}
                  type="button"
                  className="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent hover:text-accent-foreground"
                  onClick={() => toggleOption(opt.value)}
                >
                  <Checkbox
                    checked={selected}
                    tabIndex={-1}
                    className="pointer-events-none"
                    aria-hidden
                  />
                  <span className="flex-1 text-left">{opt.label}</span>
                  {opt.count != null && (
                    <span className="text-xs text-muted-foreground">
                      {opt.count}
                    </span>
                  )}
                  {selected && (
                    <Check className="ml-auto h-3 w-3 text-primary" />
                  )}
                </button>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
