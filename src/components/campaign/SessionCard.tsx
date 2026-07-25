import type { CampaignSession } from '../../types'
import { PANEL } from '../../lib/panelStyles'
import { formatDateFr } from '../../lib/formatDate'

interface Props {
  session: CampaignSession
  onClick: () => void
}

export function SessionCard({ session, onClick }: Props) {
  return (
    <button onClick={onClick} className={`${PANEL} flex flex-col overflow-hidden text-left w-full`}>
      {session.image_url && (
        <div className="h-20 w-full overflow-hidden border-b-2 border-ink">
          <img src={session.image_url} alt={session.title} className="w-full h-full object-cover" />
        </div>
      )}
      <div className="p-3 flex items-center gap-2">
        <span className="text-2xl shrink-0">{session.icon}</span>
        <div className="min-w-0">
          <p className="text-ink font-bold truncate">{session.title}</p>
          {session.session_date && (
            <p className="text-ink-muted-2 text-xs">{formatDateFr(session.session_date)}</p>
          )}
        </div>
      </div>
    </button>
  )
}
