import { AdminPensionConfigPanel } from './AdminPensionConfigPanel'
import { AdminPensionXpGroupsPanel } from './AdminPensionXpGroupsPanel'
import { AdminPensionGroupsPanel } from './AdminPensionGroupsPanel'

export function AdminPensionPanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminPensionConfigPanel />
      <AdminPensionXpGroupsPanel />
      <AdminPensionGroupsPanel />
    </div>
  )
}
