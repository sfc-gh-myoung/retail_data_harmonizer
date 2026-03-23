import { ConfidenceBadge } from './confidence-badge'

interface ScoreBreakdownProps {
  searchScore: number
  cosineScore: number
  editScore: number
  jaccardScore: number
  ensembleScore: number
  agreementLevel: number
  boostPercent: number
}

/**
 * Detailed score breakdown panel showing all individual method scores
 * and the ensemble calculation with agreement boost explanation.
 */
export function ScoreBreakdown({
  searchScore,
  cosineScore,
  editScore,
  jaccardScore,
  ensembleScore,
  agreementLevel,
  boostPercent,
}: ScoreBreakdownProps) {
  const getAgreementLabel = (level: number) => {
    switch (level) {
      case 4: return '4-way agreement'
      case 3: return '3-way agreement'
      case 2: return '2-way agreement'
      default: return 'No agreement'
    }
  }

  return (
    <div className="space-y-3">
      {/* Individual Method Scores */}
      <div>
        <h4 className="text-xs font-medium text-muted-foreground mb-2">Individual Scores</h4>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div className="flex items-center justify-between gap-2 p-2 rounded bg-muted/50">
            <span className="text-xs font-medium">Search</span>
            <ConfidenceBadge score={searchScore} />
          </div>
          <div className="flex items-center justify-between gap-2 p-2 rounded bg-muted/50">
            <span className="text-xs font-medium">Cosine</span>
            <ConfidenceBadge score={cosineScore} />
          </div>
          <div className="flex items-center justify-between gap-2 p-2 rounded bg-muted/50">
            <span className="text-xs font-medium">Edit</span>
            <ConfidenceBadge score={editScore} />
          </div>
          <div className="flex items-center justify-between gap-2 p-2 rounded bg-muted/50">
            <span className="text-xs font-medium">Jaccard</span>
            <ConfidenceBadge score={jaccardScore} />
          </div>
        </div>
      </div>

      {/* Ensemble Score with Boost Explanation */}
      <div className="border-t pt-3">
        <h4 className="text-xs font-medium text-muted-foreground mb-2">Ensemble Score</h4>
        <div className="flex items-center gap-3 p-3 rounded bg-primary/5 border border-primary/20">
          <ConfidenceBadge score={ensembleScore} size="md" />
          {boostPercent > 0 && (
            <span className="text-sm text-muted-foreground">
              ({getAgreementLabel(agreementLevel)} × {(1 + boostPercent / 100).toFixed(2)})
            </span>
          )}
          {boostPercent === 0 && (
            <span className="text-sm text-muted-foreground">
              (no agreement boost)
            </span>
          )}
        </div>
      </div>

      {/* Agreement Level Indicator */}
      <div className="flex items-center gap-2">
        <span className="text-xs text-muted-foreground">Agreement:</span>
        <div className="flex gap-0.5">
          {[1, 2, 3, 4].map((level) => (
            <div
              key={level}
              className={`w-4 h-2 rounded-sm ${
                level <= agreementLevel
                  ? 'bg-green-500'
                  : 'bg-muted'
              }`}
              title={`${level}-way`}
            />
          ))}
        </div>
        {boostPercent > 0 && (
          <span className="text-xs font-medium text-green-600 dark:text-green-400">
            +{boostPercent}%
          </span>
        )}
      </div>
    </div>
  )
}
