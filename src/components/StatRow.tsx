export function StatRow({ icon, label, value }: { icon: string; label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 py-2 border-b border-gray-700">
      <span className="text-xl w-7 shrink-0 text-center">{icon}</span>
      <span className="text-gray-400 text-sm w-32 shrink-0">{label}</span>
      <span className="text-white text-sm flex-1">{value}</span>
    </div>
  )
}
