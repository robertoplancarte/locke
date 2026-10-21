import { Controller } from "@hotwired/stimulus"

// Asks before a non-Turbo form submits, which Turbo's data-turbo-confirm doesn't cover
export default class extends Controller {
  static values = { message: String }

  submit(event) {
    if (!confirm(this.messageValue)) event.preventDefault()
  }
}
