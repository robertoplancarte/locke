import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as it's on the page, for redirects that must be POSTs
export default class extends Controller {
  connect() {
    this.element.requestSubmit()
  }
}
