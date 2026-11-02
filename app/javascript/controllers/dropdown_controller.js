import { Controller } from "@hotwired/stimulus"

// A disclosure menu: the button shows and hides the menu, and clicking outside it
// or pressing Escape hides it again
export default class extends Controller {
  static targets = [ "button", "menu" ]

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape() {
    if (this.menuTarget.hidden) return
    this.close()
    this.buttonTarget.focus()
  }
}
