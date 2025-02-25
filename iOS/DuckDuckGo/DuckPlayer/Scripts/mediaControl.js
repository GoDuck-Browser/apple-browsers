// Only initialize once
if (!window._mediaControlInitialized) {
    window._mediaControlInitialized = true;
    console.log('Media Control Script loading...');

    // Store shared state
    window._mediaControlState = {
        observer: null,
        userInitiated: false,
        originalPlay: HTMLMediaElement.prototype.play,
        touchHandler: null,
        blockPlayback: null
    };

    // Run initial setup
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            console.log('Media Control Script: DOMContentLoaded');
            mediaControl(true);
        });
    } else {
        console.log('Media Control Script: document already loaded');
        mediaControl(true);
    }

    // Cleanup on unload
    window.addEventListener('beforeunload', () => {
        console.log('Media Control Script: beforeunload');
        mediaControl(false);
    });
}

function mediaControl(pause) {
    const state = window._mediaControlState;
    if (!state) return; // Safety check

    // Clean up existing handlers
    if (state.touchHandler) {
        document.removeEventListener('touchstart', state.touchHandler, true);
    }
    if (state.blockPlayback) {
        document.removeEventListener('play', state.blockPlayback, true);
        document.removeEventListener('playing', state.blockPlayback, true);
    }

    if (pause) {
        // Block video playback
        state.blockPlayback = function(event) {
            event.preventDefault();
            event.stopPropagation();
            return false;
        };

        // Listen for user interactions
        state.touchHandler = () => {
            state.userInitiated = true;
            
            // Remove blocking listeners
            document.removeEventListener('play', state.blockPlayback, true);
            document.removeEventListener('playing', state.blockPlayback, true);

            // Unmute media
            document.querySelectorAll('audio, video').forEach(media => {
                media.muted = false;
            });

            setTimeout(() => {
                state.userInitiated = false;
            }, 500);
        };

        document.addEventListener('touchstart', state.touchHandler, true);
        document.addEventListener('play', state.blockPlayback, true);
        document.addEventListener('playing', state.blockPlayback, true);

        // Override play method
        HTMLMediaElement.prototype.play = function() {
            if (state.userInitiated) {
                if (state.observer) {
                    state.observer.disconnect();
                }
                this.muted = false;
                return state.originalPlay.apply(this, arguments);
            } else {
                this.pause();
                return Promise.reject(new Error("Playback blocked: Not user-initiated"));
            }
        };

        // Pause and mute existing media
        document.querySelectorAll('audio, video').forEach(media => {
            media.pause();
            media.muted = true;
        });

        // Setup observer if needed
        if (!state.observer) {
            state.observer = new MutationObserver(mutations => {
                mutations.forEach(mutation => {
                    mutation.addedNodes.forEach(node => {
                        if (node.tagName === 'AUDIO' || node.tagName === 'VIDEO') {
                            if (!state.userInitiated) {
                                node.pause();
                                node.muted = true;
                            }
                        } else if (node.querySelectorAll) {
                            node.querySelectorAll('audio, video').forEach(media => {
                                if (!state.userInitiated) {
                                    media.pause();
                                    media.muted = true;
                                }
                            });
                        }
                    });
                });
            });
            state.observer.observe(document.body, { childList: true, subtree: true });
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
            media.muted = false;
        });
    }
}