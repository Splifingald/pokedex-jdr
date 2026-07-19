export type ButtonColor = 'blue' | 'orange' | 'yellow' | 'gray' | 'green' | 'red'

// Fond pastel + texte noir + bordure sombre de la même teinte, cohérent sur tous les boutons d'action étiquetés.
export const BUTTON_STYLE: Record<ButtonColor, string> = {
  blue: 'bg-blue-200 border border-blue-700 text-black hover:bg-blue-300 transition-colors',
  orange: 'bg-orange-200 border border-orange-700 text-black hover:bg-orange-300 transition-colors',
  yellow: 'bg-yellow-200 border border-yellow-700 text-black hover:bg-yellow-300 transition-colors',
  gray: 'bg-gray-200 border border-gray-700 text-black hover:bg-gray-300 transition-colors',
  green: 'bg-green-200 border border-green-700 text-black hover:bg-green-300 transition-colors',
  red: 'bg-red-200 border border-red-700 text-black hover:bg-red-300 transition-colors',
}
