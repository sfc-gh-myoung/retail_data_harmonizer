import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { SectionGroup, SectionCard } from './section-group'

describe('SectionGroup', () => {
  it('renders title', () => {
    render(
      <SectionGroup title="Test Section">
        <div>Content</div>
      </SectionGroup>
    )
    
    expect(screen.getByText('Test Section')).toBeInTheDocument()
  })

  it('renders children content', () => {
    render(
      <SectionGroup title="Test Section">
        <div>Child Content Here</div>
      </SectionGroup>
    )
    
    expect(screen.getByText('Child Content Here')).toBeInTheDocument()
  })

  it('renders tooltip when provided', () => {
    render(
      <SectionGroup title="Test Section" tooltip="This is a tooltip">
        <div>Content</div>
      </SectionGroup>
    )
    
    // Info icon should be present when tooltip is provided
    expect(document.querySelector('.lucide-info')).toBeInTheDocument()
  })

  it('does not render tooltip icon when not provided', () => {
    render(
      <SectionGroup title="Test Section">
        <div>Content</div>
      </SectionGroup>
    )
    
    // Only one info icon location is in SectionGroup header
    const infoIcons = document.querySelectorAll('.lucide-info')
    expect(infoIcons.length).toBe(0)
  })

  it('renders with 2 columns', () => {
    const { container } = render(
      <SectionGroup title="Test Section" columns={2}>
        <div>Item 1</div>
        <div>Item 2</div>
      </SectionGroup>
    )
    
    const grid = container.querySelector('[class*="md:grid-cols-2"]')
    expect(grid).toBeInTheDocument()
  })

  it('renders with 3 columns by default', () => {
    const { container } = render(
      <SectionGroup title="Test Section">
        <div>Item 1</div>
        <div>Item 2</div>
        <div>Item 3</div>
      </SectionGroup>
    )
    
    const grid = container.querySelector('[class*="lg:grid-cols-3"]')
    expect(grid).toBeInTheDocument()
  })

  it('starts closed when defaultOpen is false', () => {
    render(
      <SectionGroup title="Test Section" defaultOpen={false}>
        <div>Hidden Content</div>
      </SectionGroup>
    )
    
    // Content should be in the document but collapsed
    expect(screen.getByText('Test Section')).toBeInTheDocument()
  })
})

describe('SectionCard', () => {
  it('renders title', () => {
    render(
      <SectionCard title="Card Title">
        <div>Card Content</div>
      </SectionCard>
    )
    
    expect(screen.getByText('Card Title')).toBeInTheDocument()
  })

  it('renders children', () => {
    render(
      <SectionCard title="Card Title">
        <div>Card Content Here</div>
      </SectionCard>
    )
    
    expect(screen.getByText('Card Content Here')).toBeInTheDocument()
  })

  it('renders tooltip when provided', () => {
    render(
      <SectionCard title="Card Title" tooltip="Card tooltip text">
        <div>Content</div>
      </SectionCard>
    )
    
    // Info icon should be present
    expect(document.querySelector('.lucide-info')).toBeInTheDocument()
  })

  it('does not render tooltip icon when not provided', () => {
    render(
      <SectionCard title="Card Title">
        <div>Content</div>
      </SectionCard>
    )
    
    expect(document.querySelector('.lucide-info')).not.toBeInTheDocument()
  })
})
