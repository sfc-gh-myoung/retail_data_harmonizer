import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
} from './select'

// Mock scrollIntoView for JSDOM
beforeEach(() => {
  Element.prototype.scrollIntoView = vi.fn()
})

describe('Select', () => {
  it('renders trigger with placeholder', () => {
    render(
      <Select>
        <SelectTrigger data-testid="trigger">
          <SelectValue placeholder="Select an option" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    expect(screen.getByTestId('trigger')).toBeInTheDocument()
    expect(screen.getByText('Select an option')).toBeInTheDocument()
  })

  it('renders trigger with chevron icon', () => {
    const { container } = render(
      <Select>
        <SelectTrigger data-testid="trigger">
          <SelectValue placeholder="Select" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    // Should have an SVG chevron icon
    const svg = container.querySelector('svg')
    expect(svg).toBeInTheDocument()
  })
})

describe('SelectTrigger', () => {
  it('applies custom className', () => {
    render(
      <Select>
        <SelectTrigger data-testid="trigger" className="custom-trigger">
          <SelectValue placeholder="Select" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    expect(screen.getByTestId('trigger')).toHaveClass('custom-trigger')
  })

  it('renders children', () => {
    render(
      <Select>
        <SelectTrigger>
          <span data-testid="custom-child">Custom Content</span>
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    expect(screen.getByTestId('custom-child')).toBeInTheDocument()
  })

  it('has combobox role', () => {
    render(
      <Select>
        <SelectTrigger>
          <SelectValue placeholder="Select" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    expect(screen.getByRole('combobox')).toBeInTheDocument()
  })

  it('applies default styling classes', () => {
    render(
      <Select>
        <SelectTrigger data-testid="trigger">
          <SelectValue placeholder="Select" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Option 1</SelectItem>
        </SelectContent>
      </Select>
    )

    const trigger = screen.getByTestId('trigger')
    expect(trigger).toHaveClass('flex', 'h-9', 'w-full', 'items-center', 'justify-between')
  })
})

describe('SelectLabel', () => {
  it('is exported correctly', () => {
    expect(SelectLabel).toBeDefined()
  })
})

describe('SelectSeparator', () => {
  it('is exported correctly', () => {
    expect(SelectSeparator).toBeDefined()
  })
})

describe('SelectGroup', () => {
  it('is exported correctly', () => {
    expect(SelectGroup).toBeDefined()
  })
})

describe('SelectContent', () => {
  it('is exported correctly', () => {
    expect(SelectContent).toBeDefined()
  })
})

describe('SelectItem', () => {
  it('is exported correctly', () => {
    expect(SelectItem).toBeDefined()
  })
})

describe('SelectValue', () => {
  it('is exported correctly', () => {
    expect(SelectValue).toBeDefined()
  })
})
