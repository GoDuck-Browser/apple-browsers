// This sends a mesasge to SERP about DuckPlayer
// being enabled.

// Normally, this message is sent by the legacy Duckplayer overlay
// Script, but this is no longer included in the native version
window.dispatchEvent(
    new CustomEvent('ddg-serp-yt-response', {
        detail: { 
            kind: 'initialSetup', 
            data: {
                privatePlayerMode: { enabled: {} },
                overlayInteracted: false,
            }
        },
        composed: true,
        bubbles: true,
    }),
)