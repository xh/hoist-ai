export function formatNumber(value: number, decimals = 2): string {
    if (value == null || isNaN(value)) return '';
    return value.toFixed(decimals);
}

export function isBlank(s: string | null | undefined): boolean {
    return s == null || s.trim().length === 0;
}
