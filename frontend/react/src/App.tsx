import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'
import { QueryProvider } from '@/providers/query-provider'
import { AppLayout } from '@/components/app-layout'
import { FeatureErrorBoundary } from '@/components/feature-error-boundary'
import { LoadingFallback } from '@/components/loading-fallback'

// Lazy load features (named export pattern)
const Dashboard = lazy(() => import('@/features/dashboard').then(m => ({ default: m.Dashboard })))
const Pipeline = lazy(() => import('@/features/pipeline').then(m => ({ default: m.Pipeline })))
const Review = lazy(() => import('@/features/review').then(m => ({ default: m.Review })))
const Comparison = lazy(() => import('@/features/comparison').then(m => ({ default: m.Comparison })))
const Testing = lazy(() => import('@/features/testing').then(m => ({ default: m.Testing })))
const Logs = lazy(() => import('@/features/logs').then(m => ({ default: m.Logs })))
const Settings = lazy(() => import('@/features/settings').then(m => ({ default: m.Settings })))

// Import theme store to initialize on app load
import '@/stores/theme-store'

function App() {
  return (
    <QueryProvider>
      <Routes>
        <Route path="/" element={<AppLayout />}>
          <Route index element={
            <FeatureErrorBoundary featureName="Dashboard">
              <Suspense fallback={<LoadingFallback />}>
                <Dashboard />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="pipeline" element={
            <FeatureErrorBoundary featureName="Pipeline">
              <Suspense fallback={<LoadingFallback />}>
                <Pipeline />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="review" element={
            <FeatureErrorBoundary featureName="Review">
              <Suspense fallback={<LoadingFallback />}>
                <Review />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="comparison" element={
            <FeatureErrorBoundary featureName="Comparison">
              <Suspense fallback={<LoadingFallback />}>
                <Comparison />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="testing" element={
            <FeatureErrorBoundary featureName="Testing">
              <Suspense fallback={<LoadingFallback />}>
                <Testing />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="logs" element={
            <FeatureErrorBoundary featureName="Logs">
              <Suspense fallback={<LoadingFallback />}>
                <Logs />
              </Suspense>
            </FeatureErrorBoundary>
          } />
          <Route path="settings" element={
            <FeatureErrorBoundary featureName="Settings">
              <Suspense fallback={<LoadingFallback />}>
                <Settings />
              </Suspense>
            </FeatureErrorBoundary>
          } />
        </Route>
      </Routes>
    </QueryProvider>
  )
}

export { App }
