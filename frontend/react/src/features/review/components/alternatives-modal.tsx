import { X } from 'lucide-react'
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
import { useAlternatives } from '../hooks/use-matches'
import { ConfidenceBadge } from './confidence-badge'

interface AlternativesModalProps {
  itemId: string | null
  rawDescription: string
  onClose: () => void
}

export function AlternativesModal({
  itemId,
  rawDescription,
  onClose,
}: AlternativesModalProps) {
  const { data, isLoading, error } = useAlternatives(itemId)

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
