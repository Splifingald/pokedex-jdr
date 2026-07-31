import type { CampaignChapter } from '../../types'
import { PANEL, PANEL_DONE } from '../../lib/panelStyles'
import { getChapterBanner } from '../../lib/bannerExtension'
import { DoneBadge } from './DoneBadge'
import { CampaignIcon } from './CampaignIcon'

interface Props {
  chapter: CampaignChapter
  onClick: () => void
  onView: () => void
}

export function ChapterCard({ chapter, onClick, onView }: Props) {
  const banner = getChapterBanner(chapter.content)
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') onClick() }}
      className={`${chapter.done ? PANEL_DONE : PANEL} relative flex flex-col overflow-hidden text-left w-full cursor-pointer`}
    >
      {chapter.done && banner && <DoneBadge />}
      {banner && (
        <div className="h-20 w-full overflow-hidden border-b-2 border-ink">
          <img
            src={banner.src}
            alt={chapter.title}
            className="w-full h-full object-cover"
            style={{ objectPosition: `50% ${banner.position}%` }}
          />
        </div>
      )}
      <div className="p-3 flex items-center gap-2">
        <CampaignIcon icon={chapter.icon} size={28} emojiClassName="text-2xl" />
        <p className="flex-1 min-w-0 text-ink font-bold truncate">{chapter.title}</p>
        {chapter.done && !banner && (
          <span className="shrink-0 text-lg" title="Terminé">✅</span>
        )}
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); onView() }}
          title="Lire le chapitre"
          className="shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-sm bg-cream-secondary border-2 border-ink"
        >
          🔍
        </button>
      </div>
    </div>
  )
}
