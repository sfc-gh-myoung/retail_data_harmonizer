import type { ColumnDef, RowData } from "@tanstack/react-table"
import { createElement } from "react"
import { BadgeCell, type BadgeCellProps } from "./badge-cell"
import { DateCell, type DateCellProps } from "./date-cell"
import { NumberCell, type NumberCellProps } from "./number-cell"
import { ActionCell, type Action } from "./action-cell"
import { Checkbox } from "@/components/ui/checkbox"

// ── Select (checkbox) column ───────────────────────────────────────────

export function createSelectColumn<TData extends RowData>(): ColumnDef<TData> {
  return {
    id: "select",
    header: ({ table }) =>
      createElement(Checkbox, {
        checked:
          table.getIsAllPageRowsSelected() ||
          (table.getIsSomePageRowsSelected() && "indeterminate"),
        onCheckedChange: (value: boolean) =>
          table.toggleAllPageRowsSelected(!!value),
        "aria-label": "Select all",
      }),
    cell: ({ row }) =>
      createElement(Checkbox, {
        checked: row.getIsSelected(),
        onCheckedChange: (value: boolean) => row.toggleSelected(!!value),
        "aria-label": "Select row",
      }),
    enableSorting: false,
    enableHiding: false,
  }
}

// ── Sortable text column ───────────────────────────────────────────────

interface SortableColumnOptions<TData> {
  accessorKey: keyof TData & string
  header: string
  enableSorting?: boolean
}

export function createSortableColumn<TData extends RowData>(
  options: SortableColumnOptions<TData>
): ColumnDef<TData> {
  return {
    accessorKey: options.accessorKey,
    header: options.header,
    enableSorting: options.enableSorting ?? true,
  } as ColumnDef<TData>
}

// ── Badge column ───────────────────────────────────────────────────────

interface BadgeColumnOptions<TData> {
  accessorKey: keyof TData & string
  header: string
  variants?: BadgeCellProps["variants"]
}

export function createBadgeColumn<TData extends RowData>(
  options: BadgeColumnOptions<TData>
): ColumnDef<TData> {
  return {
    accessorKey: options.accessorKey,
    header: options.header,
    cell: ({ getValue }) =>
      createElement(BadgeCell, {
        value: getValue<string>(),
        variants: options.variants,
      }),
    enableSorting: true,
  } as ColumnDef<TData>
}

// ── Date column ────────────────────────────────────────────────────────

interface DateColumnOptions<TData> {
  accessorKey: keyof TData & string
  header: string
  format?: DateCellProps["format"]
}

export function createDateColumn<TData extends RowData>(
  options: DateColumnOptions<TData>
): ColumnDef<TData> {
  return {
    accessorKey: options.accessorKey,
    header: options.header,
    cell: ({ getValue }) =>
      createElement(DateCell, {
        value: getValue<string | Date | null>(),
        format: options.format,
      }),
    enableSorting: true,
  } as ColumnDef<TData>
}

// ── Number column ──────────────────────────────────────────────────────

interface NumberColumnOptions<TData> {
  accessorKey: keyof TData & string
  header: string
  format?: NumberCellProps["format"]
  decimals?: number
}

export function createNumberColumn<TData extends RowData>(
  options: NumberColumnOptions<TData>
): ColumnDef<TData> {
  return {
    accessorKey: options.accessorKey,
    header: options.header,
    cell: ({ getValue }) =>
      createElement(NumberCell, {
        value: getValue<number | null>(),
        format: options.format,
        decimals: options.decimals,
      }),
    enableSorting: true,
  } as ColumnDef<TData>
}

// ── Actions column ─────────────────────────────────────────────────────

export function createActionsColumn<TData extends RowData>(
  actions: Action<TData>[]
): ColumnDef<TData> {
  return {
    id: "actions",
    header: "",
    cell: ({ row }) =>
      createElement(ActionCell<TData>, {
        row: row.original,
        actions,
      }),
    enableSorting: false,
    enableHiding: false,
  } as ColumnDef<TData>
}
