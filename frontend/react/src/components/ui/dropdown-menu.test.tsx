import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuCheckboxItem,
  DropdownMenuRadioItem,
  DropdownMenuRadioGroup,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuGroup,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
} from './dropdown-menu'

describe('DropdownMenu', () => {
  it('renders trigger', () => {
    render(
      <DropdownMenu>
        <DropdownMenuTrigger>Open Menu</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem>Item 1</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    expect(screen.getByText('Open Menu')).toBeInTheDocument()
  })

  it('trigger has menu aria attributes', () => {
    render(
      <DropdownMenu>
        <DropdownMenuTrigger data-testid="trigger">Open Menu</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem>Item 1</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const trigger = screen.getByTestId('trigger')
    expect(trigger).toHaveAttribute('aria-haspopup', 'menu')
  })
})

describe('DropdownMenuItem', () => {
  it('renders with default classes', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem data-testid="item">Menu Item</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const item = await screen.findByTestId('item')
    expect(item).toHaveClass('flex', 'cursor-default', 'select-none')
  })

  it('applies inset class when inset prop is true', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem data-testid="item" inset>Inset Item</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const item = await screen.findByTestId('item')
    expect(item).toHaveClass('pl-8')
  })

  it('applies custom className', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem data-testid="item" className="custom-class">Item</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const item = await screen.findByTestId('item')
    expect(item).toHaveClass('custom-class')
  })
})

describe('DropdownMenuCheckboxItem', () => {
  it('renders checkbox item', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuCheckboxItem checked data-testid="checkbox">
            Checkbox Item
          </DropdownMenuCheckboxItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    expect(await screen.findByText('Checkbox Item')).toBeInTheDocument()
  })

  it('is exported correctly', () => {
    expect(DropdownMenuCheckboxItem).toBeDefined()
  })
})

describe('DropdownMenuRadioItem', () => {
  it('renders radio item within group', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuRadioGroup value="1">
            <DropdownMenuRadioItem value="1">Option 1</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="2">Option 2</DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    expect(await screen.findByText('Option 1')).toBeInTheDocument()
    expect(await screen.findByText('Option 2')).toBeInTheDocument()
  })
})

describe('DropdownMenuLabel', () => {
  it('renders label text', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuLabel>Section Label</DropdownMenuLabel>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    expect(await screen.findByText('Section Label')).toBeInTheDocument()
  })

  it('applies inset class when inset prop is true', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuLabel data-testid="label" inset>Inset Label</DropdownMenuLabel>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const label = await screen.findByTestId('label')
    expect(label).toHaveClass('pl-8')
  })

  it('applies custom className', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuLabel data-testid="label" className="custom-label">Label</DropdownMenuLabel>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const label = await screen.findByTestId('label')
    expect(label).toHaveClass('custom-label')
  })
})

describe('DropdownMenuSeparator', () => {
  it('renders separator', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem>Item 1</DropdownMenuItem>
          <DropdownMenuSeparator data-testid="separator" />
          <DropdownMenuItem>Item 2</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const separator = await screen.findByTestId('separator')
    expect(separator).toHaveClass('h-px', 'bg-muted')
  })

  it('applies custom className', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuSeparator data-testid="separator" className="custom-separator" />
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const separator = await screen.findByTestId('separator')
    expect(separator).toHaveClass('custom-separator')
  })
})

describe('DropdownMenuShortcut', () => {
  it('renders shortcut text with correct classes', () => {
    render(<DropdownMenuShortcut data-testid="shortcut">⌘K</DropdownMenuShortcut>)

    const shortcut = screen.getByTestId('shortcut')
    expect(shortcut).toHaveTextContent('⌘K')
    expect(shortcut).toHaveClass('ml-auto', 'text-xs', 'tracking-widest', 'opacity-60')
  })

  it('applies custom className', () => {
    render(
      <DropdownMenuShortcut data-testid="shortcut" className="custom-shortcut">
        ⌘S
      </DropdownMenuShortcut>
    )

    const shortcut = screen.getByTestId('shortcut')
    expect(shortcut).toHaveClass('custom-shortcut')
  })
})

describe('DropdownMenuGroup', () => {
  it('renders grouped items', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuGroup>
            <DropdownMenuItem>Group Item 1</DropdownMenuItem>
            <DropdownMenuItem>Group Item 2</DropdownMenuItem>
          </DropdownMenuGroup>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    expect(await screen.findByText('Group Item 1')).toBeInTheDocument()
    expect(await screen.findByText('Group Item 2')).toBeInTheDocument()
  })
})

describe('DropdownMenuSubTrigger', () => {
  it('renders sub trigger', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuSub>
            <DropdownMenuSubTrigger data-testid="subtrigger">
              More Options
            </DropdownMenuSubTrigger>
            <DropdownMenuSubContent>
              <DropdownMenuItem>Sub Item</DropdownMenuItem>
            </DropdownMenuSubContent>
          </DropdownMenuSub>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const trigger = await screen.findByTestId('subtrigger')
    expect(trigger).toHaveTextContent('More Options')
  })

  it('is exported correctly', () => {
    expect(DropdownMenuSubTrigger).toBeDefined()
  })

  it('applies inset class when inset prop is true', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuSub>
            <DropdownMenuSubTrigger data-testid="subtrigger" inset>
              Inset Sub
            </DropdownMenuSubTrigger>
            <DropdownMenuSubContent>
              <DropdownMenuItem>Sub Item</DropdownMenuItem>
            </DropdownMenuSubContent>
          </DropdownMenuSub>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const trigger = await screen.findByTestId('subtrigger')
    expect(trigger).toHaveClass('pl-8')
  })
})

describe('DropdownMenuContent', () => {
  it('renders content with default classes', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent data-testid="content">
          <DropdownMenuItem>Item</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const content = await screen.findByTestId('content')
    expect(content).toHaveClass('z-50', 'min-w-[8rem]', 'overflow-hidden', 'rounded-md', 'border')
  })

  it('applies custom className', async () => {
    render(
      <DropdownMenu defaultOpen>
        <DropdownMenuTrigger>Open</DropdownMenuTrigger>
        <DropdownMenuContent data-testid="content" className="custom-content">
          <DropdownMenuItem>Item</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )

    const content = await screen.findByTestId('content')
    expect(content).toHaveClass('custom-content')
  })
})

describe('DropdownMenuSubContent', () => {
  it('is exported correctly', () => {
    expect(DropdownMenuSubContent).toBeDefined()
  })
})
