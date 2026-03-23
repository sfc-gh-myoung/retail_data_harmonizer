import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from './dialog'

describe('Dialog components', () => {
  describe('Dialog with trigger and content', () => {
    it('opens dialog when trigger is clicked', () => {
      render(
        <Dialog>
          <DialogTrigger>Open Dialog</DialogTrigger>
          <DialogContent>
            <DialogTitle>Dialog Title</DialogTitle>
            <DialogDescription>Dialog description text</DialogDescription>
          </DialogContent>
        </Dialog>
      )
      
      fireEvent.click(screen.getByText('Open Dialog'))
      expect(screen.getByText('Dialog Title')).toBeInTheDocument()
      expect(screen.getByText('Dialog description text')).toBeInTheDocument()
    })

    it('renders close button in content', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
          </DialogContent>
        </Dialog>
      )
      
      expect(screen.getByText('Close')).toBeInTheDocument()
    })
  })

  describe('DialogHeader', () => {
    it('renders children', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogHeader>Header Content</DialogHeader>
            <DialogTitle>Title</DialogTitle>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByText('Header Content')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogHeader className="custom-header" data-testid="header">
              Header
            </DialogHeader>
            <DialogTitle>Title</DialogTitle>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByTestId('header')).toHaveClass('custom-header')
    })
  })

  describe('DialogFooter', () => {
    it('renders children', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
            <DialogFooter>
              <button>Cancel</button>
              <button>Submit</button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByText('Cancel')).toBeInTheDocument()
      expect(screen.getByText('Submit')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
            <DialogFooter className="custom-footer" data-testid="footer">
              Footer
            </DialogFooter>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByTestId('footer')).toHaveClass('custom-footer')
    })
  })

  describe('DialogTitle', () => {
    it('renders children', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>My Title</DialogTitle>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByText('My Title')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle className="custom-title" data-testid="title">
              Title
            </DialogTitle>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByTestId('title')).toHaveClass('custom-title')
    })
  })

  describe('DialogDescription', () => {
    it('renders children', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
            <DialogDescription>Description text here</DialogDescription>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByText('Description text here')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
            <DialogDescription className="custom-desc" data-testid="desc">
              Description
            </DialogDescription>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByTestId('desc')).toHaveClass('custom-desc')
    })

    it('has muted foreground styling', () => {
      render(
        <Dialog defaultOpen>
          <DialogContent>
            <DialogTitle>Title</DialogTitle>
            <DialogDescription data-testid="desc">Description</DialogDescription>
          </DialogContent>
        </Dialog>
      )
      expect(screen.getByTestId('desc')).toHaveClass('text-muted-foreground')
    })
  })
})
