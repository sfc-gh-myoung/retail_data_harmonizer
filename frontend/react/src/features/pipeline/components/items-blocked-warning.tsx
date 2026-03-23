import { AlertTriangle } from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'

interface ItemsBlockedWarningProps {
  blockedCount: number
}

export function ItemsBlockedWarning({ blockedCount }: ItemsBlockedWarningProps) {
  if (blockedCount <= 0) return null

  return (
    <Alert variant="warning">
      <AlertTriangle className="h-5 w-5" />
      <AlertTitle>{blockedCount.toLocaleString()} Items Blocked</AlertTitle>
      <AlertDescription>
        Missing category classification. These items are excluded from pipeline progress counts
        until categorized.
      </AlertDescription>
    </Alert>
  )
}
