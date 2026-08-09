import { AdminSafariGeneralPanel } from './AdminSafariGeneralPanel'
import { AdminSafariBerryPanel } from './AdminSafariBerryPanel'
import { AdminSafariGroupsPanel } from './AdminSafariGroupsPanel'
import { AdminSafariForcedDrawPanel } from './AdminSafariForcedDrawPanel'

export function AdminSafariPanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminSafariGeneralPanel />
      <AdminSafariBerryPanel />
      <AdminSafariGroupsPanel />
      <AdminSafariForcedDrawPanel />
    </div>
  )
}
