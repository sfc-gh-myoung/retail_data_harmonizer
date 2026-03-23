import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion'
import { Info } from 'lucide-react'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'

interface SectionGroupProps {
  title: string
  tooltip?: string
  defaultOpen?: boolean
  children: React.ReactNode
  columns?: 2 | 3
}

export function SectionGroup({
  title,
  tooltip,
  defaultOpen = true,
  children,
  columns = 3,
}: SectionGroupProps) {
  const gridCols = columns === 2 
    ? 'grid-cols-1 md:grid-cols-2' 
    : 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3'

  return (
    <Accordion
      type="single"
      collapsible
      defaultValue={defaultOpen ? 'item' : undefined}
      className="mb-4"
    >
      <AccordionItem value="item" className="bg-secondary/50 rounded-lg border-0">
        <AccordionTrigger className="px-4 hover:no-underline">
          <div className="flex items-center gap-2">
            <span className="font-semibold">{title}</span>
            {tooltip && (
              <TooltipProvider>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Info className="h-4 w-4 text-muted-foreground" />
                  </TooltipTrigger>
                  <TooltipContent className="max-w-xs">
                    <p className="text-sm">{tooltip}</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            )}
          </div>
        </AccordionTrigger>
        <AccordionContent className="px-4 pb-4">
          <div className={`grid ${gridCols} gap-4`}>
            {children}
          </div>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  )
}

interface SectionCardProps {
  title: string
  tooltip?: string
  children: React.ReactNode
  fullWidth?: boolean
}

export function SectionCard({ title, tooltip, children, fullWidth }: SectionCardProps) {
  return (
    <div className={`bg-background/50 rounded-lg border p-4 ${fullWidth ? 'col-span-full' : ''}`}>
      <div className="flex items-center gap-2 mb-3">
        <h4 className="text-sm font-medium">{title}</h4>
        {tooltip && (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Info className="h-3 w-3 text-muted-foreground" />
              </TooltipTrigger>
              <TooltipContent className="max-w-xs">
                <p className="text-sm">{tooltip}</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        )}
      </div>
      {children}
    </div>
  )
}
