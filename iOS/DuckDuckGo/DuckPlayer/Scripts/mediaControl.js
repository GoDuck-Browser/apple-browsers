(function() {
    // Initialize state if not exists
    if (!window._mediaControlState) {
        window._mediaControlState = {
            observer: null,
            userInitiated: false,
            originalPlay: HTMLMediaElement.prototype.play,
            eventListeners: new Map(), // Store event listeners for cleanup
            isPaused: false
        };
    }
    const state = window._mediaControlState;

    // Helper to safely add event listeners with cleanup
    function addEventListenerWithCleanup(target, type, listener, options) {
        const wrappedListener = (e) => {
            if (!state.isPaused || state.userInitiated) return;
            listener(e);
        };
        target.addEventListener(type, wrappedListener, options);
        
        // Store for cleanup
        if (!state.eventListeners.has(type)) {
            state.eventListeners.set(type, []);
        }
        state.eventListeners.get(type).push({ target, listener: wrappedListener, options });
    }

    // Helper to remove all stored event listeners
    function removeAllEventListeners() {
        state.eventListeners.forEach((listeners, type) => {
            listeners.forEach(({ target, listener, options }) => {
                target.removeEventListener(type, listener, options);
            });
        });
        state.eventListeners.clear();
    }

    // Block playback handler
    const blockPlayback = function(event) {
        if (!state.isPaused || state.userInitiated) return;
        event.preventDefault();
        event.stopPropagation();
        return false;
    };

    // Touch handler
    const handleTouch = function(event) {
        if (!state.isPaused) return;
        state.userInitiated = true;
        document.querySelectorAll('audio, video').forEach(media => {
            media.muted = false;
        });
        // Allow playback for a short time
        setTimeout(() => {
            state.userInitiated = false;
        }, 1000);
    };

    // The actual media control function
    function mediaControl(pause) {
        // Update state
        state.isPaused = pause;
        
        // Clean up existing handlers
        removeAllEventListeners();
        
        if (pause) {
            // Override play method
            HTMLMediaElement.prototype.play = function() {
                if (!state.isPaused || state.userInitiated) {
                    return state.originalPlay.apply(this, arguments);
                }
                this.pause();
                return Promise.reject(new Error("Playback blocked"));
            };

            // Add event listeners
            addEventListenerWithCleanup(document, 'play', blockPlayback, true);
            addEventListenerWithCleanup(document, 'playing', blockPlayback, true);
            addEventListenerWithCleanup(document, 'touchstart', handleTouch, true);
            addEventListenerWithCleanup(document, 'click', handleTouch, true);

            // Function to pause all media
            const pauseAllMedia = () => {
                if (!state.isPaused || state.userInitiated) return;
                document.querySelectorAll('audio, video').forEach(media => {
                    try {
                        media.pause();
                        media.muted = true;
                    } catch (e) {
                        console.error('Error pausing media:', e);
                    }
                });
            };

            // Initial pause
            pauseAllMedia();

            // Setup observer if needed
            if (state.observer) {
                state.observer.disconnect();
            }
            
            state.observer = new MutationObserver(mutations => {
                if (!state.isPaused || state.userInitiated) return;
                mutations.forEach(mutation => {
                    mutation.addedNodes.forEach(node => {
                        if (node.tagName === 'AUDIO' || node.tagName === 'VIDEO') {
                            try {
                                node.pause();
                                node.muted = true;
                            } catch (e) {
                                console.error('Error handling new media:', e);
                            }
                        } else if (node.querySelectorAll) {
                            node.querySelectorAll('audio, video').forEach(media => {
                                try {
                                    media.pause();
                                    media.muted = true;
                                } catch (e) {
                                    console.error('Error handling new media:', e);
                                }
                            });
                        }
                    });
                });
            });
            
            try {
                state.observer.observe(document.body, { 
                    childList: true, 
                    subtree: true 
                });
            } catch (e) {
                console.error('Error setting up observer:', e);
            }

        } else {
            // Restore original play method
            HTMLMediaElement.prototype.play = state.originalPlay;
            
            // Clean up observer
            if (state.observer) {
                state.observer.disconnect();
                state.observer = null;
            }

            // Unmute media
            document.querySelectorAll('audio, video').forEach(media => {
                try {
                    media.muted = false;
                } catch (e) {
                    console.error('Error unmuting media:', e);
                }
            });
        }
    }

    // Export function
    window.mediaControl = mediaControl;
    
})();