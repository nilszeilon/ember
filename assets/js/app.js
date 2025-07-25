// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/emberchat"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const hooks = {
  ...colocatedHooks,
  SearchModal: {
    mounted() {
      // Focus the search input when modal becomes visible
      this.observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
            const isOpen = this.el.classList.contains('modal-open')
            if (isOpen) {
              // Use a small delay to ensure the modal is fully rendered
              setTimeout(() => {
                const searchInput = this.el.querySelector('input[name="query"]')
                if (searchInput) {
                  searchInput.focus()
                }
              }, 100)
            }
          }
        })
      })
      
      this.observer.observe(this.el, {
        attributes: true,
        attributeFilter: ['class']
      })
    },
    
    destroyed() {
      if (this.observer) {
        this.observer.disconnect()
      }
    }
  },
  KeyboardShortcuts: {
    mounted() {
      this.handleKeyDown = (e) => {
        // Ctrl+K or Cmd+K to open search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
          e.preventDefault()
          this.pushEvent("keyboard_shortcut", {
            key: e.key,
            ctrlKey: e.ctrlKey,
            metaKey: e.metaKey
          })
        }
        // ESC to close modals and focus search
        else if (e.key === 'Escape') {
          // Don't prevent default to allow normal ESC behavior
          this.pushEvent("keyboard_shortcut", {
            key: e.key
          })
        }
      }
      
      window.addEventListener("keydown", this.handleKeyDown)
    },
    
    destroyed() {
      window.removeEventListener("keydown", this.handleKeyDown)
    }
  },
  MessageScroll: {
    mounted() {
      this.handleEvent("scroll_to_message", ({message_id}) => {
        this.scrollToMessage(message_id)
      })
      // Still auto-scroll to bottom on mount if no highlight
      if (!this.el.dataset.highlight) {
        this.scrollToBottom()
      }
    },
    updated() {
      // Auto-scroll to bottom unless we're highlighting a message
      if (!this.el.dataset.highlight) {
        this.scrollToBottom()
      }
    },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight
    },
    scrollToMessage(messageId) {
      const targetElement = document.querySelector(`#message-${messageId}`)
      
      if (targetElement) {
        targetElement.scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        })
        
        // Add a brief pulse animation after scrolling
        setTimeout(() => {
          targetElement.classList.add('animate-pulse')
          setTimeout(() => {
            targetElement.classList.remove('animate-pulse')
          }, 1000)
        }, 500)
      }
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Add scroll to message functionality
window.addEventListener("scroll-to-message", (e) => {
  const targetSelector = e.detail.to
  const targetElement = document.querySelector(targetSelector)
  
  if (targetElement) {
    targetElement.scrollIntoView({
      behavior: 'smooth',
      block: 'center'
    })
    
    // Add highlight effect
    targetElement.classList.add('animate-pulse')
    setTimeout(() => {
      targetElement.classList.remove('animate-pulse')
    }, 2000)
  }
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

