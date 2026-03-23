import { Card, CardContent } from '@/components/ui/card'
import { cn } from '@/lib/utils'
import type { LucideIcon } from 'lucide-react'

interface KpiCardProps {
  title: string
  value: string | number
  icon?: LucideIcon
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'primary' | 'accent'
  subtitle?: string
}

const variantStyles = {
  default: 'text-foreground',
  success: 'text-green-600 dark:text-green-400',
  warning: 'text-yellow-600 dark:text-yellow-400',
  danger: 'text-red-600 dark:text-red-400',
  primary: 'text-blue-600 dark:text-blue-400',
  accent: 'text-purple-600 dark:text-purple-400',
}

export function KpiCard({ title, value, icon: Icon, variant = 'default', subtitle }: KpiCardProps) {
  const formattedValue = typeof value === 'number' 
    ? value.toLocaleString() 
    : value

  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-muted-foreground">{title}</p>
            <p className={cn('text-2xl font-bold', variantStyles[variant])}>
              {formattedValue}
            </p>
            {subtitle && (
              <p className="text-xs text-muted-foreground">{subtitle}</p>
            )}
          </div>
          {Icon && (
            <Icon className={cn('h-8 w-8 opacity-50', variantStyles[variant])} />
          )}
        </div>
      </CardContent>
    </Card>
  )
}
