import type { ReactNode } from 'react'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CASINO_ICON } from '../lib/icons'

export function GameBanner({ bannerUrl, fallbackEmoji, className }: { bannerUrl: string; fallbackEmoji: string; className: string }) {
  return (
    <div className={`w-full bg-black/10 flex items-center justify-center overflow-hidden ${className}`}>
      {bannerUrl ? (
        <img src={bannerUrl} alt="" className="w-full h-full object-cover" />
      ) : (
        <span className="text-4xl">{fallbackEmoji}</span>
      )}
    </div>
  )
}

export function GameCard({
  nom, iconUrl, bannerUrl, fallbackEmoji, disabled, onPlay, extraBadge, ticketIconUrl = CASINO_ICON.ticket,
}: {
  nom: string
  iconUrl: string
  bannerUrl: string
  fallbackEmoji: string
  disabled: boolean
  onPlay: () => void
  extraBadge?: ReactNode
  ticketIconUrl?: string
}) {
  return (
    <div className={`p-3 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
      <GameBanner bannerUrl={bannerUrl} fallbackEmoji={fallbackEmoji} className="h-24 rounded mb-2" />
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 shrink-0 flex items-center justify-center">
          {iconUrl ? (
            <img src={iconUrl} alt="" className="w-full h-full object-contain" />
          ) : (
            <span className="text-xl">{fallbackEmoji}</span>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <span className="block text-ink text-sm font-bold truncate">{nom}</span>
          {extraBadge}
        </div>
        <button
          onClick={onPlay}
          disabled={disabled}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-bold shrink-0 disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.yellow}`}
        >
          <img src={ticketIconUrl} alt="" className="w-4 h-4 object-contain pixelated" />
          Jouer
        </button>
      </div>
    </div>
  )
}
