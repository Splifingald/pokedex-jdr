import type { CampaignChapter } from '../../types'
import { PANEL } from '../../lib/panelStyles'

interface Props {
  chapter: CampaignChapter
  onClick: () => void
}

export function ChapterCard({ chapter, onClick }: Props) {
  return (
    <button onClick={onClick} className={`${PANEL} flex flex-col overflow-hidden text-left w-full`}>
      {chapter.image_url && (
        <div className="h-20 w-full overflow-hidden border-b-2 border-ink">
          <img src={chapter.image_url} alt={chapter.title} className="w-full h-full object-cover" />
        </div>
      )}
      <div className="p-3 flex items-center gap-2">
        <span className="text-2xl shrink-0">{chapter.icon}</span>
        <p className="text-ink font-bold truncate">{chapter.title}</p>
      </div>
    </button>
  )
}
