// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Turbo swaps <body> but keeps <html>, so carry the new page's theme over before it renders
addEventListener("turbo:before-render", ({ detail }) => {
  document.documentElement.dataset.theme = detail.newBody.dataset.theme
})
