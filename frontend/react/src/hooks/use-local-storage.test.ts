import { renderHook, act } from '@testing-library/react'
import { describe, it, expect, beforeEach } from 'vitest'
import { useLocalStorage } from './use-local-storage'

describe('useLocalStorage', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('returns initial value when no stored value exists', () => {
    const { result } = renderHook(() => useLocalStorage('test-key', 'initial'))
    
    expect(result.current[0]).toBe('initial')
  })

  it('returns stored value when it exists', () => {
    localStorage.setItem('test-key', JSON.stringify('stored-value'))
    
    const { result } = renderHook(() => useLocalStorage('test-key', 'initial'))
    
    expect(result.current[0]).toBe('stored-value')
  })

  it('updates value and persists to localStorage', () => {
    const { result } = renderHook(() => useLocalStorage('test-key', 'initial'))
    
    act(() => {
      result.current[1]('new-value')
    })
    
    expect(result.current[0]).toBe('new-value')
    expect(JSON.parse(localStorage.getItem('test-key')!)).toBe('new-value')
  })

  it('accepts function updater', () => {
    const { result } = renderHook(() => useLocalStorage('counter', 0))
    
    act(() => {
      result.current[1]((prev) => prev + 1)
    })
    
    expect(result.current[0]).toBe(1)
  })

  it('handles object values', () => {
    const initialObj = { name: 'test', count: 0 }
    const { result } = renderHook(() => useLocalStorage('obj-key', initialObj))
    
    act(() => {
      result.current[1]({ name: 'updated', count: 5 })
    })
    
    expect(result.current[0]).toEqual({ name: 'updated', count: 5 })
  })

  it('handles array values', () => {
    const { result } = renderHook(() => useLocalStorage<string[]>('arr-key', []))
    
    act(() => {
      result.current[1](['a', 'b', 'c'])
    })
    
    expect(result.current[0]).toEqual(['a', 'b', 'c'])
  })

  it('returns initialValue when localStorage has invalid JSON', () => {
    localStorage.setItem('bad-key', 'not-json')
    
    const { result } = renderHook(() => useLocalStorage('bad-key', 'fallback'))
    
    expect(result.current[0]).toBe('fallback')
  })

  it('responds to storage events from other tabs', () => {
    const { result } = renderHook(() => useLocalStorage('sync-key', 'initial'))
    
    // Simulate storage event from another tab
    act(() => {
      const event = new StorageEvent('storage', {
        key: 'sync-key',
        newValue: JSON.stringify('from-other-tab'),
      })
      window.dispatchEvent(event)
    })
    
    expect(result.current[0]).toBe('from-other-tab')
  })

  it('ignores storage events for different keys', () => {
    const { result } = renderHook(() => useLocalStorage('my-key', 'initial'))
    
    act(() => {
      const event = new StorageEvent('storage', {
        key: 'other-key',
        newValue: JSON.stringify('other-value'),
      })
      window.dispatchEvent(event)
    })
    
    expect(result.current[0]).toBe('initial')
  })
})
