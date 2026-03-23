import { Outlet } from 'react-router-dom'
import { Toaster } from 'sonner'
import { Sidebar } from '@/components/sidebar'
import { ThemeToggle } from '@/components/theme-toggle'
import { TooltipProvider } from '@/components/ui/tooltip'

export function AppLayout() {
  return (
    <TooltipProvider>
      <Toaster richColors position="top-right" />
      <div className="min-h-screen bg-background">
        <header className="border-b">
          <div className="flex items-center justify-between px-6 py-4">
            <h1 className="text-xl font-bold">Retail Data Harmonizer</h1>
            <ThemeToggle />
          </div>
        </header>

        <div className="flex">
          <Sidebar />
          <main className="flex-1 p-6">
            <Outlet />
          </main>
        </div>
      </div>
    </TooltipProvider>
  )
}
