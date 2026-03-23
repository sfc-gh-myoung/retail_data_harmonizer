import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Workflow,
  CheckSquare,
  GitCompare,
  FlaskConical,
  ScrollText,
  Settings,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/pipeline', icon: Workflow, label: 'Pipeline' },
  { to: '/review', icon: CheckSquare, label: 'Review' },
  { to: '/comparison', icon: GitCompare, label: 'Comparison' },
  { to: '/testing', icon: FlaskConical, label: 'Testing' },
  { to: '/logs', icon: ScrollText, label: 'Logs' },
  { to: '/settings', icon: Settings, label: 'Settings' },
]

export function Sidebar() {
  return (
    <aside className="w-60 border-r bg-muted/40 min-h-[calc(100vh-65px)]">
      <nav className="flex flex-col gap-1 p-4">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'
              )
            }
          >
            <item.icon className="h-4 w-4" />
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}
