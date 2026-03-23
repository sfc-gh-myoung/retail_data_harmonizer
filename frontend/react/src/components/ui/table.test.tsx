import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import {
  Table,
  TableHeader,
  TableBody,
  TableFooter,
  TableHead,
  TableRow,
  TableCell,
  TableCaption,
} from './table'

describe('Table components', () => {
  describe('Table', () => {
    it('renders a table element', () => {
      render(<Table data-testid="table">Content</Table>)
      expect(screen.getByTestId('table')).toBeInTheDocument()
    })

    it('applies custom className', () => {
      render(<Table className="custom-class" data-testid="table">Content</Table>)
      expect(screen.getByTestId('table')).toHaveClass('custom-class')
    })
  })

  describe('TableHeader', () => {
    it('renders thead element', () => {
      render(
        <table>
          <TableHeader data-testid="header">
            <tr><th>Header</th></tr>
          </TableHeader>
        </table>
      )
      expect(screen.getByTestId('header').tagName).toBe('THEAD')
    })

    it('applies custom className', () => {
      render(
        <table>
          <TableHeader className="custom-header" data-testid="header">
            <tr><th>Header</th></tr>
          </TableHeader>
        </table>
      )
      expect(screen.getByTestId('header')).toHaveClass('custom-header')
    })
  })

  describe('TableBody', () => {
    it('renders tbody element', () => {
      render(
        <table>
          <TableBody data-testid="body">
            <tr><td>Cell</td></tr>
          </TableBody>
        </table>
      )
      expect(screen.getByTestId('body').tagName).toBe('TBODY')
    })

    it('applies custom className', () => {
      render(
        <table>
          <TableBody className="custom-body" data-testid="body">
            <tr><td>Cell</td></tr>
          </TableBody>
        </table>
      )
      expect(screen.getByTestId('body')).toHaveClass('custom-body')
    })
  })

  describe('TableFooter', () => {
    it('renders tfoot element', () => {
      render(
        <table>
          <TableFooter data-testid="footer">
            <tr><td>Footer</td></tr>
          </TableFooter>
        </table>
      )
      expect(screen.getByTestId('footer').tagName).toBe('TFOOT')
    })

    it('applies custom className', () => {
      render(
        <table>
          <TableFooter className="custom-footer" data-testid="footer">
            <tr><td>Footer</td></tr>
          </TableFooter>
        </table>
      )
      expect(screen.getByTestId('footer')).toHaveClass('custom-footer')
    })
  })

  describe('TableRow', () => {
    it('renders tr element', () => {
      render(
        <table>
          <tbody>
            <TableRow data-testid="row"><td>Cell</td></TableRow>
          </tbody>
        </table>
      )
      expect(screen.getByTestId('row').tagName).toBe('TR')
    })

    it('applies custom className', () => {
      render(
        <table>
          <tbody>
            <TableRow className="custom-row" data-testid="row"><td>Cell</td></TableRow>
          </tbody>
        </table>
      )
      expect(screen.getByTestId('row')).toHaveClass('custom-row')
    })
  })

  describe('TableHead', () => {
    it('renders th element', () => {
      render(
        <table>
          <thead>
            <tr>
              <TableHead data-testid="head">Header</TableHead>
            </tr>
          </thead>
        </table>
      )
      expect(screen.getByTestId('head').tagName).toBe('TH')
    })

    it('applies custom className', () => {
      render(
        <table>
          <thead>
            <tr>
              <TableHead className="custom-head" data-testid="head">Header</TableHead>
            </tr>
          </thead>
        </table>
      )
      expect(screen.getByTestId('head')).toHaveClass('custom-head')
    })
  })

  describe('TableCell', () => {
    it('renders td element', () => {
      render(
        <table>
          <tbody>
            <tr>
              <TableCell data-testid="cell">Cell Content</TableCell>
            </tr>
          </tbody>
        </table>
      )
      expect(screen.getByTestId('cell').tagName).toBe('TD')
    })

    it('applies custom className', () => {
      render(
        <table>
          <tbody>
            <tr>
              <TableCell className="custom-cell" data-testid="cell">Cell</TableCell>
            </tr>
          </tbody>
        </table>
      )
      expect(screen.getByTestId('cell')).toHaveClass('custom-cell')
    })
  })

  describe('TableCaption', () => {
    it('renders caption element', () => {
      render(
        <table>
          <TableCaption data-testid="caption">Table Caption</TableCaption>
        </table>
      )
      expect(screen.getByTestId('caption').tagName).toBe('CAPTION')
    })

    it('applies custom className', () => {
      render(
        <table>
          <TableCaption className="custom-caption" data-testid="caption">Caption</TableCaption>
        </table>
      )
      expect(screen.getByTestId('caption')).toHaveClass('custom-caption')
    })
  })

  describe('Full table structure', () => {
    it('renders a complete table with all components', () => {
      render(
        <Table>
          <TableCaption>A sample table</TableCaption>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Value</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow>
              <TableCell>Item 1</TableCell>
              <TableCell>100</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Item 2</TableCell>
              <TableCell>200</TableCell>
            </TableRow>
          </TableBody>
          <TableFooter>
            <TableRow>
              <TableCell>Total</TableCell>
              <TableCell>300</TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      )

      expect(screen.getByText('A sample table')).toBeInTheDocument()
      expect(screen.getByText('Name')).toBeInTheDocument()
      expect(screen.getByText('Value')).toBeInTheDocument()
      expect(screen.getByText('Item 1')).toBeInTheDocument()
      expect(screen.getByText('Item 2')).toBeInTheDocument()
      expect(screen.getByText('Total')).toBeInTheDocument()
      expect(screen.getByText('300')).toBeInTheDocument()
    })
  })
})
