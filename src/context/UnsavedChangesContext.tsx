import { createContext, useContext, useRef, useState, useCallback, type ReactNode } from 'react'
import { UnsavedChangesPopup } from '../components/UnsavedChangesPopup'

interface Guard {
  isDirty: () => boolean
  onSave: () => void
}

interface UnsavedChangesContextValue {
  setGuard: (guard: Guard | null) => void
  guardedNavigate: (action: () => void) => void
}

const UnsavedChangesContext = createContext<UnsavedChangesContextValue | null>(null)

export function UnsavedChangesProvider({ children }: { children: ReactNode }) {
  const guardRef = useRef<Guard | null>(null)
  const [pendingAction, setPendingAction] = useState<(() => void) | null>(null)

  const setGuard = useCallback((guard: Guard | null) => {
    guardRef.current = guard
  }, [])

  const guardedNavigate = useCallback((action: () => void) => {
    if (guardRef.current?.isDirty()) {
      setPendingAction(() => action)
    } else {
      action()
    }
  }, [])

  const handleSaveAndQuit = () => {
    guardRef.current?.onSave()
    const action = pendingAction
    setPendingAction(null)
    action?.()
  }

  const handleDiscardAndQuit = () => {
    const action = pendingAction
    setPendingAction(null)
    action?.()
  }

  return (
    <UnsavedChangesContext.Provider value={{ setGuard, guardedNavigate }}>
      {children}
      {pendingAction && (
        <UnsavedChangesPopup
          onSaveAndQuit={handleSaveAndQuit}
          onDiscardAndQuit={handleDiscardAndQuit}
          onCancel={() => setPendingAction(null)}
        />
      )}
    </UnsavedChangesContext.Provider>
  )
}

export function useUnsavedChangesGuard() {
  const ctx = useContext(UnsavedChangesContext)
  if (!ctx) throw new Error('useUnsavedChangesGuard doit être utilisé dans un UnsavedChangesProvider')
  return ctx
}
