export function parseOutputHashFromBuildLog(log: string): string | null {
  const match = log.match(/got:\s*(sha256-[A-Za-z0-9+/=]+)/m);
  return match?.[1] ?? null;
}
