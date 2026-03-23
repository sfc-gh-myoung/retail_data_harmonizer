import { useCallback, useEffect, useRef, useState } from "react"
import { Search, X } from "lucide-react"

import { cn } from "@/lib/utils"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"

export interface FilterSearchProps {
  value: string | undefined
  onChange: (value: string | undefined) => void
  placeholder?: string
  className?: string
  debounceMs?: number
}

export function FilterSearch({
  value,
  onChange,
  placeholder = "Search...",
  className,
  debounceMs = 300,
}: FilterSearchProps) {
  // Use key to reset local state when value is cleared externally
  const [resetKey, setResetKey] = useState(0)

  return (
    <DebouncedInput
      key={resetKey}
      initialValue={value ?? ""}
      onChange={onChange}
      onClear={() => {
        onChange(undefined)
        setResetKey((k) => k + 1)
      }}
      placeholder={placeholder}
      className={className}
      debounceMs={debounceMs}
    />
  )
}

function DebouncedInput({
  initialValue,
  onChange,
  onClear,
  placeholder,
  className,
  debounceMs,
}: {
  initialValue: string
  onChange: (value: string | undefined) => void
  onClear: () => void
  placeholder: string | undefined
  className: string | undefined
  debounceMs: number
}) {
  const [localValue, setLocalValue] = useState(initialValue)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const flush = useCallback(
    (val: string) => {
      const trimmed = val.trim()
      onChange(trimmed.length > 0 ? trimmed : undefined)
    },
    [onChange]
  )

  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current)
      }
    }
  }, [])

  function handleChange(val: string) {
    setLocalValue(val)
    if (timerRef.current) {
      clearTimeout(timerRef.current)
    }
    timerRef.current = setTimeout(() => {
      flush(val)
      timerRef.current = null
    }, debounceMs)
  }

  return (
    <div className={cn("relative flex items-center", className)}>
      <Search className="absolute left-2 h-3.5 w-3.5 text-muted-foreground" />
      <Input
        value={localValue}
        onChange={(e) => handleChange(e.target.value)}
        placeholder={placeholder}
        className="h-8 w-48 pl-7 pr-7"
      />
      {localValue.length > 0 && (
        <Button
          variant="ghost"
          size="icon"
          className="absolute right-0 h-8 w-7"
          onClick={onClear}
          aria-label="Clear search"
        >
          <X className="h-3 w-3" />
        </Button>
      )}
    </div>
  )
}
