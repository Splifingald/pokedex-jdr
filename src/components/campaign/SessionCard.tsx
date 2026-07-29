import type { CampaignSession } from '../../types'
import { PANEL, PANEL_DONE } from '../../lib/panelStyles'
import { formatDateFr } from '../../lib/formatDate'
import { DoneBadge } from './DoneBadge'
import { CampaignIcon } from './CampaignIcon'

interface Props {
  session: CampaignSession
  onClick: () => void
}

export function SessionCard({ session, onClick }: Props) {
  return (
    <button onClick={onClick} className={`${session.done ? PANEL_DONE : PANEL} relative flex flex-col overflow-hidden text-left w-full`}>
      {session.done && <DoneBadge />}
      {session.image_url && (
        <div className="h-20 w-full overflow-hidden border-b-2 border-ink">
          <img
            src={session.image_url}
            alt={session.title}
            className="w-full h-full object-cover"
            style={{ objectPosition: `50% ${session.image_position ?? 50}%` }}
          />
        </div>
      )}
      <div className="p-3 flex items-center gap-2">
        <CampaignIcon icon={session.icon} size={28} emojiClassName="text-2xl" />
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
