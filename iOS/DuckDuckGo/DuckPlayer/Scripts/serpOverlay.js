window.dispatchEvent(
    new CustomEvent('ddg-serp-yt-response', {
        detail: { 
            kind: 'initialSetup', 
            data: {
                privatePlayerMode: { alwaysAsk: {} },
                overlayInteracted: false,
            }
        },
        composed: true,
        bubbles: true,
    }),
)