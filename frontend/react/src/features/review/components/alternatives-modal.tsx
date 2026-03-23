import { useState } from 'react'
import { Check, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Skeleton } from '@/components/ui/skeleton'
import { useAlternatives, useSelectAlternative, type Alternative } from '../hooks/use-matches'
import { ConfidenceBadge } from './confidence-badge'

interface AlternativesModalProps {
  itemId: string | null
  matchId: string
  rawDescription: string
  onClose: () => void
}

export function AlternativesModal({
  itemId,
  matchId,
  rawDescription,
  onClose,
}: AlternativesModalProps) {
  const { data, isLoading, error } = useAlternatives(itemId)
  const selectAlternative = useSelectAlternative()
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const handleSelect = (alternative: Alternative) => {
    setSelectedId(alternative.standardItemId)
    selectAlternative.mutate(
      {
        itemId: itemId!,
        matchId,
        standardId: alternative.standardItemId,
      },
      {
        onSuccess: () => {
          onClose()
        },
        onError: () => {
          setSelectedId(null)
        },
      }
    )
  }

  return (
    <Dialog open={!!itemId} onOpenChange={() => onClose()}>
      <DialogContent className="max-w-3xl max-h-[80vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle>Alternative Candidates</DialogTitle>
          <DialogDescription className="truncate" title={rawDescription}>
            For: {rawDescription}
          </DialogDescription>
        </DialogHeader>

        <div className="flex-1 overflow-auto">
          {isLoading && (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          )}

          {error && (
            <div className="text-center py-8 text-destructive">
              Failed to load alternatives: {error.message}
            </div>
          )}

          {data && data.alternatives.length === 0 && (
            <div className="text-center py-8 text-muted-foreground">
              No alternative candidates available for this item.
            </div>
          )}

          {data && data.alternatives.length > 0 && (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Candidate</TableHead>
                  <TableHead>Method</TableHead>
                  <TableHead className="text-right">Score</TableHead>
                  <TableHead className="w-24"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.alternatives.map((alt) => (
                  <TableRow key={alt.standardItemId}>
                    <TableCell>
                      <div>
                        <span className="font-medium">{alt.description}</span>
                        {alt.brand && (
                          <span className="text-muted-foreground"> — {alt.brand}</span>
                        )}
                        {alt.price > 0 && (
                          <span className="text-muted-foreground">
                            {' '}
                            (${alt.price.toFixed(2)})
                          </span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {alt.method}
                    </TableCell>
                    <TableCell className="text-right">
                      <ConfidenceBadge score={alt.score} />
                    </TableCell>
                    <TableCell>
                      <Button
                        size="sm"
                        onClick={() => handleSelect(alt)}
                        disabled={selectAlternative.isPending}
                      >
                        {selectedId === alt.standardItemId ? (
                          <>
                            <Check className="h-3 w-3 mr-1 animate-pulse" />
                            Selecting...
                          </>
                        ) : (
                          'Select'
                        )}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </div>

        <div className="flex justify-end pt-4 border-t">
          <Button variant="outline" onClick={onClose}>
            <X className="h-4 w-4 mr-1" />
            Close
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
