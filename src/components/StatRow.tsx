export function StatRow({ icon, title, value }: { icon: React.ReactNode; title: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 py-2 border-b border-ink/20" title={title}>
      <span className="w-7 shrink-0 flex items-center justify-center text-xl leading-none">{icon}</span>
      <span className="text-ink text-sm flex-1">{value}</span>
    </div>
  )
}
