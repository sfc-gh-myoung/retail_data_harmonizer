import type { ScaleData } from '../types'

interface ScaleProjectionProps {
  scaleData: ScaleData
}

export function ScaleProjection({ scaleData }: ScaleProjectionProps) {
  const prodItems = 48_000_000
  const prodUnique = Math.round(prodItems * scaleData.dedupRatio)
  const prodFullPipeline = Math.round(prodItems - (prodItems * scaleData.fastPathRate / 100))

  const dedupPercent = ((1 - scaleData.dedupRatio) * 100).toFixed(1)

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        Projected costs at production scale (48M items) based on demo performance.
      </p>
      
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b">
              <th className="text-left py-2 px-3 font-semibold">Metric</th>
              <th className="text-left py-2 px-3 font-semibold">
                Demo ({scaleData.total.toLocaleString()} items)
              </th>
              <th className="text-left py-2 px-3 font-semibold">
                Production (48M items)
              </th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b hover:bg-muted/50">
              <td className="py-2 px-3">Unique Descriptions</td>
              <td className="py-2 px-3">{scaleData.uniqueCount.toLocaleString()}</td>
              <td className="py-2 px-3">{prodUnique.toLocaleString()}</td>
            </tr>
            <tr className="border-b hover:bg-muted/50">
              <td className="py-2 px-3">Dedup Ratio</td>
              <td className="py-2 px-3" colSpan={2}>{dedupPercent}%</td>
            </tr>
            <tr className="border-b hover:bg-muted/50">
              <td className="py-2 px-3">Fast-path Rate</td>
              <td className="py-2 px-3">{scaleData.fastPathRate}%</td>
              <td className="py-2 px-3">{scaleData.fastPathRate}% (projected)</td>
            </tr>
            <tr className="hover:bg-muted/50">
              <td className="py-2 px-3">Items Needing Full Pipeline</td>
              <td className="py-2 px-3">
                {(scaleData.total - scaleData.fastPathCount).toLocaleString()}
              </td>
              <td className="py-2 px-3 font-semibold text-yellow-600 dark:text-yellow-500">
                {prodFullPipeline.toLocaleString()}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  )
}
